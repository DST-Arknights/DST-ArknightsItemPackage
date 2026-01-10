local SpDamageUtil = GLOBAL.require("components/spdamageutil")

SpDamageUtil.DefineSpType("true_damage", {
    -- 真实伤害不考虑防御，所以总是返回0
    GetDefense = function(ent)
        return 0
    end,
})

-- 使用 Symbol 作为缓存标记
local TIMELINE_RESCALED_KEY = GLOBAL.Symbol("timeline_rescaled")
local ORIGINAL_TIMES_KEY = GLOBAL.Symbol("original_times")

local function RescaleTimeline(self, val)
    local timeline = self.currentstate and self.currentstate.timeline
    if not timeline then
        return
    end

    -- 如果要重置（val == nil 或 1）
    if val == nil or val == 1 then
        -- 如果已经是原始状态，无需重置
        if not timeline[TIMELINE_RESCALED_KEY] then
            return
        end
        
        -- 恢复原始时间
        local original_times = timeline[ORIGINAL_TIMES_KEY]
        if original_times then
            for i, v in ipairs(timeline) do
                v.time = original_times[i]
            end
        end
        
        -- 清除标记
        timeline[TIMELINE_RESCALED_KEY] = nil
        timeline[ORIGINAL_TIMES_KEY] = nil
    else
        -- 如果已经缩放过相同的值，跳过
        if timeline[TIMELINE_RESCALED_KEY] == val then
            return
        end
        
        -- 保存原始时间（如果还没保存过）
        if not timeline[ORIGINAL_TIMES_KEY] then
            timeline[ORIGINAL_TIMES_KEY] = {}
            for i, v in ipairs(timeline) do
                timeline[ORIGINAL_TIMES_KEY][i] = v.time
            end
        end
        
        -- 应用新的缩放
        local original_times = timeline[ORIGINAL_TIMES_KEY]
        for i, v in ipairs(timeline) do
            v.time = original_times[i] / val
        end
        
        -- 标记当前缩放值
        timeline[TIMELINE_RESCALED_KEY] = val
    end
end

-- 攻击速度修改器类，类似于 SourceModifierList
local AttackSpeedModifiers = Class(function(self, combat)
    self.combat = combat
    self.modifiers = {} -- { [source] = { [key] = multiplier } }
end)

function AttackSpeedModifiers:SetModifier(source, multiplier, key)
    -- source 可以是对象或字符串
    -- key 是可选的，默认为 ""
    key = key or ""

    local source_key = type(source) == "table" and source or tostring(source)

    if not self.modifiers[source_key] then
        self.modifiers[source_key] = {}

        -- 如果 source 是实体，监听其移除事件
        if type(source) == "table" and source.ListenForEvent then
            source:ListenForEvent("onremove", function()
                self:RemoveAllModifiersFromSource(source_key)
            end)
        end
    end

    self.modifiers[source_key][key] = multiplier
    self:_UpdateAttackSpeed()
end

function AttackSpeedModifiers:RemoveModifier(source, key)
    key = key or ""
    local source_key = type(source) == "table" and source or tostring(source)

    if self.modifiers[source_key] then
        self.modifiers[source_key][key] = nil

        -- 如果该来源没有更多修改器，清理掉
        if next(self.modifiers[source_key]) == nil then
            self.modifiers[source_key] = nil
        end

        self:_UpdateAttackSpeed()
    end
end

function AttackSpeedModifiers:RemoveAllModifiersFromSource(source)
    local source_key = type(source) == "table" and source or tostring(source)

    if self.modifiers[source_key] then
        self.modifiers[source_key] = nil
        self:_UpdateAttackSpeed()
    end
end

function AttackSpeedModifiers:Get()
    -- 计算所有修改器的乘积
    local result = 1
    for _, source_mods in pairs(self.modifiers) do
        for _, multiplier in pairs(source_mods) do
            result = result * multiplier
        end
    end
    return result
end

function AttackSpeedModifiers:_UpdateAttackSpeed()
    local combat = self.combat
    local speed = self:Get()

    if not combat.base_attack_period then
        combat.base_attack_period = combat.min_attack_period
    end

    combat:SetAttackPeriod(combat.base_attack_period / speed)

    if combat.inst.replica and combat.inst.replica.combat then
        combat.inst.replica.combat:SetAttackSpeed(speed)
    end
end

AddComponentPostInit("combat", function(self)
  -- 初始化攻击速度修改器
  self.attackspeedmodifiers = AttackSpeedModifiers(self)

  function self:EnableTrueDamage(enable)
    if enable == nil then
      enable = true
    end
    self.true_damage_enabled = enable
  end

  function self:DisableTrueDamage()
    self.true_damage_enabled = false
  end

  function self:SetAttackSpeed(speed)
    self.attackspeedmodifiers:SetModifier("ark_attack_speed", speed)
  end

  function self:GetAttackSpeed()
    return self.attackspeedmodifiers:Get()
  end
  -- hook
  local _GetAttacked = self.GetAttacked
  function self:GetAttacked(attacker, damage, weapon, stimuli, spdamage)
    -- 作为被攻击者, 如果攻击者启用了真实伤害，则将伤害转换为真实伤害
    if attacker and attacker.components.combat and attacker.components.combat.true_damage_enabled then
      ArkLogger:Trace("combat_extension GetAttacked TrueDamage")
      if spdamage == nil then
        spdamage = {}
      end
      spdamage.true_damage = damage
      damage = 0
      return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage)
    end
    return _GetAttacked(self, attacker, damage, weapon, stimuli, spdamage)
  end
end)

AddClassPostConstruct("components/combat_replica", function(self)
  self._ark_attack_speed = net_float(self.inst.GUID, "combat._ark_attack_speed")
  function self:SetAttackSpeed(speed)
    if TheWorld.ismastersim then
      self._ark_attack_speed:set(speed)
    end
  end
  function self:GetAttackSpeed()
    return self._ark_attack_speed:value()
  end
end)


AddStategraphPostInit("wilson", function(sg)
    local OldAttackOnEnter = sg.states["attack"].onenter
    sg.states["attack"].onenter = function(inst, ...)
        OldAttackOnEnter(inst, ...)
        if not inst.components.rider:IsRiding() and inst.sg.currentstate.name == "attack" then
            local attack_speed = inst.components.combat:GetAttackSpeed()
            if attack_speed ~= 1 then
                inst.AnimState:SetDeltaTimeMultiplier(attack_speed)
                RescaleTimeline(inst.sg, attack_speed)
                if inst.sg.timeout then
                    inst.sg:SetTimeout(inst.sg.timeout / attack_speed)
                end
            end
        end
    end

    local OldAttackOnExit = sg.states["attack"].onexit
    sg.states["attack"].onexit = function(inst, ...)
        OldAttackOnExit(inst, ...)
        inst.AnimState:SetDeltaTimeMultiplier(1)
        RescaleTimeline(inst.sg)
    end
end)

AddStategraphPostInit("wilson_client", function(sg)
    local OldAttackOnEnter = sg.states["attack"].onenter
    sg.states["attack"].onenter = function(inst, ...)
        OldAttackOnEnter(inst, ...)

        if not inst.replica.rider:IsRiding() and inst.sg.currentstate.name == "attack" then
            local attack_speed = inst.replica.combat:GetAttackSpeed()
            if attack_speed ~= 1 then
                inst.AnimState:SetDeltaTimeMultiplier(attack_speed)
                RescaleTimeline(inst.sg, attack_speed)
                if inst.sg.timeout then
                    inst.sg:SetTimeout(inst.sg.timeout / attack_speed)
                end
            end
        end
    end

    local OldAttackOnExit = sg.states["attack"].onexit
    sg.states["attack"].onexit = function(inst, ...)
        OldAttackOnExit(inst, ...)
        inst.AnimState:SetDeltaTimeMultiplier(1)
        RescaleTimeline(inst.sg)
    end
end)