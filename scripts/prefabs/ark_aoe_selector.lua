-- 默认配置：reticule 视觉与交互 + aoetargeting 行为
local DEFAULT_CONFIG = {
  reticule = {
    reticuleprefab = "reticuleaoesmall",
    pingprefab = "reticuleaoesmallping",
    validcolour = { 1, .75, 0, 1 },
    invalidcolour = { .5, 0, 0, 1 },
    ease = true,
    mouseenabled = true,
    twinstickmode = 1,
    twinstickrange = 8,
  },
  aoetargeting = {
    allowWater = false,
    deployRadius = 1,
  },
}

-- 将用户配置合并到默认配置，并应用到 inst 的 aoetargeting/reticule
local function ApplyConfig(inst, userConfig)
  -- 浅拷贝默认 reticule 配置
  local reticuleCfg = {}
  for k, v in pairs(DEFAULT_CONFIG.reticule) do
    reticuleCfg[k] = v
  end
  -- 浅拷贝默认 aoetargeting 配置
  local aoeCfg = {}
  for k, v in pairs(DEFAULT_CONFIG.aoetargeting) do
    aoeCfg[k] = v
  end

  -- 合并用户配置
  if userConfig then
    if userConfig.reticule then
      for k, v in pairs(userConfig.reticule) do
        reticuleCfg[k] = v
      end
    end
    if userConfig.aoetargeting then
      for k, v in pairs(userConfig.aoetargeting) do
        aoeCfg[k] = v
      end
    end
  end

  -- 应用到 aoetargeting
  local aoe = inst.components.aoetargeting
  if aoe then
    if aoeCfg.allowWater ~= nil then
      aoe:SetAllowWater(aoeCfg.allowWater)
    end
    if aoeCfg.deployRadius ~= nil then
      aoe:SetDeployRadius(aoeCfg.deployRadius)
    end

    -- 应用 reticule 配置到 aoetargeting.reticule 表
    for k, v in pairs(reticuleCfg) do
      aoe.reticule[k] = v
    end
  end
end

local function OnConfigReady(inst, configStr)
  if configStr and configStr ~= "" then
    local userConfig = json.decode(configStr)
    ApplyConfig(inst, userConfig)
    if ThePlayer and ThePlayer.components.playercontroller then
      ThePlayer.components.playercontroller:StartAOETargetingUsing(inst)
    end
  end
end

local function OnEntityReplicated(inst)
  local replica = inst.replica.inventoryitem
  function replica:IsGrandOwner(guy)
    return guy and self.inst.entity:GetParent() == guy
  end
  -- 处理网络变量先于 OnEntityReplicated 到达的情况
  local configStr = inst._ark_aoe_config and inst._ark_aoe_config:value() or ""
  if configStr ~= "" then
    OnConfigReady(inst, configStr)
  end
end

local function ReticuleTargetAllowWaterFn()
  local player = ThePlayer
  local pos = Vector3()
  for r = 7, 0, -.25 do
    pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
    if TheWorld.Map:IsPassableAtPoint(pos.x, 0, pos.z, true)
        and not TheWorld.Map:IsGroundTargetBlocked(pos) then
      return pos
    end
  end
  return pos
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  --[[Non-networked entity]]
  inst.entity:SetCanSleep(false)

  -- 网络变量：配置字符串
  inst._ark_aoe_config = net_string(inst.GUID, "ark_aoe_selector._config", "ark_aoe_config_dirty")

  inst:AddComponent("spellbook")
  -- 3. 让 spellbook:SelectSpell 返回 true
  inst.components.spellbook.SelectSpell = function(self, id)
    return true -- 总是成功
  end

  -- 4. 让 spellbook:GetSelectedSpell 返回一个值
  inst.components.spellbook.GetSelectedSpell = function(self)
    return 1 -- 返回任意值
  end
  function inst.components.spellbook:CanBeUsedBy(doer)
    return self.inst.entity:GetParent() == doer
  end

  inst:AddComponent("aoetargeting")
  -- 基础设置（不可配置）
  inst.components.aoetargeting.reticule.targetfn = ReticuleTargetAllowWaterFn
  inst.components.aoetargeting:SetShouldRepeatCastFn(nil)
  -- 其他配置由 ApplyConfig 在 OnEntityReplicated 中应用

  function inst.components.aoetargeting:StartTargeting()
    if self.inst.components.reticule == nil then
      self.inst:AddComponent("reticule")
      for k, v in pairs(self.reticule) do
        self.inst.components.reticule[k] = v
      end
      if ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RefreshReticule(self.inst)
      end
    end
  end

  function inst.components.aoetargeting:StopTargeting()
    if self.inst.components.reticule ~= nil then
      self.inst:RemoveComponent("reticule")
      if ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RefreshReticule()
      end
    end
  end

  inst:AddComponent("aoespell")
  inst:ListenForEvent("onremove", function()
    if ThePlayer and ThePlayer.components.playercontroller then
      ThePlayer.components.playercontroller:RefreshReticule()
    end
  end)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
    inst:ListenForEvent("ark_aoe_config_dirty", function()
      local configStr = inst._ark_aoe_config and inst._ark_aoe_config:value() or ""
      OnConfigReady(inst, configStr)
    end)
    inst.OnEntityReplicated = OnEntityReplicated
    return inst
  end
  -- 让action能正常走下去
  inst:AddComponent("inventoryitem")
  function inst.components.inventoryitem:GetGrandOwner()
    return self.inst.entity:GetParent()
  end

  inst:DoTaskInTime(0, OnEntityReplicated)
  inst.persists = false
  return inst
end
return Prefab("ark_aoe_selector", fn, nil)
