local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"

local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
  self.skillsById = {}
  self.installedSkills = {}
  self.builtinSkillProfilesById = {}
  -- 共享 hook 链注册表：每个 (obj, funcName) 只包装一次，避免多技能嵌套
  self._sharedHookRegistry = {}
  self._onBuiltinEliteChanged = function()
    self:_SyncBuiltinSkills()
  end
  self.inst:ListenForEvent("ark_elite_changed", self._onBuiltinEliteChanged)
end)


-- 配置回调字段与事件名映射（模块级常量，避免每次实例化重建）
local CONFIG_CALLBACK_EVENT_MAP = {
  OnActivate         = "ark_skill_activate",
  OnDeactivate       = "ark_skill_deactivate",
  OnLocked           = "ark_skill_locked",
  OnUnlocked         = "ark_skill_unlocked",
  OnEnergyRecovering = "ark_skill_energy_recovering",
  OnActivateReady    = "ark_skill_activate_ready",
  OnActivateEffect   = "ark_skill_activate_effect",
  OnBulletCut        = "ark_skill_bullet_cut",
  OnLevelChange      = "ark_skill_level_change",
}

local function CopySaveData(data)
  local copy = {}
  for key, value in pairs(data) do
    copy[key] = value
  end
  return copy
end

local function NormalizeBuiltinSkillProfile(profile)
  profile = profile or {}

  local normalized = {}
  local requiredElite = profile.requiredElite
  if requiredElite == nil then
    requiredElite = 1
  end
  requiredElite = math.max(1, math.floor(requiredElite))
  normalized.requiredElite = requiredElite

  if profile.slot ~= nil then
    normalized.slot = math.max(1, math.floor(profile.slot))
  end

  return normalized
end

-- 单技能对象（SingleSkill）：封装技能自身的运行态与行为
local SingleSkill = Class(function(self, manager, id)
  self.manager = manager
  self.inst = manager.inst
  self.id = id
  self._lastActivateTime = nil
  self.cancelDebounceTime = 0.3
  -- 运行态数据（含定时器控制）
  self.data = {
    level = 1,
    status = CONSTANTS.SKILL_STATUS.LOCKED,
    energyProgress = 0,
    buffProgress = 0,
    bulletCount = 0,
    activationStacks = 0,
    force = false,
    tickEnergy = false,
    tickBuff = false
  }
  -- 注册事件回调（按事件名索引）
  self._callbacks = {}
  self._activateTest = nil
  -- 从配置中自动注册事件回调
  local cfg = GetArkSkillConfigById(id)
  for cfgKey, eventName in pairs(CONFIG_CALLBACK_EVENT_MAP) do
    if cfg[cfgKey] then
      local fn = cfg[cfgKey]
      self:_AddCallback(eventName, function(inst, payload)
        fn(self, payload)
      end)
    end
  end
  if cfg.ActivateTest then
    local fn = cfg.ActivateTest
    self._activateTest = function(inst, params)
      return fn(self, params)
    end
  end
  -- 生命周期钩子（不走事件系统）
  self._cfgOnStep   = cfg.OnStep
  self._cfgOnInstall = cfg.OnInstall
  self._cfgOnAdd    = cfg.OnAdd
  self._cfgOnRemove = cfg.OnRemove
  self._cfgOnSave   = cfg.OnSave
  self._cfgOnLoad   = cfg.OnLoad
  -- 本技能注册的所有 hook token，供 _CleanupOwnedHooks 兜底清理
  self._ownedTokens = {}
  -- 本技能注册的所有事件监听记录，供 _CleanupOwnedHooks 兜底清理
  -- 每条记录：{ listener, event, fn, source, sourceRemoveFn }
  -- source == nil 表示监听自身（skill.inst）
  self._ownedListeners = {}
end)

function SingleSkill:GetConfig()
  return GetArkSkillConfigById(self.id)
end

function SingleSkill:GetConfigLevels()
  return self:GetConfig().levels
end

function SingleSkill:GetMaxLevel()
  return #self:GetConfigLevels()
end

function SingleSkill:GetLevelConfig()
  local levels = self:GetConfigLevels()
  return levels[self:GetLevel()]
end

function SingleSkill:GetLevelParams()
  return self:GetLevelConfig().params or {}
end

function SingleSkill:SyncStatus()
  self.manager:SyncSkillStatus(self.id)
end

-- 事件工具方法
function SingleSkill:_AddCallback(eventName, fn)
  if fn == nil then
    return
  end
  local list = self._callbacks[eventName]
  if not list then
    list = {}
    self._callbacks[eventName] = list
  end
  for _, cb in ipairs(list) do
    if cb == fn then
      return
    end
  end
  table.insert(list, fn)
end

function SingleSkill:_RemoveCallback(eventName, fn)
  if fn == nil then
    return
  end
  local list = self._callbacks[eventName]
  if not list then
    return
  end
  for i, cb in ipairs(list) do
    if cb == fn then
      table.remove(list, i)
      return
    end
  end
end

function SingleSkill:_Emit(eventName, payload)
  if payload == nil then
    payload = {}
  end
  payload.skillId = payload.skillId or self.id
  payload.level = payload.level or self.data.level
  payload.status = payload.status or self.data.status
  local list = self._callbacks[eventName]
  if list then
    for _, cb in ipairs(list) do
      cb(self.inst, payload)
    end
  end
  self.inst:PushEvent(eventName, payload)
end

function SingleSkill:_EmitActivateEffect(payload)
  local data = self.data
  self:_Emit("ark_skill_activate_effect", {
    source = payload.source,
    target = payload.target,
    targetPos = payload.targetPos,
    force = data.force,
    energyProgress = data.energyProgress,
    buffProgress = data.buffProgress,
    bulletCount = data.bulletCount,
    activationStacks = data.activationStacks,
  })
end

-- 事件注册/反注册接口（相同函数不会重复添加）
function SingleSkill:SetOnLocked(fn)
  self:_AddCallback("ark_skill_locked", fn)
end
function SingleSkill:UnsetOnLocked(fn)
  self:_RemoveCallback("ark_skill_locked", fn)
end

function SingleSkill:SetOnUnlocked(fn)
  self:_AddCallback("ark_skill_unlocked", fn)
end
function SingleSkill:UnsetOnUnlocked(fn)
  self:_RemoveCallback("ark_skill_unlocked", fn)
end

function SingleSkill:SetOnEnergyRecovering(fn)
  self:_AddCallback("ark_skill_energy_recovering", fn)
end
function SingleSkill:UnsetOnEnergyRecovering(fn)
  self:_RemoveCallback("ark_skill_energy_recovering", fn)
end

function SingleSkill:SetOnActivateReady(fn)
  self:_AddCallback("ark_skill_activate_ready", fn)
end
function SingleSkill:UnsetOnActivateReady(fn)
  self:_RemoveCallback("ark_skill_activate_ready", fn)
end

-- 持续效果应用事件：正常激活时在 activate 之后触发，读档恢复时只触发此事件。
function SingleSkill:SetOnActivateEffect(fn)
  self:_AddCallback("ark_skill_activate_effect", fn)
end
function SingleSkill:UnsetOnActivateEffect(fn)
  self:_RemoveCallback("ark_skill_activate_effect", fn)
end

function SingleSkill:SetOnActivate(fn)
  self:_AddCallback("ark_skill_activate", fn)
end
function SingleSkill:UnsetOnActivate(fn)
  self:_RemoveCallback("ark_skill_activate", fn)
end

function SingleSkill:SetOnDeactivate(fn)
  self:_AddCallback("ark_skill_deactivate", fn)
end
function SingleSkill:UnsetOnDeactivate(fn)
  self:_RemoveCallback("ark_skill_deactivate", fn)
end

function SingleSkill:SetOnBulletCut(fn)
  self:_AddCallback("ark_skill_bullet_cut", fn)
end
function SingleSkill:UnsetOnBulletCut(fn)
  self:_RemoveCallback("ark_skill_bullet_cut", fn)
end

function SingleSkill:SetOnLevelChange(fn)
  self:_AddCallback("ark_skill_level_change", fn)
end
function SingleSkill:UnsetOnLevelChange(fn)
  self:_RemoveCallback("ark_skill_level_change", fn)
end

function SingleSkill:SetActivateTest(fn)
  self._activateTest = fn
end

-- ── Hook 系统（SingleSkill 层） ───────────────────────────────────────────────

-- 注册一个与本技能生命周期绑定的函数中间件。
-- fn 签名：function(next, ...) ... return next(...) end
-- 返回 token，可传入 UnhookFunction 做定点移除。
function SingleSkill:HookFunction(obj, funcName, fn)
  local token, entryId = self.manager:_HookRegister(obj, funcName, fn)
  table.insert(self._ownedTokens, { token = token, entryId = entryId })
  return token
end

-- 定点移除指定 token 的中间件；token 不存在或已清理时静默返回（幂等）。
function SingleSkill:UnhookFunction(token)
  if token == nil then return end
  for i, owned in ipairs(self._ownedTokens) do
    if owned.token == token then
      self.manager:_HookUnregister(token, owned.entryId)
      table.remove(self._ownedTokens, i)
      return
    end
  end
end

-- 仅在激活期间（BUFFING/BULLETING）生效的 hook。
-- 激活时自动挂载，deactivate（含 Cancel）时自动清除，读档恢复时也会正确挂载。
-- fn 签名同 HookFunction。
function SingleSkill:HookWhileActive(obj, funcName, fn)
  local activeToken = nil
  self:_AddCallback("ark_skill_activate_effect", function()
    if not activeToken then
      activeToken = self:HookFunction(obj, funcName, fn)
    end
  end)
  self:_AddCallback("ark_skill_deactivate", function()
    if activeToken then
      self:UnhookFunction(activeToken)
      activeToken = nil
    end
  end)
  -- 读档恢复：已处于激活状态则立即挂载
  if self:IsActivating() then
    activeToken = self:HookFunction(obj, funcName, fn)
  end
end

-- 清理本技能注册的所有 hook 与事件监听（由 Remove 在最后调用，作为安全兜底）。
function SingleSkill:_CleanupOwnedHooks()
  for _, owned in ipairs(self._ownedTokens) do
    self.manager:_HookUnregister(owned.token, owned.entryId)
  end
  self._ownedTokens = {}
  -- 同时清理所有事件监听
  local listeners = self._ownedListeners
  self._ownedListeners = {}
  for _, entry in ipairs(listeners) do
    entry.listener:RemoveEventCallback(entry.event, entry.fn, entry.source)
    -- 若有为 source 的 onremove 注册的守卫回调，也一并移除
    if entry.sourceRemoveFn then
      entry.listener:RemoveEventCallback("onremove", entry.sourceRemoveFn, entry.source)
    end
  end
end

-- ── 事件监听系统（SingleSkill 层）─────────────────────────────────────────

-- 注册一个与本技能生命周期绑定的事件监听。
-- 签名：ListenForEvent(event, fn, [source])
--   event    : 事件名
--   fn       : 回调，签名 function(source_inst, data)
--   source   : 可选，被监听的实体（默认为 skill.inst 自身）
-- 返回 token，可传入 RemoveEventCallback 做定点移除。
-- 若 source 是外部实体，框架自动在其 onremove 时清理本监听，防止悬空。
function SingleSkill:ListenForEvent(event, fn, source)
  local listener = self.inst
  local token = Symbol("listen_" .. tostring(event))
  local entry = {
    token          = token,
    listener       = listener,
    event          = event,
    fn             = fn,
    source         = source,  -- nil == 监听自身
    sourceRemoveFn = nil,
  }
  -- source 是外部实体时，注册 onremove 守卫，source 死亡时自动清理本条记录
  if source ~= nil and source ~= listener then
    entry.sourceRemoveFn = function()
      self:RemoveEventCallback(token)
    end
    listener:ListenForEvent("onremove", entry.sourceRemoveFn, source)
  end
  table.insert(self._ownedListeners, entry)
  listener:ListenForEvent(event, fn, source)
  return token
end

-- 定点移除指定 token 的事件监听；token 不存在或已清理时静默返回（幂等）。
function SingleSkill:RemoveEventCallback(token)
  if token == nil then return end
  local listeners = self._ownedListeners
  for i, entry in ipairs(listeners) do
    if entry.token == token then
      entry.listener:RemoveEventCallback(entry.event, entry.fn, entry.source)
      if entry.sourceRemoveFn then
        entry.listener:RemoveEventCallback("onremove", entry.sourceRemoveFn, entry.source)
      end
      table.remove(listeners, i)
      return
    end
  end
end

-- 仅在激活期间（BUFFING/BULLETING）生效的事件监听。
-- 激活时自动注册，deactivate（含 Cancel）时自动移除，读档恢复时也会正确挂载。
-- 签名与 ListenForEvent 相同；无需手动管理生命周期。
function SingleSkill:ListenForEventWhileActive(event, fn, source)
  local activeToken = nil
  self:_AddCallback("ark_skill_activate_effect", function()
    if not activeToken then
      activeToken = self:ListenForEvent(event, fn, source)
    end
  end)
  self:_AddCallback("ark_skill_deactivate", function()
    if activeToken then
      self:RemoveEventCallback(activeToken)
      activeToken = nil
    end
  end)
  if self:IsActivating() then
    activeToken = self:ListenForEvent(event, fn, source)
  end
end

function SingleSkill:SetEnergyRecovering(force)
  local data = self.data
  local cfg = self:GetConfig()
  local lvl = self:GetLevelConfig()
  local prevStatus = data.status
  force = force == true

  data.status = CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
  if cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    if data.activationStacks >= lvl.maxActivationStacks then
      data.tickEnergy = false
      data.energyProgress = 0
    else
      data.tickEnergy = true
    end
  else
    data.tickEnergy = false
  end
  data.tickBuff = false
  self.manager:SyncSkillStatus(self.id)

  -- 从 BUFF/BULLET 状态回到充能，视为一次“结束激活”
  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self:_Emit("ark_skill_deactivate", {
      fromStatus = prevStatus,
      force = force
    })
  end

  -- 进入充能状态事件
  self:_Emit("ark_skill_energy_recovering", {
    fromStatus = prevStatus,
    force = force
  })
end

function SingleSkill:SetBuffing()
  local data = self.data
  data.status = CONSTANTS.SKILL_STATUS.BUFFING
  data.tickBuff = true
  data.tickEnergy = false
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:SetBulleting()
  local data = self.data
  data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self.manager:SyncSkillStatus(self.id)
  data.tickEnergy = false
  data.tickBuff = false
end

function SingleSkill:IsActivating()
  return self.data.status == CONSTANTS.SKILL_STATUS.BUFFING or self.data.status == CONSTANTS.SKILL_STATUS.BULLETING
end

function SingleSkill:Lock()
  local data = self.data
  local prevStatus = data.status
  data.status = CONSTANTS.SKILL_STATUS.LOCKED
  data.tickEnergy = false
  data.tickBuff = false
  data.energyProgress = 0
  data.buffProgress = 0
  data.bulletCount = 0
  data.activationStacks = 0
  data.force = false
  self.manager:SyncSkillStatus(self.id)

  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self:_Emit("ark_skill_deactivate", {
      fromStatus = prevStatus,
      force = false
    })
  end
  self:_Emit("ark_skill_locked", {
    fromStatus = prevStatus
  })
  self:RefreshTag()
end

function SingleSkill:Unlock()
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
    return
  end
  local prevStatus = data.status
  self:_Emit("ark_skill_unlocked", {
    fromStatus = prevStatus
  })
  self:SetEnergyRecovering()
  self:RefreshTag()
end

function SingleSkill:RefreshTag()
  -- task任务, 第一次prefab是没初始化的
  if self.refreshTagTask ~= nil then
    return
  end
  self.refreshTagTask = self.inst:DoTaskInTime(0, function()
    self.refreshTagTask = nil
    local levels = self:GetConfigLevels()
    for level in pairs(levels) do
      local builder_tag = common.genArkSkillLevelUpPrefabNameById(self.id, level)
      if level == self.data.level and self.data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
        self.inst:AddTag(builder_tag)
      else
        self.inst:RemoveTag(builder_tag)
      end
    end
  end)
end

function SingleSkill:GetLevel()
  return self.data.level
end

function SingleSkill:SetLevel(level)
  local maxLevel = self:GetMaxLevel()
  assert(level >= 1 and level <= maxLevel, "Invalid skill level: " .. tostring(level) .. ", max level is: " .. tostring(maxLevel))
  local oldLevel = self:GetLevel()
  if oldLevel == level then
    return
  end
  self.data.level = level
  local cfg = self:GetConfig()
  local lvl = self:GetLevelConfig()
  self.data.activationStacks = math.min(self.data.activationStacks, lvl.maxActivationStacks)

  if self.data.status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    if cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
      self.data.tickEnergy = self.data.activationStacks < lvl.maxActivationStacks
      if not self.data.tickEnergy then
        self.data.energyProgress = 0
      end
    else
      self.data.tickEnergy = false
    end
  end
  self:_Emit("ark_skill_level_change", {
    oldLevel = oldLevel,
    newLevel = level
  })
  self.manager:SyncSkillStatus(self.id)
  -- self:SetEnergyRecovering()
  self:RefreshTag()
end

function SingleSkill:AddEnergyProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING and data.status ~= CONSTANTS.SKILL_STATUS.BUFFING then
    return 0
  end
  local cfg = self:GetConfig()
  local lvl = self:GetLevelConfig()
  if data.activationStacks >= lvl.maxActivationStacks then
    return 0
  end
  local oldEnergyProgress = data.energyProgress
  data.energyProgress = data.energyProgress + value
  while data.energyProgress >= lvl.activationEnergy do
    data.energyProgress = data.energyProgress - lvl.activationEnergy
    data.activationStacks = data.activationStacks + 1
    -- 每次可激活次数 +1 时触发
    self:_Emit("ark_skill_activate_ready", {
      activationStacks = data.activationStacks
    })
    if data.activationStacks >= lvl.maxActivationStacks then
      data.tickEnergy = false
      data.energyProgress = 0
      break
    end
  end
  -- 自动充能模式整数帧同步, 其余模式在每次进度变化时同步
  local skipSync = cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO and math.floor(oldEnergyProgress) == math.floor(data.energyProgress)
  if not skipSync then
    self.manager:SyncSkillStatus(self.id)
  end
  local leftEnergy = data.energyProgress - lvl.activationEnergy
  return leftEnergy
end

function SingleSkill:AddBuffProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.BUFFING then
    return 0
  end
  local lvl = self:GetLevelConfig()
  data.buffProgress = data.buffProgress + value
  local leftBuff = data.buffProgress - lvl.buffDuration
  if leftBuff >= 0 then
    data.buffProgress = leftBuff
    self:SetEnergyRecovering()
    data.tickBuff = false
  end
  return leftBuff
end

function SingleSkill:CanActivate(params)
  if not params then params = {} end
  local data = self.data
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then
    return false
  end
  if data.activationStacks <= 0 then
    return false
  end
  if self._activateTest then
    return self._activateTest(self.inst, {
      target = params.target,
      targetPos = params.targetPos,
      force = params.force
    })
  end
  return true
end

function SingleSkill:Activate(params)
  -- 处于激活状态跳过
  if self:IsActivating() then
    return true
  end
  if not params then params = { target = nil, targetPos = nil, force = false } end
  local data = self.data
  data.activationStacks = data.activationStacks - 1
  local lvl = self:GetLevelConfig()
  if lvl.bulletCount then
    data.bulletCount = lvl.bulletCount
  else
    data.buffProgress = 0
  end
  data.force = params.force
  self._lastActivateTime = GetTime()
  if lvl.bulletCount then
    self:SetBulleting()
  else
    self:SetBuffing()
  end
  self:_Emit("ark_skill_activate", params)
  self:_EmitActivateEffect({
    source = "activate",
    target = params.target,
    targetPos = params.targetPos,
  })
  return true
end

function SingleSkill:TryActivate(params)
  if not params then params = { target = nil, targetPos = nil, force = false } end
  if not self:CanActivate(params) then
    return false
  end
  return self:Activate(params)
end

function SingleSkill:Cancel()
  if self._lastActivateTime ~= nil and GetTime() - self._lastActivateTime < self.cancelDebounceTime then
    return false
  end
  if not self:IsActivating() then
    return false
  end
  self.data.force = false
  self.data.tickBuff = false
  self:SetEnergyRecovering(true)
  return true
end

function SingleSkill:CutBullet(value)
  if value == nil then
    value = 1
  end
  local data = self.data
  data.bulletCount = data.bulletCount - value
  if data.bulletCount < 0 then
    data.bulletCount = 0
  end
  self.manager:SyncSkillStatus(self.id)
  self:_Emit("ark_skill_bullet_cut", {
    cut = value,
    bulletCount = data.bulletCount
  })
  if data.bulletCount == 0 then
    self:SetEnergyRecovering()
  end
end

function SingleSkill:Step(dt)
  local data = self.data
  -- buff 期间不自动时间充能；buff 多余的时间根据充能模式决定是否叠加到能量
  if data.tickBuff then
    local leftBuff = self:AddBuffProgress(dt)
    -- 如果状态流转到了 自动充能，且有剩余时间，则将剩余时间加到能量上
    if leftBuff > 0 and data.tickEnergy then
      self:AddEnergyProgress(dt + leftBuff)
    end
  elseif data.tickEnergy then
    self:AddEnergyProgress(dt)
  end
  if self._cfgOnStep then
    self._cfgOnStep(self, dt)
  end
end

function SingleSkill:OnLoad(saved)
  if not saved then
    return
  end
  local stateData = saved.data
  if not stateData then
    return
  end
  if not table.contains(CONSTANTS.SKILL_STATUS, stateData.status) then
    return
  end
  self.data = MergeMaps(self.data, stateData)
  self.data.level = math.min(self.data.level or 1, self:GetMaxLevel())
  self.manager:SyncSkillStatus(self.id)
  self:RefreshTag()
  self._lastActivateTime = nil

  if self:IsActivating() then
    self:_EmitActivateEffect({ source = "load" })
  end
  if self._cfgOnLoad then
    self._cfgOnLoad(self, saved.cfg or {})
  end
end

function SingleSkill:Remove()
  if self.refreshTagTask then
    self.refreshTagTask:Cancel()
    self.refreshTagTask = nil
  end
  self:Cancel()  -- 若在激活中，触发 deactivate → HookWhileActive 自动清除
  self:Lock()
  if self._cfgOnRemove and not self._removing then
    self._cfgOnRemove(self, {})
  end
  self:_CleanupOwnedHooks()  -- 兜底：清理所有未释放的 hook
  self._removing = true
  self.manager:RemoveSkill(self.id)
end

function ArkSkill:_GetCurrentElite()
  local elite = self.inst.components.ark_elite
  return elite and elite.elite or nil
end

function ArkSkill:CanAddSkill(id)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))
  return true, nil
end

function ArkSkill:CanUnlockSkill(id)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))

  local profile = self.builtinSkillProfilesById[id]
  if not profile then
    return true, nil
  end

  local currentElite = self:_GetCurrentElite()
  if currentElite == nil or currentElite >= profile.requiredElite then
    return true, nil
  end

  return false, "elite_insufficient"
end

function ArkSkill:_SyncBuiltinSkillState(id)
  local profile = self.builtinSkillProfilesById[id]
  if not profile then
    return
  end

  local skill = self.skillsById[id]
  if not skill then
    return
  end

  local shouldUnlock = self:CanUnlockSkill(id)
  if shouldUnlock then
    if skill.data.status == CONSTANTS.SKILL_STATUS.LOCKED then
      skill:Unlock()
    end
  else
    if skill.data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
      skill:Lock()
    end
  end
end

function ArkSkill:_SyncBuiltinSkills()
  for id in pairs(self.builtinSkillProfilesById) do
    self:_SyncBuiltinSkillState(id)
  end
end

function ArkSkill:DeclareBuiltinSkill(id, profile)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))

  self.builtinSkillProfilesById[id] = NormalizeBuiltinSkillProfile(profile)
  self:_SyncBuiltinSkillState(id)
end

function ArkSkill:GetBuiltinSkillProfile(id)
  return self.builtinSkillProfilesById[id]
end

-- 内部核心：创建并接入 SingleSkill，返回新建的 skill 对象
function ArkSkill:_InstallSkill(id)
  local skill = SingleSkill(self, id)
  self.skillsById[id] = skill
  table.insert(self.installedSkills, id)
  self.inst:StartUpdatingComponent(self)
  self.inst.replica.ark_skill:AddSkill(id)
  self:SyncSkillStatus(id)
  if skill._cfgOnInstall then
    skill._cfgOnInstall(skill, {})
  end
  return skill
end

-- OnLoad 读档恢复路径专用：会触发 OnInstall，但不触发 OnAdd 回调和 ark_skill_added 事件
-- 用 pcall 防御存档中记录的技能 id 已被 mod 移除的情况
function ArkSkill:_RestoreSkill(id)
  if self.skillsById[id] then return end
  local ok = pcall(GetArkSkillConfigById, id)
  if not ok then
    ArkLogger:Warn("Ark skill config not found, skip restore: " .. tostring(id))
    return
  end
  self:_InstallSkill(id)
end

function ArkSkill:AddSkill(id)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))
  if self.skillsById[id] then
    ArkLogger:Warn("Ark skill already exists for id: " .. tostring(id))
    return
  end
  local skill = self:_InstallSkill(id)
  if skill._cfgOnAdd then
    skill._cfgOnAdd(skill, {})
  end
  self:_SyncBuiltinSkillState(id)
  self.inst:PushEvent("ark_skill_added", { id = id })
end

function ArkSkill:RemoveSkill(id)
  local skill = self.skillsById[id]
  if skill and not skill._removing then
    skill:Remove()
    self.inst.replica.ark_skill:RemoveSkill(id)
    self.skillsById[id] = nil
    table.removearrayvalue(self.installedSkills, id)
  end
end

-- 便捷的几个方法（by-id）
function ArkSkill:GetSkill(id)
  return self.skillsById[id]
end

function ArkSkill:SyncSkillStatus(id)
  local s = self:GetSkill(id)
  if not s then
    return
  end
  self.inst.replica.ark_skill:SyncSkillStatus(id, s.data)
end

function ArkSkill:RequestSyncSkillStatus(id)
  self:SyncSkillStatus(id)
end

function ArkSkill:OnUpdate(dt)
  for _, s in pairs(self.skillsById) do
    if s and s.Step then
      s:Step(dt)
    end
  end
end

function ArkSkill:OnSave()
  local data = {
    installedSkills = {},
    skills = {}
  }
  for _, id in ipairs(self.installedSkills) do
    local skill = self.skillsById[id]
    if skill then
      table.insert(data.installedSkills, id)
      local savedSkill = {
        data = CopySaveData(skill.data),
        cfg = nil,
      }
      if skill._cfgOnSave then
        local cfgData = {}
        cfgData = skill._cfgOnSave(skill, cfgData) or cfgData
        savedSkill.cfg = next(cfgData) and cfgData or nil
      end
      data.skills[id] = savedSkill
    end
  end
  return data
end

function ArkSkill:OnLoad(data)
  if not data then
    return
  end
  self.installedSkills = {}
  -- 第一步：恢复技能插槽（会触发 OnInstall，但不触发 OnAdd/ark_skill_added，避免 elite 等组件重置存档数据）
  if data.installedSkills then
    for _, id in ipairs(data.installedSkills) do
      self:_RestoreSkill(id)
    end
  end
  -- 第二步：恢复各技能的运行态数据
  if data.skills then
    for id, skillData in pairs(data.skills) do
      local s = self.skillsById[id]
      if s then
        s:OnLoad(skillData)
      end
    end
  end
  self:_SyncBuiltinSkills()
end

-- OnPreRemoveFromEntity
function ArkSkill:OnPreRemoveFromEntity()
  self.inst:RemoveEventCallback("ark_elite_changed", self._onBuiltinEliteChanged)
  for _, s in pairs(self.skillsById) do
    s:Remove()
  end
end

-- ── Hook 系统（ArkSkill manager 层） ─────────────────────────────────────────
-- 每个 (obj, funcName) 对只替换一次原函数，所有 SingleSkill 的中间件统一调度，
-- 避免多个技能重复包装同一函数导致的调用栈嵌套问题。

-- 获取或创建 hook 链；首次调用时替换 obj[funcName] 为调度器。
function ArkSkill:_GetOrCreateHookChain(obj, funcName)
  local id = tostring(obj) .. "\0" .. funcName
  if not self._sharedHookRegistry[id] then
    local original = obj[funcName]
    assert(type(original) == "function",
      "HookFunction: '" .. tostring(funcName) .. "' 不是函数: " .. tostring(obj))
    local entry = {
      id       = id,
      obj      = obj,
      key      = funcName,
      original = original,
      mws      = {},  -- 有序列表 { token, fn }，无空洞
    }
    obj[funcName] = function(...)
      local mws = entry.mws
      local idx = 0
      local function callNext(...)
        idx = idx + 1
        if mws[idx] then
          return mws[idx].fn(callNext, ...)
        else
          return entry.original(...)
        end
      end
      return callNext(...)
    end
    self._sharedHookRegistry[id] = entry
  end
  return self._sharedHookRegistry[id]
end

-- 向 hook 链末尾追加一个中间件，返回 (token, entryId)。
function ArkSkill:_HookRegister(obj, funcName, fn)
  local entry = self:_GetOrCreateHookChain(obj, funcName)
  local token = Symbol("hook_" .. tostring(funcName))
  table.insert(entry.mws, { token = token, fn = fn })
  return token, entry.id
end

-- 移除指定 token 的中间件。
-- 链空时调度器仍留在 obj 上作为透传，不还原原函数：
-- 其他模组可能在任意时刻包装了同一接口，强制还原会抹掉它们的 hook。
function ArkSkill:_HookUnregister(token, entryId)
  if token == nil then return end
  local entry = self._sharedHookRegistry[entryId]
  if not entry then return end
  for i, mw in ipairs(entry.mws) do
    if mw.token == token then
      table.remove(entry.mws, i)
      return
    end
  end
end

return ArkSkill
