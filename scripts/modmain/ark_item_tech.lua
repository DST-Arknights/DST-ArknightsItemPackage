local TechTree = require('techtree')

table.insert(TechTree.AVAILABLE_TECH, 'ARK_ITEM_TECH')

TECH.NONE.ARK_ITEM_TECH = 0
TECH.ARK_PROCESSING_ONE = { ARK_ITEM_TECH = 1}

for k,v in pairs(TUNING.PROTOTYPER_TREES) do
  v.ARK_ITEM_TECH = 0
end

TUNING.PROTOTYPER_TREES.ARK_PROCESSING_STATION_ONE = TechTree.Create({
  ARK_ITEM_TECH = 1,
})


for i, v in pairs(AllRecipes) do
	v.level.ARK_ITEM_TECH = v.level.ARK_ITEM_TECH or 0
end