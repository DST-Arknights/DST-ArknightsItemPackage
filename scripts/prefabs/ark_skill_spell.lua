-- local function ReticuleTargetAllowWaterFn()
-- 	local player = ThePlayer
-- 	local ground = TheWorld.Map
-- 	local pos = Vector3()
-- 	--Cast range is 8, leave room for error
-- 	--4 is the aoe range
-- 	for r = 7, 0, -.25 do
-- 		pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
-- 		if ground:IsPassableAtPoint(pos.x, 0, pos.z, true) and not ground:IsGroundTargetBlocked(pos) then
-- 			return pos
-- 		end
-- 	end
-- 	return pos
-- end

local function OnEntityReplicated(inst)
  local replica = inst.replica.inventoryitem
  function replica:IsGrandOwner(guy)
    return guy and self.inst.entity:GetParent() == guy
  end

  if ThePlayer and ThePlayer.components.playercontroller then
    ThePlayer.components.playercontroller:StartAOETargetingUsing(inst)
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
  inst.components.aoetargeting:SetAllowWater(true)
  inst.components.aoetargeting.reticule.targetfn = ReticuleTargetAllowWaterFn
  inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
  inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
  inst.components.aoetargeting.reticule.ease = true
  inst.components.aoetargeting.reticule.mouseenabled = true
  inst.components.aoetargeting.reticule.twinstickmode = 1
  inst.components.aoetargeting.reticule.twinstickrange = 8



  inst.components.aoetargeting:SetDeployRadius(1)
  inst.components.aoetargeting:SetShouldRepeatCastFn(nil)
  inst.components.aoetargeting.reticule.reticuleprefab = "reticuleaoe_1_6"
  inst.components.aoetargeting.reticule.pingprefab = "reticuleaoeping_1_6"

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
    if inst.onstoptargetingfn then
      inst.onstoptargetingfn(inst)
    end
  end

  inst:AddComponent("aoespell")
  inst:ListenForEvent("onremove", function()
    ArkLogger:Debug("AOE selector removed", inst)
    if ThePlayer and ThePlayer.components.playercontroller then
      ThePlayer.components.playercontroller:RefreshReticule()
    end
  end)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
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
return Prefab("ark_skill_spell", fn, nil)
