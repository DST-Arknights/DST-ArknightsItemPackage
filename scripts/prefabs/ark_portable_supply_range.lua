return ArkMakeFx({
  name = "ark_portable_supply_range",
  bank = "winona_catapult_placement",
  build = "winona_catapult_placement",
  anim = "idle_16d6",
  loop = true,
  fn = function (inst)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.Transform:SetScale(10/8, 10/8, 10/8)
  end,
})