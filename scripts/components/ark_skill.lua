local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local builtinProfile = require "ark_builtin_profile"
local utils = require "ark_utils"
local hooks = require "ark_entity_hooks"

local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
  self.skillsById = {}
  self.installedSkills = {}
  self.builtinSkillProfilesById = {}
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
  OnRecast           = "ark_skill_recast",
}

local CopySaveData = hooks.CopySaveData

-- state 中的实体以 GetSaveRecord 内联嵌套存档（参考 player_common.lua 的 wormlight）：
-- 玩家存档不适用 save references（SerializeUserSession 丢弃 refs），实体数据须自包含。
-- 序列化：实体 → { _ark_entity_save = record }；读档：SpawnSaveRecord 还原。
local function SerializeState(state, refs)
  if type(state) ~= "table" then return state end
  local copy = {}
  for k, v in pairs(state) do
    if EntityScript.is_instance(v) then
      if v:IsValid() then
        local record, innerRefs = v:GetSaveRecord()
        copy[k] = { _ark_entity_save = record }
        -- 嵌套实体自身的 references 一并上抛（对世界实体存档可用于解析）
        if innerRefs then
          for _, guid in ipairs(innerRefs) do
            table.insert(refs, guid)
          end
        end
      end
      -- 无效实体不保留（skill 侧应在实体销毁时自行清理 state）
    elseif type(v) == "table" then
      copy[k] = SerializeState(v, refs)
    else
      copy[k] = v
    end
  end
  return copy
end

-- 读档：把 state 中的 { _ark_entity_save = record } 还原为实体。
-- 恢复的实体记录到 skill._restoredEntities，供 skill 移除时兜底清理（防重复/残留）。
local function DeserializeState(state, skill)
  if type(state) ~= "table" then return end
  for k, v in pairs(state) do
    if type(v) == "table" and v._ark_entity_save then
      local ent = SpawnSaveRecord(v._ark_entity_save)
      if ent ~= nil then
        ent.persists = false -- 继续由技能接管，不回到世界存档
        state[k] = ent
        if skill then
          skill._restoredEntities = skill._restoredEntities or {}
          table.insert(skill._restoredEntities, ent)
        end
      else
        state[k] = nil
      end
    elseif type(v) == "table" then
      DeserializeState(v, skill)
    end
  end
end

local CONFIG_PATCH_FIELD_DEFS = {
  activationMode = {
    normalize = function(value, skillId)
      assert(type(value) == "string", "Skill " .. skillId .. " config patch field activationMode must be a string.")
      assert(table.contains(CONSTANTS.ACTIVATION_MODE, value), "Invalid activationMode for skill " .. skillId)
      return value
    end,
  },
  energyRecoveryMode = {
    normalize = function(value, skillId)
      assert(type(value) == "string", "Skill " .. skillId .. " config patch field energyRecoveryMode must be a string.")
      assert(table.contains(CONSTANTS.ENERGY_RECOVERY_MODE, value), "Invalid energyRecoveryMode for skill " .. skillId)
      return value
    end,
  },
  hotkey = {
    normalize = function(value, skillId)
      assert(type(value) == "number" or type(value) == "string",
        "Skill " .. skillId .. " config patch field hotkey must be a number or string.")
      return value
    end,
  },
  lockedDesc = {
    normalize = function(value, skillId)
      assert(type(value) == "string", "Skill " .. skillId .. " config patch field lockedDesc must be a string.")
      return value
    end,
  },
  name = {
    normalize = function(value, skillId)
      assert(type(value) == "string", "Skill " .. skillId .. " config patch field name must be a string.")
      return value
    end,
  },
}

local function ShallowCopyMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do
    copy[key] = value
  end
  return copy
end

local function GetSortedMapKeys(source)
  local keys = {}
  for key in pairs(source or {}) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

local function NormalizeConfigPatch(configPatch, skillId)
  assert(type(configPatch) == "table", "Skill " .. skillId .. " config patch must be a table.")
  local normalized = {}
  for key, value in pairs(configPatch) do
    local fieldDef = CONFIG_PATCH_FIELD_DEFS[key]
    assert(fieldDef ~= nil, "Unsupported config patch field for skill " .. skillId .. ": " .. tostring(key))
    if value ~= nil then
      normalized[key] = fieldDef.normalize(value, skillId)
    end
  end
  return normalized
end

local function SerializeConfigPatch(configPatch)
  local keys = GetSortedMapKeys(configPatch)
  if #keys <= 0 then
    return ""
  end

  local serialized = {}
  for _, key in ipairs(keys) do
    local value = configPatch[key]
    local valueType = type(value)
    assert(valueType == "string" or valueType == "number" or valueType == "boolean",
      "Unsupported config patch value type for field " .. tostring(key) .. ": " .. valueType)
    local valueLiteral = valueType == "string" and string.format("%q", value) or tostring(value)
    table.insert(serialized, string.format("[%q]=%s", key, valueLiteral))
  end

  return "{" .. table.concat(serialized, ",") .. "}"
end

local function DeserializeConfigPatch(configPatchString, skillId)
  if configPatchString == nil or configPatchString == "" then
    return {}
  end

  local chunk, err = loadstring("return " .. configPatchString)
  if chunk == nil then
    ArkLogger:Warn("Failed to deserialize config patch for skill " .. tostring(skillId) .. ": " .. tostring(err))
    return {}
  end

  local ok, configPatch = pcall(chunk)
  if not ok or type(configPatch) ~= "table" then
    ArkLogger:Warn("Invalid deserialized config patch for skill " .. tostring(skillId))
    return {}
  end

  local okNormalize, normalized = pcall(NormalizeConfigPatch, configPatch, skillId)
  if not okNormalize then
    ArkLogger:Warn("Failed to normalize config patch for skill " .. tostring(skillId) .. ": " .. tostring(normalized))
    return {}
  end

  return normalized
end

local function MergeSkillConfig(baseConfig, configPatch)
  local merged = ShallowCopyMap(baseConfig)
  for key, value in pairs(configPatch or {}) do
    merged[key] = value
  end
  return merged
end

local function GetChangedConfigPatchKeys(previousPatch, nextPatch)
  local changedKeys = {}
  local keySet = {}
  for key in pairs(previousPatch or {}) do
    keySet[key] = true
  end
  for key in pairs(nextPatch or {}) do
    keySet[key] = true
  end
  for key in pairs(keySet) do
    if previousPatch[key] ~= nextPatch[key] then
      table.insert(changedKeys, key)
    end
  end
  table.sort(changedKeys)
  return changedKeys
end

-- 单技能对象（SingleSkill）：封装技能自身的运行态与行为
local SingleSkill = Class(function(self, manager, id)
  self.manager = manager
  self.inst = manager.inst
  self.id = id
  self.configPatch = {}
  self.configPatchString = ""
  self._lastActivateTime = nil
  self._lastDeactivateTime = nil
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
    tickBuff = false,
    activateCount = 0,
    isTemporary = false,
    limitTimeInitial = 0,
    limitRemaining = 0,
    -- 技能运行时状态存储（随 data 一起序列化，读档自动恢复）
    state = {},
  }
  -- 注册事件回调（按事件名索引）
  self:_InitItemBase()
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
  self._cfgOnStep    = cfg.OnStep
  self._cfgOnInstall = cfg.OnInstall
  self._cfgOnAdd     = cfg.OnAdd
  self._cfgOnRemove  = cfg.OnRemove
  self._cfgOnSave    = cfg.OnSave
  self._cfgOnLoad    = cfg.OnLoad
end)

function SingleSkill:GetBaseConfig()
  return GetArkSkillConfigById(self.id)
end

function SingleSkill:GetConfigPatch()
  return ShallowCopyMap(self.configPatch)
end

function SingleSkill:GetConfigPatchString()
  return self.configPatchString
end

function SingleSkill:GetResolvedConfig()
  return MergeSkillConfig(self:GetBaseConfig(), self.configPatch)
end

function SingleSkill:GetConfig()
  return self:GetResolvedConfig()
end

function SingleSkill:_ApplyConfigPatch(nextPatch, opts)
  opts = opts or {}
  nextPatch = NormalizeConfigPatch(nextPatch, self.id)
  local nextPatchString = SerializeConfigPatch(nextPatch)
  if nextPatchString == self.configPatchString then
    return false
  end

  local previousPatch = self:GetConfigPatch()
  self.configPatch = nextPatch
  self.configPatchString = nextPatchString

  if opts.sync ~= false then
    self.manager:SyncSkillStatus(self.id)
  end

  self.inst:PushEvent("ark_skill_config_patch", {
    skillId = self.id,
    previousPatch = previousPatch,
    patch = self:GetConfigPatch(),
    changedKeys = GetChangedConfigPatchKeys(previousPatch, self.configPatch),
    source = opts.source,
  })
  return true
end

function SingleSkill:PatchConfig(patch, opts)
  assert(type(patch) == "table", "Skill " .. self.id .. " PatchConfig patch must be a table.")
  local nextPatch = self:GetConfigPatch()
  for key, value in pairs(patch) do
    nextPatch[key] = value
  end
  return self:_ApplyConfigPatch(nextPatch, opts)
end

function SingleSkill:ClearConfigPatch(keys, opts)
  local nextPatch
  if keys == nil then
    nextPatch = {}
  else
    if type(keys) ~= "table" then
      keys = { keys }
    end
    nextPatch = self:GetConfigPatch()
    for _, key in ipairs(keys) do
      assert(CONFIG_PATCH_FIELD_DEFS[key] ~= nil,
        "Unsupported config patch field for skill " .. self.id .. ": " .. tostring(key))
      nextPatch[key] = nil
    end
  end
  return self:_ApplyConfigPatch(nextPatch, opts)
end

function SingleSkill:GetConfigLevels()
  return self:GetBaseConfig().levels
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

function SingleSkill:GetLastActivateTime()
  return self._lastActivateTime
end

function SingleSkill:GetLastDeactivateTime()
  return self._lastDeactivateTime
end

function SingleSkill:GetActivateCount()
  return self.data.activateCount
end

-- ── 技能状态存储（Persistent State）────────────────────────────────────────────
-- 用于在技能运行期间保存自定义数据，随 data 一起序列化，读档自动恢复。
-- 生命周期完全由开发者控制：Activate 时建议手动 ClearState，Deactivate 时可选择性读取。
-- 被动技能没有 Activate/Deactivate 边界，state 一直保留直到技能被移除。

function SingleSkill:SetState(key, value)
  -- 实体被技能接管：不再由世界系统存档（persists=false），
  -- 由 ArkSkill:OnSave 通过 GetSaveRecord 嵌套保存，读档 SpawnSaveRecord 恢复
  if EntityScript.is_instance(value) then
    value.persists = false
  end
  self.data.state[key] = value
end

function SingleSkill:GetState(key)
  return self.data.state[key]
end

function SingleSkill:HasState(key)
  return self.data.state[key] ~= nil
end

function SingleSkill:RemoveState(key)
  self.data.state[key] = nil
end

function SingleSkill:ClearState()
  self.data.state = {}
end

function SingleSkill:GetAllState()
  return ShallowCopyMap(self.data.state)
end

function SingleSkill:SyncStatus()
  self.manager:SyncSkillStatus(self.id)
end

-- 事件工具方法
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

function SingleSkill:SetOnRecast(fn)
  self:_AddCallback("ark_skill_recast", fn)
end

function SingleSkill:UnsetOnRecast(fn)
  self:_RemoveCallback("ark_skill_recast", fn)
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
-- HookFunction / UnhookFunction / ListenForEvent / RemoveEventCallback /
-- _CleanupOwnedHooks 由 hooks.InstallItemBase(SingleSkill) 注入（见文件末尾）。

-- 仅在激活期间（BUFFING/BULLETING）生效的 hook。
-- 激活时自动挂载，deactivate（含 Cancel）时自动清除，读档恢复时也会正确挂载。
-- fn 签名同 HookFunction。
function SingleSkill:HookFunctionWhileActivating(obj, funcName, fn)
  self:_AddCallback("ark_skill_activate_effect", function()
    self:HookFunction(obj, funcName, fn)
  end)
  self:_AddCallback("ark_skill_deactivate", function()
    self:UnhookFunction(obj, funcName, fn)
  end)
  -- 读档恢复：已处于激活状态则立即挂载
  if self:IsActivating() then
    self:HookFunction(obj, funcName, fn)
  end
end

-- ── 事件监听系统（SingleSkill 层）─────────────────────────────────────────
-- ListenForEvent / RemoveEventCallback / _CleanupOwnedHooks 由共享模块注入。

-- 仅在激活期间（BUFFING/BULLETING）生效的事件监听。
-- 激活时自动注册，deactivate（含 Cancel）时自动移除，读档恢复时也会正确挂载。
-- 签名与 ListenForEvent 相同；无需手动管理生命周期。
function SingleSkill:ListenForEventWhileActivating(event, fn, source)
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
    self._lastDeactivateTime = GetTime()
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
  data.state = {}
  self.manager:SyncSkillStatus(self.id)

  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self._lastDeactivateTime = GetTime()
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
    -- 实体可能已移除（如玩家下线/快照迁移临时玩家被 Remove 时 skill 清理触发），跳过
    if not self.inst:IsValid() then
      return
    end
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
  assert(level >= 1 and level <= maxLevel,
    "Invalid skill level: " .. tostring(level) .. ", max level is: " .. tostring(maxLevel))
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
  local skipSync = cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO and
  math.floor(oldEnergyProgress) == math.floor(data.energyProgress)
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
  data.activateCount = data.activateCount + 1
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

function SingleSkill:Recast(params)
  -- 必须处于激活状态才能重铸
  if not self:IsActivating() then
    return false
  end
  if not params then params = { target = nil, targetPos = nil, force = false } end
  self:_Emit("ark_skill_recast", params)
  return true
end

-- 选择确认后：设 targetPos 并激活
local function ActivateWithTargetPos(self, params, doer, pos)
  params.targetPos = pos
  local canAgain, reasonAgain = self:CanActivate(params)
  if not canAgain then
    if reasonAgain then SayAndVoice(self.inst, reasonAgain) end
    return
  end
  self:Activate(params)
end

function SingleSkill:TryActivate(params)
  if not params then params = {} end

  -- 检查是否需要目标选择器（顶层 targetSelector = 注册表 id）
  local cfg = self:GetConfig()
  local selectorId = cfg.targetSelector

  if selectorId then
    local selector = GetTargetSelector(selectorId)
    if selector then
      -- 快速失败检查（不传 targetPos）
      local can, reason = self:CanActivate(params)
      if not can then
        if reason then SayAndVoice(self.inst, reason) end
        return false
      end

      -- 取消回调缺省：技能未激活无需回滚
      selector:BeginSelecting(self.inst,
        function(doer, pos)
          ActivateWithTargetPos(self, params, doer, pos)
        end
      )
      return
    end
  end

  -- 无选择器路径
  local can, reason = self:CanActivate(params)
  if not can then
    if reason then SayAndVoice(self.inst, reason) end
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
  self:_Emit("ark_skill_bullet_cut", {
    cut = value,
    bulletCount = data.bulletCount
  })
  if data.bulletCount == 0 then
    self:SetEnergyRecovering()
  end
  self.manager:SyncSkillStatus(self.id)
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
  -- 临时技能倒计时
  if data.isTemporary and data.limitTimeInitial > 0 then
    local oldRemaining = data.limitRemaining
    data.limitRemaining = math.max(0, data.limitRemaining - dt)
    if math.floor(oldRemaining) ~= math.floor(data.limitRemaining) then
      self.manager:SyncSkillStatus(self.id)
    end
    if data.limitRemaining <= 0 and not self._removingByTimeout then
      self._removingByTimeout = true
      self.inst:DoTaskInTime(0, function()
        self.manager:RemoveSkill(self.id)
      end)
    end
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
  self.configPatch = DeserializeConfigPatch(saved.configPatch, self.id)
  self.configPatchString = SerializeConfigPatch(self.configPatch)
  self.data = MergeMaps(self.data, stateData)
  self.data.level = math.min(self.data.level or 1, self:GetMaxLevel())
  self.manager:SyncSkillStatus(self.id)
  self:RefreshTag()
  self._lastActivateTime = nil
  self._lastDeactivateTime = nil
end

function SingleSkill:Remove()
  if self.refreshTagTask then
    self.refreshTagTask:Cancel()
    self.refreshTagTask = nil
  end
  self:Cancel() -- 若在激活中，触发 deactivate → OnSkill3Deactivate 等清理 state 实体
  self:Lock()
  if self._cfgOnRemove and not self._removing then
    self._cfgOnRemove(self, {})
  end
  self:_CleanupOwnedHooks() -- 兜底：清理所有未释放的 hook
  self._removing = true
  self.manager:RemoveSkill(self.id)
  -- 兜底：清理读档恢复的实体。
  -- 读档会经历"快照恢复 → SerializeUserSession → Remove"流程，临时玩家 v 恢复的
  -- 实体（如锚点A）若未被 deactivate 移除，此处统一清除，避免与新玩家的实体重复。
  if self._restoredEntities then
    for _, ent in ipairs(self._restoredEntities) do
      if ent and ent:IsValid() then
        ent:Remove()
      end
    end
    self._restoredEntities = nil
  end
end

function ArkSkill:_GetCurrentElite()
  local elite = self.inst.components.ark_elite
  return elite and elite.elite or nil
end

function ArkSkill:CanAddSkill(id)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))
  if self.skillsById[id] then
    return false, "SKILL_ALREADY_LEARNED"
  end
  if #self.installedSkills >= self.inst.replica.ark_skill.maxSkillCount then
    return false, "SKILL_MAX_LIMIT"
  end
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

function ArkSkill:_GetBuiltinSkillTargetLevel(id)
  local profile = self.builtinSkillProfilesById[id]
  return builtinProfile.GetTargetLevelByElite(profile, self:_GetCurrentElite())
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
    local targetLevel = self:_GetBuiltinSkillTargetLevel(id)
    if targetLevel ~= nil and skill:GetLevel() ~= targetLevel then
      skill:SetLevel(math.min(targetLevel, skill:GetMaxLevel()))
    end
  end
end

function ArkSkill:_SyncBuiltinSkills()
  for id in pairs(self.builtinSkillProfilesById) do
    self:_SyncBuiltinSkillState(id)
  end
end

function ArkSkill:DeclareBuiltin(id, profile)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))

  self.builtinSkillProfilesById[id] = builtinProfile.NormalizeProfile(profile, { keepSlot = true })
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
  self.inst:AddTag(common.genArkSkillInstalledTagById(id))
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

function ArkSkill:AddSkill(id, limitTime)
  assert(id, "Skill id is required")
  assert(GetArkSkillConfigById(id), "Config not found for skill id: " .. tostring(id))
  if self.skillsById[id] then
    ArkLogger:Warn("Ark skill already exists for id: " .. tostring(id))
    return
  end
  local skill = self:_InstallSkill(id)
  if limitTime ~= nil then
    skill.data.isTemporary = true
    skill.data.limitTimeInitial = limitTime
    skill.data.limitRemaining = limitTime
    self:SyncSkillStatus(id)
  end
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
    self.inst:RemoveTag(common.genArkSkillInstalledTagById(id))
    self.inst.replica.ark_skill:RemoveSkill(id)
    self.skillsById[id] = nil
    table.removearrayvalue(self.installedSkills, id)
  end
end

-- 便捷的几个方法（by-id）
function ArkSkill:GetSkill(id)
  return self.skillsById[id]
end

function ArkSkill:GetSkillLastActivateTime(id)
  local skill = self:GetSkill(id)
  return skill and skill:GetLastActivateTime() or nil
end

function ArkSkill:GetSkillLastDeactivateTime(id)
  local skill = self:GetSkill(id)
  return skill and skill:GetLastDeactivateTime() or nil
end

-- 获取全部技能
function ArkSkill:GetAllSkills()
  local res = {}
  for _, value in pairs(self.skillsById) do
    table.insert(res, value)
  end
  return res
end

function ArkSkill:SyncSkillStatus(id)
  local s = self:GetSkill(id)
  if not s then
    return
  end
  self.inst.replica.ark_skill:SyncSkillStatus(id, {
    status = s.data.status,
    level = s.data.level,
    energyProgress = s.data.energyProgress,
    buffProgress = s.data.buffProgress,
    bulletCount = s.data.bulletCount,
    activationStacks = s.data.activationStacks,
    configPatch = s:GetConfigPatchString(),
    isTemporary = s.data.isTemporary and 1 or 0,
    limitTimeInitial = s.data.limitTimeInitial or 0,
    limitRemaining = s.data.limitRemaining or 0,
  })
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
  local refs = {}
  for _, id in ipairs(self.installedSkills) do
    local skill = self.skillsById[id]
    if skill then
      table.insert(data.installedSkills, id)
      local savedSkill = {
        data = CopySaveData(skill.data),
        configPatch = skill:GetConfigPatchString() ~= "" and skill:GetConfigPatchString() or nil,
        cfg = nil,
      }
      -- state 中的实体内联为 { _ark_entity_save = record }（GetSaveRecord 嵌套存档），
      -- state 本身自包含、可序列化；实体在 OnLoad 时同步 SpawnSaveRecord 恢复
      if savedSkill.data.state then
        savedSkill.data.state = SerializeState(savedSkill.data.state, refs)
      end
      if skill._cfgOnSave then
        local cfgData = {}
        cfgData = skill._cfgOnSave(skill, cfgData) or cfgData
        savedSkill.cfg = next(cfgData) and cfgData or nil
      end
      data.skills[id] = savedSkill
    end
  end
  return data, refs
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
        -- 同步恢复 state 中的实体（SpawnSaveRecord）。
        -- 不能延后到 LoadPostPass：读档期间快照恢复流程会同步触发 SerializeUserSession，
        -- 若此时实体未恢复，OnSave 会把剥离后的 state 重存成空档覆盖存档。
        DeserializeState(s.data.state, s)
        -- cfg 通道（技能开发者 OnLoad）同样同步调用，避免 LoadPostPass 异步被重存覆盖
        if s._cfgOnLoad then
          s._cfgOnLoad(s, skillData.cfg or {})
        end
      end
    end
  end
  self:_SyncBuiltinSkills()
  if self.inst:HasTag("player") then
    self.inst:DoTaskInTime(0, function()
      self:LoadPostPass(Ents, data)
    end)
  end
end

function ArkSkill:LoadPostPass(newents, data)
  if not data or not data.skills then
    return
  end
  for id, _ in pairs(data.skills) do
    local s = self.skillsById[id]
    -- 实体与 cfg 已在 OnLoad 同步恢复，这里只在读档后补触发激活效果（缓冲一轮，等实体/世界稳定）
    if s and s:IsActivating() then
      s:_EmitActivateEffect({ source = "load" })
    end
  end
end

-- 清理所有技能（含读档恢复的实体）。
-- OnPreRemoveFromEntity（组件被 RemoveComponent 移除，ItemPackage entityscript_extension 调用）
-- 与 OnRemoveEntity（实体被 Remove 移除，EntityScript:Remove 调用，如玩家下线/快照迁移临时玩家）
-- 共用本清理，保证任何路径都释放技能及被接管的实体。
function ArkSkill:_CleanupSkills()
  self.inst:RemoveEventCallback("ark_elite_changed", self._onBuiltinEliteChanged)
  for _, s in pairs(self.skillsById) do
    s:Remove()
  end
end

function ArkSkill:OnPreRemoveFromEntity()
  self:_CleanupSkills()
end

function ArkSkill:OnRemoveEntity()
  self:_CleanupSkills()
end

-- ── Hook 系统（ArkSkill manager 层） ─────────────────────────────────────────
-- SingleSkill 基础设施由共享模块注入：
-- _InitItemBase / _AddCallback / _RemoveCallback / HookFunction / UnhookFunction /
-- ListenForEvent / RemoveEventCallback / _CleanupOwnedHooks
hooks.InstallItemBase(SingleSkill)

return ArkSkill
