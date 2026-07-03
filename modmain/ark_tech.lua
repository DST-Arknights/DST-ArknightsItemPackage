AddTechBranch("ARK_ITEM_TECH")
AddTechRequirement("ARK_ITEM_ONE", "ARK_ITEM_TECH", 1)
AddPrototyperTree('ARK_WORKSHOP_ONE', {
  ARK_ITEM_TECH = 1,
})

AddTechBranch("ARK_TRAINING_TECH")
AddTechRequirement("ARK_TRAINING_ONE", "ARK_TRAINING_TECH", 1)
AddPrototyperTree('ARK_TRAINING_ROOM_ONE', {
  ARK_TRAINING_TECH = 1,
})

AddTechBranch("ARK_ELITE_TECH")
AddTechRequirement("ARK_ELITE_ONE", "ARK_ELITE_TECH", 1)
AddTechRequirement("ARK_ELITE_TWO", "ARK_ELITE_TECH", 2)

AddPrototyperDef('ark_workshop', {
  icon_atlas = "images/ark_workshop_prototyper.xml",
  icon_image = "ark_workshop_prototyper.tex",
  is_crafting_station = true,
  action_str = 'ARK_WORKSHOP',
  filter_text = STRINGS.UI.CRAFTING_FILTERS.ARK_WORKSHOP
})

RegisterInventoryItemAtlas("images/ark_workshop.xml", "ark_workshop.tex")
-- 制造站
AddRecipe2('ark_workshop', {
  Ingredient('charcoal', 10),
}, TECH.SCIENCE_TWO, {
  placer = 'ark_workshop_placer',
  force_hint = true,
}, { "MODS", "PROTOTYPERS", "STRUCTURES" })

-- 训练室
AddPrototyperDef('ark_training_room', {
  icon_atlas = "images/ark_training_room_prototyper.xml",
  icon_image = "ark_training_room_prototyper.tex",
  is_crafting_station = true,
  action_str = 'ARK_TRAINING_ROOM',
  filter_text = STRINGS.UI.CRAFTING_FILTERS.ARK_TRAINING_ROOM
})

RegisterInventoryItemAtlas("images/ark_training_room.xml", "ark_training_room.tex")

AddRecipe2("ark_training_room",
  { Ingredient("boards", 4), Ingredient("goldnugget", 2) },
  TECH.SCIENCE_TWO,
  {
    placer = 'ark_training_room_placer',
    force_hint = true,
  },
  { "MODS", "PROTOTYPERS", "STRUCTURES" }
)

AddClassPostConstruct("widgets/redux/craftingmenu_widget", function(self)
  ArkHookFunction(self, "OnCraftingMenuOpen", function(next, self, set_focus)
    local builder = self.owner ~= nil and self.owner.replica.builder or nil
    local prototyper = builder ~= nil and builder:GetCurrentPrototyper() or nil
    local def = prototyper ~= nil and PROTOTYPER_DEFS[prototyper.prefab] or nil

    if def ~= nil and def.skip_default_station_focus then
      local old_is_crafting_station = def.is_crafting_station
      def.is_crafting_station = false

      local ok, result = pcall(next, self, set_focus)

      def.is_crafting_station = old_is_crafting_station

      if not ok then
        error(result)
      end

      return result
    end

    return next(self, set_focus)
  end)
end)
