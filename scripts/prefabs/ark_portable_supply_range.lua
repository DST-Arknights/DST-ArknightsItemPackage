local range_scale = 16 * 1.5
return ArkMakeFx({
  name = "ark_portable_supply_range",
  bank = "ark_agoat2_skill1_mist_fx",
  build = "ark_agoat2_skill1_mist_fx",
  anim = "mist",
  loop = true,
  transform = Vector3(range_scale, range_scale, range_scale),
  tint = Vector3(0.30, 0.70, 1.00),
  tintalpha = 0.42,
  fn = function (inst)
    -- FX 子实体仍会让鼠标命中父物体，范围图使用 DECOR 排除悬停。
    inst:RemoveTag("FX")
    inst:AddTag("DECOR")
    inst:AddTag("NOCLICK")
    inst.AnimState:SetDeltaTimeMultiplier(0.5)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    -- inst.AnimState:SetLayer(LAYER_BACKGROUND)
    -- inst.AnimState:SetSortOrder(1)
  end,
})
