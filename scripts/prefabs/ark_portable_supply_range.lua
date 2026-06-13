return ArkMakeFx({
  name = "ark_portable_supply_range",
  bank = "winona_catapult_placement",
  build = "winona_catapult_placement",
  anim = "idle_16d6",
  loop = true,
  transform = Vector3(1.5, 1.5, 1.5),
  fn = function (inst)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
  end,
})