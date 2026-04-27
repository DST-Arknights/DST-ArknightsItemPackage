local DEFAULT_RANGE_SCALE = 3.0

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")

  inst.entity:SetCanSleep(false)

  inst.AnimState:SetBank("winona_catapult_placement")
  inst.AnimState:SetBuild("winona_catapult_placement")
  inst.AnimState:PlayAnimation("idle_16d6", true)
  inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
  inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
  inst.AnimState:SetSortOrder(3)
  inst.AnimState:SetLightOverride(1)

  inst.Transform:SetScale(DEFAULT_RANGE_SCALE, DEFAULT_RANGE_SCALE, DEFAULT_RANGE_SCALE)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst.persists = false

  function inst:SetDisplayScale(scale)
    scale = tonumber(scale) or DEFAULT_RANGE_SCALE
    self.Transform:SetScale(scale, scale, scale)
  end

  return inst
end

return Prefab("ark_portable_supply_range", fn)