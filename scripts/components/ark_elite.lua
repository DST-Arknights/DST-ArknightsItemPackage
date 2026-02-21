local common = require "ark_common"
local CONSTANTS = require "ark_constants"

local function onrarity(self, value)
  self.inst.replica.ark_elite.state.rarity = value
end
local function onelite(self, value)
  self.inst.replica.ark_elite.state.elite = value
end
local function onlevel(self, value)
  self.inst.replica.ark_elite.state.level = value
end
local function oncurrentExp(self, value)
  self.inst.replica.ark_elite.state.currentExp = value
end

local function onoverflowExp(self, value)
  self.inst.replica.ark_elite.state.overflowExp = value
end

-- 杀怪回经验
local function OnKilled(inst, data)
  if not inst:HasTag("player") then
    return
  end
  local target = data.victim
  if not target then
    return
  end
  if not inst.components.ark_elite then
    return
  end
  -- 获取目标血量, 指定用户增加被击杀生物的最大血量数量的经验
  local health = target.components.health.maxhealth
  local exp = math.floor(health)
  inst.components.ark_elite:AddExp(exp)
end

local ArkElite = Class(function(self, inst)
  self.inst = inst
  self.rarity = 1
  self.potential = 1
  self.elite = 1
  self.level = 1
  self.currentExp = 0
  self.totalExp = 0
  self.overflowExp = 0
  self:RefreshLevelTag()
  self:ApplyElite()
  self.inst:ListenForEvent("killed", OnKilled)
end, nil, {
  rarity = onrarity,
  elite = onelite,
  level = onlevel,
  currentExp = oncurrentExp,
  overflowExp = onoverflowExp
})

function ArkElite:RefreshLevelTag()
  -- 下一帧任务
  if self._refreshLevelTagTask then
    return
  end
  self._refreshLevelTagTask = self.inst:DoTaskInTime(0, function()
    self._refreshLevelTagTask = nil
    if self:CanEliteUp() then
      local tag = common.genArkEliteLevelUpPrefabName(self.inst.prefab, self.elite)
      self.inst:AddTag(tag)
    else
      -- 循环删除所有tag
      for i = 1, self.elite do
        local tag = common.genArkEliteLevelUpPrefabName(self.inst.prefab, i)
        self.inst:RemoveTag(tag)
      end
    end
  end)
end
----------------------------------------------------------
-- 内部工具函数
----------------------------------------------------------

local function _getMaxEliteByRarity(rarity)
  local cfg = CONSTANTS.EXP_CONFIG.maxLevel[rarity]
  return cfg and #cfg or 0
end

-- 当前阶段的封顶等级
function ArkElite:_GetLevelCap()
  return self.inst.replica.ark_elite:GetLevelCap()
end



-- 从一个经验池中推进等级（不跨精英化阶段）
-- countToTotal 为 true 时会累计到 totalExp，用于正常战斗获得经验；
-- 为 false 时用于精英化后释放 overflowExp，不重复统计。
function ArkElite:_ApplyExpPool(amount, countToTotal)
  if not amount or amount <= 0 then
    return
  end
  local oldLevel = self.level
  local pool = amount
  while pool > 0 do
    local levelCap = self:_GetLevelCap()
    if self.level >= levelCap then
      -- 当前精英化阶段已满级：多余经验全部进入 overflow，等待精英化后释放
      self.overflowExp = (self.overflowExp or 0) + pool
      break
    end

    local need = self.inst.replica.ark_elite:GetLevelUpExp(self.level)
    if need <= 0 then
      -- 配置缺失或异常，直接把剩余经验计入 overflow，避免死循环
      self.overflowExp = (self.overflowExp or 0) + pool
      break
    end

    local remainToNext = need - self.currentExp
    if remainToNext <= 0 then
      -- 数据异常：强制升一级，重置当前经验
      self.currentExp = 0
      self.level = self.level + 1
    else
      if pool >= remainToNext then
        -- 够升一级
        self.currentExp = self.currentExp + remainToNext -- = need
        pool = pool - remainToNext
        -- 升级后当前等级 +1，经验清零
        self.currentExp = 0
        self.level = self.level + 1
      else
        -- 还不够升级，只增加当前等级内经验
        self.currentExp = self.currentExp + pool
        pool = 0
      end
    end
  end

  if countToTotal and amount > 0 then
    self.totalExp = self.totalExp + amount
  end
  self:RefreshLevelTag()
  if self.level ~= oldLevel then
    self:ApplyElite()
  end
end
----------------------------------------------------------
-- 对外接口（供其它系统 / RPC 调用）
----------------------------------------------------------

-- 设置角色星级（改变星级后会按新星级的配置校正精英化与等级）
function ArkElite:SetRarity(rarity)
  self.rarity = rarity or self.rarity
  local maxElite = _getMaxEliteByRarity(self.rarity)
  if maxElite > 0 and self.elite > maxElite then
    self.elite = maxElite
  end
  local levelCap = self:_GetLevelCap()
  if self.level > levelCap then
    self.level = levelCap
    self.currentExp = 0
  end
  self:RefreshLevelTag()
end

-- 增加经验值：负责自动小等级升级与封顶阶段溢出经验的记录
function ArkElite:AddExp(value)
  if not value or value <= 0 then
    return
  end
  self:_ApplyExpPool(value, true)
end

-- 是否可以进行精英化提升（由星级 + 精英化配置决定）
function ArkElite:CanEliteUp()
  return self.inst.replica.ark_elite:IsAtLevelCap()
end

-- 强制设置精英化阶段（无视当前经验是否满级），并释放 overflowExp
function ArkElite:SetElite(elite)
  if elite == nil then
    return false
  end

  local targetElite = math.floor(elite)
  local maxElite = _getMaxEliteByRarity(self.rarity)
  if maxElite <= 0 then
    return false
  end

  if targetElite < 1 then
    targetElite = 1
  elseif targetElite > maxElite then
    targetElite = maxElite
  end

  self.elite = targetElite
  self.level = 1
  self.currentExp = 0

  -- 释放在上一阶段积攒的经验，但不重复计入 totalExp
  local overflow = self.overflowExp or 0
  self.overflowExp = 0
  if overflow > 0 then
    self:_ApplyExpPool(overflow, false)
  end

  ArkLogger:Debug("ark_elite elite up", self.inst, self.elite, self.level)
  if self.inst.components.builder then
    if self.elite == 2 then
      self.inst.components.builder:UnlockRecipesForTech(TECH.ARK_ELITE_ONE)
    elseif self.elite == 3 then
      self.inst.components.builder:UnlockRecipesForTech(TECH.ARK_ELITE_TWO)
    end
  end
  self:RefreshLevelTag()
  self:ApplyElite()
  return true
end

-- 精英化提升：保持经验校验，通过后调用下一阶段 SetElite
function ArkElite:EliteUp()
  if not self:CanEliteUp() then
    return false
  end
  return self:SetElite(self.elite + 1)
end

function ArkElite:OnApplyElite(fn)
  self._onApplyElite = fn
end

function ArkElite:ApplyElite()
  -- 下一帧任务
  if self._applyEliteTask then
    return
  end
  self._applyEliteTask = self.inst:DoTaskInTime(0, function()
    self._applyEliteTask = nil
    if self._onApplyElite then
      self._onApplyElite(self.inst, self.elite, self.level)
    end
  end)
end

function ArkElite:OnSave()
  local data = {
    potential = self.potential,
    elite = self.elite,
    level = self.level,
    currentExp = self.currentExp,
    totalExp = self.totalExp,
    overflowExp = self.overflowExp,
  }
  return data
end

function ArkElite:OnLoad(data)
  if data then
    self.potential = data.potential or self.potential
    self.elite = data.elite or self.elite
    self.level = data.level or self.level
    self.currentExp = data.currentExp or self.currentExp
    self.totalExp = data.totalExp or self.totalExp
    self.overflowExp = data.overflowExp or self.overflowExp
  end
  self:RefreshLevelTag()
  self:ApplyElite()
end

function ArkElite:OnRemoveFromEntity()
  if self._refreshLevelTagTask then
    self._refreshLevelTagTask:Cancel()
    self._refreshLevelTagTask = nil
  end
  if self._applyEliteTask then
    self._applyEliteTask:Cancel()
    self._applyEliteTask = nil
  end
  self.inst:RemoveEventCallback("killed", OnKilled)
end

return ArkElite
