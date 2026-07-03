TUNING.SYMPATHETIC_PENDANT = {
  SPEED_MULT = 1.02,
}
AddPlayerPostInit(function(inst)
  if not TheWorld.ismastersim then
    return
  end

  if inst.components.sympathetic_pendant == nil then
    inst:AddComponent("sympathetic_pendant")
  end
end)


AddRecipe2('sympathetic_pendant', {
  Ingredient("yellowamulet", 1),
  Ingredient("redgem", 2),
  Ingredient("bluegem", 2),
  Ingredient("yellowgem", 2),
  Ingredient("greengem", 2),
}, TECH.MAGIC_THREE, {
  force_hint = true,
}, {
  "MAGIC",
  "LIGHT",
  "CHARACTER",
  "MODS",
})
