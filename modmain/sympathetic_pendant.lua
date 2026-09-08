TUNING.SYMPATHETIC_PENDANT = {
  SPEED_MULT = 1.02,
  TEMP = 24,
}

AddPrefabPostInit("world", function(inst)
  if TheNet:GetIsServer() then
    inst:AddComponent("sympathetic_pendant_data")
  end
end)

AddPlayerPostInit(function(inst)
  if not TheWorld.ismastersim then
    return
  end

  if inst.components.sympathetic_pendant == nil then
    inst:AddComponent("sympathetic_pendant")
  end
end)


AddRecipe2('sympathetic_pendant', {
  Ingredient("yellowamulet", 6),
  Ingredient("redgem", 6),
  Ingredient("bluegem", 6),
  Ingredient("yellowgem", 6),
  Ingredient("greengem", 6),
}, TECH.MAGIC_THREE, {
  force_hint = true,
}, {
  "MAGIC",
  "LIGHT",
  "ARK_TECHNOLOGY",
  "MODS",
})
