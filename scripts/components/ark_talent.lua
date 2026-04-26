local CONSTANTS = require "ark_constants"
local builtinProfile = require "ark_builtin_profile"
local hooks = require "ark_entity_hooks"

local CopySaveData = hooks.CopySaveData

-- ── 内部工具 ────────────────────────────────────────────────────────────────

-- 配置回调字段与事件名映射
local CONFIG_CALLBACK_EVENT_MAP = {
  OnLocked      = "ark_talent_locked",
  OnUnlocked    = "ark_talent_unlocked",
  OnLevelChange = "ark_talent_level_change",
}

-- ── SingleTalent ─────────────────────────────────────────────────────────────
-- 封装单个天赋的运行态与行为。天赋无激活状态机，仅有 LOCKED / ACTIVE 两态。

local SingleTalent = Class(function(self, manager, id)
  self.manager = manager
  self.inst = manager.inst
  self.id = id
  self.data = {
    level  = 1,
    status = CONSTANTS.TALENT_STATUS.LOCKED,
  }
  -- 初始化共享基础设施（_callbacks / _ownedTokens / _ownedListeners）
  self:_InitItemBase()
  -- 从配置中自动注册事件回调
  local cfg = GetArkTalentConfigById(id)
  for cfgKey, eventName in pairs(CONFIG_CALLBACK_EVENT_MAP) do
    if cfg[cfgKey] then
      local fn = cfg[cfgKey]
      self:_AddCallback(eventName, function(inst, payload)
        fn(self, payload)
      end)
    end
  end
  -- 生命周期钩子（不走事件系统）
  self._cfgOnInstall = cfg.OnInstall
  self._cfgOnAdd     = cfg.OnAdd
  self._cfgOnRemove  = cfg.OnRemove
  self._cfgOnSave    = cfg.OnSave
  self._cfgOnLoad    = cfg.OnLoad
end)

-- 安装共享基础设施：_InitItemBase / _AddCallback / _RemoveCallback /
-- HookFunction / UnhookFunction / ListenForEvent / RemoveEventCallback / _CleanupOwnedHooks
hooks.InstallItemBase(SingleTalent)

-- ── 配置访问 ─────────────────────────────────────────────────────────────────

function SingleTalent:GetConfig()
  return GetArkTalentConfigById(self.id)
end

function SingleTalent:GetConfigLevels()
  return self:GetConfig().levels
end

function SingleTalent:GetMaxLevel()
  return #self:GetConfigLevels()
end

function SingleTalent:GetLevelConfig()
  return self:GetConfigLevels()[self:GetLevel()]
end

function SingleTalent:GetLevelParams()
  return self:GetLevelConfig().params or {}
end

function SingleTalent:GetLevel()
  return self.data.level
end

-- ── 事件发射 ────────────────────────────────────────────────────────────────

function SingleTalent:_Emit(eventName, payload)
  if payload == nil then
    payload = {}
  end
  payload.talentId = payload.talentId or self.id
  payload.level    = payload.level    or self.data.level
  payload.status   = payload.status   or self.data.status
  local list = self._callbacks[eventName]
  if list then
    for _, cb in ipairs(list) do
      cb(self.inst, payload)
    end
  end
  self.inst:PushEvent(eventName, payload)
end

-- ── 仅在激活期间（ACTIVE）生效的 hook ─────────────────────────────────────

-- 天赋解锁时自动挂载，锁定时自动清除，读档恢复时也会正确挂载。
function SingleTalent:HookFunctionWhileActivating(obj, funcName, fn)
  local activeToken = nil
  self:_AddCallback("ark_talent_unlocked", function()
    if not activeToken then
      activeToken = self:HookFunction(obj, funcName, fn)
    end
  end)
  self:_AddCallback("ark_talent_locked", function()
    if activeToken then
      self:UnhookFunction(activeToken)
      activeToken = nil
    end
  end)
  if self:IsActivating() then
    activeToken = self:HookFunction(obj, funcName, fn)
  end
end

-- 仅在激活期间（ACTIVE）生效的事件监听。
function SingleTalent:ListenForEventWhileActivating(event, fn, source)
  local activeToken = nil
  self:_AddCallback("ark_talent_unlocked", function()
    if not activeToken then
      activeToken = self:ListenForEvent(event, fn, source)
    end
  end)
  self:_AddCallback("ark_talent_locked", function()
    if activeToken then
      self:RemoveEventCallback(activeToken)
      activeToken = nil
    end
  end)
  if self:IsActivating() then
    activeToken = self:ListenForEvent(event, fn, source)
  end
end

-- ── 状态查询 ─────────────────────────────────────────────────────────────────

function SingleTalent:IsActivating()
  return self.data.status == CONSTANTS.TALENT_STATUS.ACTIVE
end

-- ── 状态变更 ─────────────────────────────────────────────────────────────────

function SingleTalent:SyncStatus()
  self.manager:SyncTalentStatus(self.id)
end

function SingleTalent:SetLevel(level)
  local maxLevel = self:GetMaxLevel()
  assert(level >= 1 and level <= maxLevel,
    "Invalid talent level: " .. tostring(level) .. ", max: " .. tostring(maxLevel))
  local oldLevel = self.data.level
  if oldLevel == level then return end
  self.data.level = level
  self:_Emit("ark_talent_level_change", {
    oldLevel = oldLevel,
    newLevel = level,
  })
  self:SyncStatus()
end

function SingleTalent:Lock()
  local prevStatus = self.data.status
  self.data.status = CONSTANTS.TALENT_STATUS.LOCKED
  self.manager:SyncTalentStatus(self.id)
  if prevStatus == CONSTANTS.TALENT_STATUS.ACTIVE then
    self:_Emit("ark_talent_locked", { fromStatus = prevStatus })
  end
end

function SingleTalent:Unlock()
  if self.data.status == CONSTANTS.TALENT_STATUS.ACTIVE then return end
  local prevStatus = self.data.status
  self.data.status = CONSTANTS.TALENT_STATUS.ACTIVE
  self.manager:SyncTalentStatus(self.id)
  self:_Emit("ark_talent_unlocked", { fromStatus = prevStatus })
end

function SingleTalent:OnLoad(saved)
  if not saved then return end
  local stateData = saved.data
  if not stateData then return end
  if not table.contains(CONSTANTS.TALENT_STATUS, stateData.status) then return end
  self.data = MergeMaps(self.data, stateData)
  self.data.level = math.min(self.data.level or 1, self:GetMaxLevel())
  self.manager:SyncTalentStatus(self.id)
  -- 读档恢复：若处于激活状态则重新触发 unlock 事件（让 HookFunctionWhileActivating 正确挂载）
  if self:IsActivating() then
    self:_Emit("ark_talent_unlocked", { fromStatus = CONSTANTS.TALENT_STATUS.LOCKED, source = "load" })
  end
  if self._cfgOnLoad then
    self._cfgOnLoad(self, saved.cfg or {})
  end
end

function SingleTalent:Remove()
  if self:IsActivating() then
    self:Lock()  -- 触发 ark_talent_locked → HookFunctionWhileActivating 自动清除
  end
  if self._cfgOnRemove and not self._removing then
    self._cfgOnRemove(self, {})
  end
  self:_CleanupOwnedHooks()
  self._removing = true
  self.manager:RemoveTalent(self.id)
end

-- ── ArkTalent（Manager） ─────────────────────────────────────────────────────

local ArkTalent = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_talent")
  self.talentsById         = {}
  self.installedTalents    = {}  -- 有序数组，记录安装顺序
  self.builtinTalentProfilesById = {}
  -- 共享 hook 链注册表
  self._sharedHookRegistry = {}
  self._onBuiltinEliteChanged = function()
    self:_SyncBuiltinTalents()
  end
  self.inst:ListenForEvent("ark_elite_changed", self._onBuiltinEliteChanged)
end)

-- 安装共享 hook 链管理方法
hooks.InstallManagerHooks(ArkTalent)

-- ── 内置天赋（builtin）── 与 elite 联动 ──────────────────────────────────────

function ArkTalent:_GetCurrentElite()
  local elite = self.inst.components.ark_elite
  return elite and elite.elite or nil
end

function ArkTalent:CanUnlockTalent(id)
  assert(id, "Talent id is required")
  local profile = self.builtinTalentProfilesById[id]
  if not profile then return true, nil end
  local currentElite = self:_GetCurrentElite()
  if currentElite == nil or currentElite >= profile.requiredElite then
    return true, nil
  end
  return false, "elite_insufficient"
end

function ArkTalent:_GetBuiltinTalentTargetLevel(id)
  local profile = self.builtinTalentProfilesById[id]
  return builtinProfile.GetTargetLevelByElite(profile, self:_GetCurrentElite())
end

function ArkTalent:_SyncBuiltinTalentState(id)
  local profile = self.builtinTalentProfilesById[id]
  if not profile then
    return
  end

  local talent = self.talentsById[id]
  if not talent then
    return
  end

  local shouldUnlock = self:CanUnlockTalent(id)
  if shouldUnlock then
    if talent.data.status == CONSTANTS.TALENT_STATUS.LOCKED then
      talent:Unlock()
    end
    -- elite 驱动天赋等级升降
    local targetLevel = self:_GetBuiltinTalentTargetLevel(id)
    if targetLevel ~= nil and talent:GetLevel() ~= targetLevel then
      talent:SetLevel(math.min(targetLevel, talent:GetMaxLevel()))
    end
  end
end

function ArkTalent:_SyncBuiltinTalents()
  for id in pairs(self.builtinTalentProfilesById) do
    self:_SyncBuiltinTalentState(id)
  end
end

-- 声明内置对象（由 prefab 在 OnAdd 时调用）
-- profile = { requiredElite = 1, eliteLevelMap = { [1]=1, [2]=2 } }
function ArkTalent:DeclareBuiltin(id, profile)
  assert(id, "Talent id is required")
  assert(GetArkTalentConfigById(id), "Config not found for talent id: " .. tostring(id))
  self.builtinTalentProfilesById[id] = builtinProfile.NormalizeProfile(profile)
  self:_SyncBuiltinTalentState(id)
end

function ArkTalent:GetBuiltinTalentProfile(id)
  return self.builtinTalentProfilesById[id]
end

-- ── 内部核心：安装/卸载 ───────────────────────────────────────────────────────

function ArkTalent:_InstallTalent(id)
  local talent = SingleTalent(self, id)
  self.talentsById[id] = talent
  table.insert(self.installedTalents, id)
  self.inst.replica.ark_talent:AddTalent(id)
  self:SyncTalentStatus(id)
  if talent._cfgOnInstall then
    talent._cfgOnInstall(talent, {})
  end
  return talent
end

-- 读档恢复路径（不触发 OnAdd / ark_talent_added）
function ArkTalent:_RestoreTalent(id)
  if self.talentsById[id] then return end
  local ok = pcall(GetArkTalentConfigById, id)
  if not ok then
    ArkLogger:Warn("Ark talent config not found, skip restore: " .. tostring(id))
    return
  end
  self:_InstallTalent(id)
end

function ArkTalent:AddTalent(id)
  assert(id, "Talent id is required")
  assert(GetArkTalentConfigById(id), "Config not found for talent id: " .. tostring(id))
  if self.talentsById[id] then
    ArkLogger:Warn("Ark talent already exists for id: " .. tostring(id))
    return
  end
  local talent = self:_InstallTalent(id)
  if talent._cfgOnAdd then
    talent._cfgOnAdd(talent, {})
  end
  self:_SyncBuiltinTalentState(id)
  self.inst:PushEvent("ark_talent_added", { id = id })
end

function ArkTalent:RemoveTalent(id)
  local talent = self.talentsById[id]
  if talent and not talent._removing then
    talent:Remove()
    self.inst.replica.ark_talent:RemoveTalent(id)
    self.talentsById[id] = nil
    table.removearrayvalue(self.installedTalents, id)
  end
end

-- ── 便捷方法 ─────────────────────────────────────────────────────────────────

function ArkTalent:GetTalent(id)
  return self.talentsById[id]
end

function ArkTalent:SyncTalentStatus(id)
  local t = self:GetTalent(id)
  if not t then return end
  self.inst.replica.ark_talent:SyncTalentStatus(id, t.data)
end

-- ── 存档 ─────────────────────────────────────────────────────────────────────

function ArkTalent:OnSave()
  local data = {
    installedTalents = {},
    talents = {}
  }
  for _, id in ipairs(self.installedTalents) do
    local talent = self.talentsById[id]
    if talent then
      table.insert(data.installedTalents, id)
      local saved = {
        data = CopySaveData(talent.data),
        cfg = nil,
      }
      if talent._cfgOnSave then
        local cfgData = {}
        cfgData = talent._cfgOnSave(talent, cfgData) or cfgData
        saved.cfg = next(cfgData) and cfgData or nil
      end
      data.talents[id] = saved
    end
  end
  return data
end

function ArkTalent:OnLoad(data)
  if not data then return end
  self.installedTalents = {}
  if data.installedTalents then
    for _, id in ipairs(data.installedTalents) do
      self:_RestoreTalent(id)
    end
  end
  if data.talents then
    for id, talentData in pairs(data.talents) do
      local t = self.talentsById[id]
      if t then
        t:OnLoad(talentData)
      end
    end
  end
  self:_SyncBuiltinTalents()
end

-- ── 生命周期 ─────────────────────────────────────────────────────────────────

function ArkTalent:OnPreRemoveFromEntity()
  self.inst:RemoveEventCallback("ark_elite_changed", self._onBuiltinEliteChanged)
  for _, t in pairs(self.talentsById) do
    t:Remove()
  end
end

return ArkTalent
