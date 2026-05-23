local TechTree = require("techtree")

local function NormalizeTechName(name)
    assert(type(name) == "string" and name ~= "", "AddTechBranch: tech name must be a non-empty string")
    return string.upper(name)
end

local function NormalizeRegistryName(name, field_name)
    assert(type(name) == "string" and name ~= "", field_name .. ": name must be a non-empty string")
    return name
end

local function EnsureListValue(list, value)
    if not table.contains(list, value) then
        table.insert(list, value)
    end
end

local function EnsureTechMappings(name)
    local lower = string.lower(name)
    TechTree.AVAILABLE_TECH_BONUS[name] = lower .. "_bonus"
    TechTree.AVAILABLE_TECH_TEMPBONUS[name] = lower .. "_tempbonus"
    TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[name] = lower .. "bonus"
    TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[name] = lower .. "tempbonus"
    TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[name] = lower .. "level"
end

local function FillTechTree(tree)
    if tree ~= nil then
        TechTree.Create(tree)
    end
    return tree
end

local function SyncExistingTechData()
    FillTechTree(TECH.NONE)

    for _, tech in pairs(TECH) do
        FillTechTree(tech)
    end

    for _, tree in pairs(TUNING.PROTOTYPER_TREES) do
        FillTechTree(tree)
    end

    for _, recipe in pairs(AllRecipes) do
        if recipe.level ~= nil then
            recipe.level = FillTechTree(recipe.level)
        end
    end
end

local function MakeTechLevel(name, level)
    return TechTree.Create({
        [name] = level or 0,
    })
end

local function MakeTechTree(tree)
    return TechTree.Create(shallowcopy(tree))
end

local function AddTechRequirement(level_name, tech_name, tech_level)
    level_name = NormalizeRegistryName(level_name, "AddTechRequirement")
    tech_name = NormalizeTechName(tech_name)
    TECH[level_name] = MakeTechLevel(tech_name, tech_level)
    return TECH[level_name]
end

local function AddTechBranch(name, data)
    name = NormalizeTechName(name)
    data = data or {}

    EnsureTechMappings(name)
    EnsureListValue(TechTree.AVAILABLE_TECH, name)

    if data.allow_bonus then
        EnsureListValue(TechTree.BONUS_TECH, name)
    end

    SyncExistingTechData()

    return name
end

local function AddPrototyperTree(tree_name, tree)
    tree_name = NormalizeRegistryName(tree_name, "AddPrototyperTree")
    TUNING.PROTOTYPER_TREES[tree_name] = MakeTechTree(tree)
    return TUNING.PROTOTYPER_TREES[tree_name]
end

GLOBAL.AddTechBranch = AddTechBranch
GLOBAL.AddTechRequirement = AddTechRequirement
GLOBAL.AddPrototyperTree = AddPrototyperTree
