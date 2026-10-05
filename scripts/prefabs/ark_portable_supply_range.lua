local range_scale = 16 * 1.5
return ArkMakeFx({
  name = "ark_portable_supply_range",
  bank = "ark_agoat2_skill1_mist_fx",
  build = "ark_agoat2_skill1_mist_fx",
  anim = "mist",
  loop = true,
  transform = Vector3(range_scale, range_scale, range_scale),
  tint = Vector3(0.20, 0.58, 1.00),
  fn = function (inst)
    inst.AnimState:SetDeltaTimeMultiplier(0.5)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(1)
  end,
})
