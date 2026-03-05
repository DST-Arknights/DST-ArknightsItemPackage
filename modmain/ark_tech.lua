local TechTree = require('techtree')
table.insert(TechTree.AVAILABLE_TECH, 'ARK_ITEM_TECH')
table.insert(TechTree.AVAILABLE_TECH, 'ARK_TRAINING_TECH')
table.insert(TechTree.AVAILABLE_TECH, 'ARK_ELITE_TECH')

TECH.NONE.ARK_ITEM_TECH = 0
TECH.ARK_ITEM_ONE = { ARK_ITEM_TECH = 1}
TECH.NONE.ARK_TRAINING_TECH = 0
TECH.ARK_TRAINING_ONE = { ARK_TRAINING_TECH = 1}
TECH.NONE.ARK_ELITE_TECH = 0
TECH.ARK_ELITE_ONE = { ARK_ELITE_TECH = 1}
TECH.ARK_ELITE_TWO = { ARK_ELITE_TECH = 2}

for k,v in pairs(TUNING.PROTOTYPER_TREES) do
  v.ARK_ITEM_TECH = 0
  v.ARK_TRAINING_TECH = 0
  v.ARK_ELITE_TECH = 0
end

TUNING.PROTOTYPER_TREES.ARK_WORKSHOP_ONE = TechTree.Create({
  ARK_ITEM_TECH = 1,
})
TUNING.PROTOTYPER_TREES.ARK_TRAINING_ROOM_ONE = TechTree.Create({
  ARK_TRAINING_TECH = 1,
})
TUNING.PROTOTYPER_TREES.ARK_ELITE_ONE = TechTree.Create({
  ARK_ELITE_TECH = 1,
})
TUNING.PROTOTYPER_TREES.ARK_ELITE_TWO = TechTree.Create({
  ARK_ELITE_TECH = 2,
})

for i, v in pairs(AllRecipes) do
	v.level.ARK_ITEM_TECH = v.level.ARK_ITEM_TECH or 0
  v.level.ARK_TRAINING_TECH = v.level.ARK_TRAINING_TECH or 0
  v.level.ARK_ELITE_TECH = v.level.ARK_ELITE_TECH or 0
end

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
}, {"MODS", "PROTOTYPERS", "STRUCTURES" })

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
  {Ingredient("boards", 4), Ingredient("goldnugget", 2)},
  TECH.SCIENCE_TWO,
  {
    placer = 'ark_training_room_placer',
    force_hint = true,
  },
  { "MODS", "PROTOTYPERS", "STRUCTURES" }
)
