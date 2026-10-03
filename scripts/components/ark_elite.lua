local CONSTANTS = require "ark_constants"
local SourceModifierList = require("util/sourcemodifierlist")

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

local MAX_OVERFLOW_EXP = 2000000
local HEALTH_BONUS_MODIFIER_KEY = "ark_elite_health_bonus"
local DAMAGE_BONUS_MODIFIER_KEY = "ark_elite_damage_bonus"

local function _clampOverflowExp(value)
  value = math.floor(value or 0)
  if value < 0 then
    return 0
  end
  if value > MAX_OVERFLOW_EXP then
    return MAX_OVERFLOW_EXP
  end
  return value
end

-- 默认击杀经验：击杀取完整经验，巨兽的有效参与额外获得 0.5 倍。
local function DefaultKillExpFn(inst, victim, is_kill, is_participated)
  local health = victim.components and victim.components.health
  if health == nil then
    return 0
  end
  local exp = is_kill and math.floor(health.maxhealth) or 0
  if is_participated and victim:HasTag("epic") then
    exp = exp + math.floor(health.maxhealth * 0.5)
  end
  return exp
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
  self.externalexpmultipliers = SourceModifierList(inst)
  self.externalexpmultipliers:SetModifier("base", 5)
  self._killExpFn = DefaultKillExpFn
  self._apply_elite_task = self.inst:DoTaskInTime(0, function()
    self._apply_elite_task = nil
    self:ApplyElite()
  end)
end, nil, {
  rarity = onrarity,
  elite = onelite,
  level = onlevel,
  currentExp = oncurrentExp,
  overflowExp = onoverflowExp
})
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

-- 获取当前星级下所有精英化阶段的总等级数
function ArkElite:_GetTotalLevels()
  local cfg = CONSTANTS.EXP_CONFIG.maxLevel[self.rarity]
  if not cfg then return 1 end
  local total = 0
  for _, cap in ipairs(cfg) do
    total = total + cap
  end
  return math.max(total, 1)
end

-- 获取当前累计等级（已完成的精英化阶段等级上限之和 + 当前阶段等级）
function ArkElite:_GetCumulativeLevel()
  local cfg = CONSTANTS.EXP_CONFIG.maxLevel[self.rarity]
  if not cfg then return 1 end
  local cumulative = 0
  for i = 1, self.elite - 1 do
    cumulative = cumulative + (cfg[i] or 0)
  end
  cumulative = cumulative + self.level
  return cumulative
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
  local levelUps = 0
  while pool > 0 do
    local levelCap = self:_GetLevelCap()
    if self.level >= levelCap then
      -- 当前精英化阶段已满级：多余经验全部进入 overflow，等待精英化后释放
      -- 若已是最终精英阶段：按"最后一级所需经验"折算伪升级，仍触发升级事件（供满级后继续解锁）
      if self.elite >= _getMaxEliteByRarity(self.rarity) then
        local lastNeed = self.inst.replica.ark_elite:GetLevelUpExp(levelCap - 1)
        if lastNeed and lastNeed > 0 then
          local overflow = (self.overflowExp or 0) + pool
          local pseudo = math.floor(overflow / lastNeed)
          if pseudo > 0 then
            levelUps = levelUps + pseudo
            overflow = overflow - pseudo * lastNeed
          end
          self.overflowExp = _clampOverflowExp(overflow)
        else
          self.overflowExp = _clampOverflowExp((self.overflowExp or 0) + pool)
        end
      else
        self.overflowExp = _clampOverflowExp((self.overflowExp or 0) + pool)
      end
      break
    end

    local need = self.inst.replica.ark_elite:GetLevelUpExp(self.level)
    if need <= 0 then
      -- 配置缺失或异常，直接把剩余经验计入 overflow，避免死循环
      self.overflowExp = _clampOverflowExp((self.overflowExp or 0) + pool)
      break
    end

    local remainToNext = need - self.currentExp
    if remainToNext <= 0 then
      -- 数据异常：强制升一级，重置当前经验
      self.currentExp = 0
      self.level = self.level + 1
      levelUps = levelUps + 1
    else
      if pool >= remainToNext then
        -- 够升一级
        self.currentExp = self.currentExp + remainToNext -- = need
        pool = pool - remainToNext
        -- 升级后当前等级 +1，经验清零
        self.currentExp = 0
        self.level = self.level + 1
        levelUps = levelUps + 1
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
  if self.level ~= oldLevel then
    self:ApplyElite()
  end
  -- 升级事件（含满级伪升级），供外部系统（如自动掌握配方）监听
  if levelUps > 0 then
    self.inst:PushEvent("ark_elite_levelup", { elite = self.elite, level = self.level, count = levelUps })
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
end

-- 增加经验值：负责自动小等级升级与封顶阶段溢出经验的记录
function ArkElite:AddExp(value)
  if not value or value <= 0 then
    return
  end
  value = math.floor(value * self.externalexpmultipliers:Get())
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

  local oldElite = self.elite
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
  self:ApplyElite()
  if oldElite ~= self.elite then
    self.inst:PushEvent("ark_elite_changed", {
      oldElite = oldElite,
      newElite = self.elite,
      level = self.level,
    })
  end
  return true
end

-- 精英化提升：保持经验校验，通过后调用下一阶段 SetElite
function ArkElite:EliteUp()
  if not self:CanEliteUp() then
    return false
  end
  return self:SetElite(self.elite + 1)
end

function ArkElite:SetOnApplyElite(fn)
  self._onApplyElite = fn
end

-- 设置满级属性奖励上限（由角色 prefab 初始化时调用）
function ArkElite:SetMaxHealthBonus(value)
  self.maxHealthBonus = value or 0
end

function ArkElite:GetHealthBonus()
  local ratio = self:_GetCumulativeLevel() / self:_GetTotalLevels()
  local value = self.maxHealthBonus and (self.maxHealthBonus * ratio) or 0
  return value >= 0 and math.floor(value) or math.ceil(value)
end

function ArkElite:SetMaxDamageBonus(value)
  self.maxDamageBonus = value or 0
end

function ArkElite:SetMaxDefenseBonus(value)
  self.maxDefenseBonus = value or 0
end

-- fn(inst, victim, is_kill, is_participated) 返回基础经验，随后由 AddExp 应用倍率。
-- 设置 nil 表示完全退出击杀及参与经验结算，不影响其他 AddExp 来源。
function ArkElite:SetKillExpFn(fn)
  assert(fn == nil or type(fn) == "function", "kill experience calculator must be a function or nil")
  self._killExpFn = fn
end

function ArkElite:IsKillExpEnabled()
  return self._killExpFn ~= nil
end

-- is_participated 表示死亡前存在有效的非致命命中记录，由世界监听统一合并。
function ArkElite:OnKill(victim, is_kill, is_participated)
  if not self:IsKillExpEnabled() or victim == nil or not (is_kill or is_participated) then
    return
  end
  self:AddExp(self._killExpFn(self.inst, victim, is_kill == true, is_participated == true))
end

-- 根据累计等级 / 总等级比例，应用属性奖励
-- Strip：把旧的奖励从属性上扣掉，回到干净的基础值
function ArkElite:_StripBonuses()
  local health = self.inst.components.health
  local combat = self.inst.components.combat

  if health then
    health.maxhealthaddmodifiers:RemoveModifier(HEALTH_BONUS_MODIFIER_KEY)
  end

  if combat then
    combat.defaultdamageaddmodifiers:RemoveModifier(DAMAGE_BONUS_MODIFIER_KEY)
  end

  if health then
    health.externalabsorbmodifiers:RemoveModifier(self.inst, "ark_elite_defense")
  end
end

-- Apply：根据当前累计等级从零开始叠加奖励
function ArkElite:_ApplyBonuses()
  local totalLevels = self:_GetTotalLevels()
  local cumulativeLevel = self:_GetCumulativeLevel()
  local ratio = cumulativeLevel / totalLevels
  local health = self.inst.components.health
  local combat = self.inst.components.combat

  -- 生命上限奖励（支持负值：生命随成长降低的角色，负值向零舍入避免多扣）
  if health then
    local bonus = self:GetHealthBonus()
    if bonus ~= 0 then
      ArkLogger:Debug("Applying health bonus", bonus, "ratio", ratio, "cumulativeLevel", cumulativeLevel, "totalLevels", totalLevels)
      health.maxhealthaddmodifiers:SetModifier(HEALTH_BONUS_MODIFIER_KEY, bonus)
    else
      health.maxhealthaddmodifiers:RemoveModifier(HEALTH_BONUS_MODIFIER_KEY)
    end
  end

  -- 攻击力奖励
  if combat then
    local bonus = self.maxDamageBonus and self.maxDamageBonus > 0 and math.floor(self.maxDamageBonus * ratio) or 0
    if bonus > 0 then
      combat.defaultdamageaddmodifiers:SetModifier(DAMAGE_BONUS_MODIFIER_KEY, bonus)
    else
      combat.defaultdamageaddmodifiers:RemoveModifier(DAMAGE_BONUS_MODIFIER_KEY)
    end
  end

  -- 防御奖励（通过 externalabsorbmodifiers 应用，值为 0~1 的吸收比例）
  if health then
    local bonus = self.maxDefenseBonus and self.maxDefenseBonus > 0 and self.maxDefenseBonus * ratio or 0
    if bonus > 0 then
      health.externalabsorbmodifiers:SetModifier(self.inst, bonus, "ark_elite_defense")
    else
      health.externalabsorbmodifiers:RemoveModifier(self.inst, "ark_elite_defense")
    end
  end
end

function ArkElite:ApplyElite()
  if self._apply_elite_task then
    self._apply_elite_task:Cancel()
    self._apply_elite_task = nil
  end
  if self._onApplyElite then
    self._onApplyElite(self.inst, self.elite, self.level)
  end
  -- 2) Apply：内部会自行回收旧奖励并重算当前奖励
  self:_ApplyBonuses()
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
  local oldElite = self.elite
  if data then
    self.potential = data.potential or self.potential
    self.elite = data.elite or self.elite
    self.level = data.level or self.level
    self.currentExp = data.currentExp or self.currentExp
    self.totalExp = data.totalExp or self.totalExp
    self.overflowExp = _clampOverflowExp(data.overflowExp or self.overflowExp)
  end
  self:ApplyElite()
  if data and oldElite ~= self.elite then
    self.inst:PushEvent("ark_elite_changed", {
      oldElite = oldElite,
      newElite = self.elite,
      level = self.level,
      source = "load",
    })
  end
end

function ArkElite:OnRemoveFromEntity()
  if self._apply_elite_task then
    self._apply_elite_task:Cancel()
    self._apply_elite_task = nil
  end
  self:_StripBonuses()
end

return ArkElite
