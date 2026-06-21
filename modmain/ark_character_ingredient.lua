-- 自定义配方材料（CharacterIngredient）注册系统
-- 允许任意模组注册自定义材料类型，与 DST 制作系统对接。
--
-- 用法：
--   AddCharacterIngredient(typeName, {
--     Has(inst, amount) -> bool, current        服务端（可选）：判断玩家是否有足够数量
--     Consume(inst, amount)                     服务端：制作时扣除材料
--     HasClient(inst, amount) -> bool, current  客户端（可选，缺省复用 Has）
--   })
--
--   当 Has 缺失时，Has 判定退化为读取 inst[Symbol] 上由 UpdateCharacterIngredient 记录的值。
--
--   UpdateCharacterIngredient(inst, typeName, value)
--     更新 inst 上某类型的当前值，当阶梯等级发生变化时自动通知 UI 刷新配方列表。

local _registry = {}
local _tiers = {}    -- typeName -> 已排序的阶梯值数组
local CI_VALUES = Symbol("character_ingredient_values")  -- 共享存储表

-- ── 内部工具 ──────────────────────────────────────────────────────────────────

-- 计算当前值满足了多少个阶梯（tiers 已排序）
local function GetTierLevel(typeName, value)
  local tiers = _tiers[typeName]
  if not tiers or #tiers == 0 then return 0 end
  local level = 0
  for _, t in ipairs(tiers) do
    if value >= t then
      level = level + 1
    else
      break
    end
  end
  return level
end

local function GetStoredValue(inst, typeName)
  local values = inst[CI_VALUES]
  if not values then return 0 end
  return values[typeName] or 0
end

local function NotifyUI(inst)
  if inst.HUD and inst.HUD.controls.crafttabs then
    inst.HUD.controls.crafttabs:UpdateRecipes()
  end
end

-- ── 收集配方阶梯 ──────────────────────────────────────────────────────────────

AddRecipePostInitAny(function(recipe)
  if recipe.character_ingredients then
    for _, ci in pairs(recipe.character_ingredients) do
      if not _tiers[ci.type] then
        _tiers[ci.type] = {}
      end
      local tiers = _tiers[ci.type]
      local found = false
      for _, t in ipairs(tiers) do
        if t == ci.amount then
          found = true
          break
        end
      end
      if not found then
        table.insert(tiers, ci.amount)
        table.sort(tiers)
      end
    end
  end
end)

-- ── 服务端 builder Hook ───────────────────────────────────────────────────────

local function _hookBuilderHas(next, self, ingredient)
  local handlers = _registry[ingredient.type]
  if handlers then
    if handlers.Has then
      return handlers.Has(self.inst, ingredient.amount)
    end
    local current = GetStoredValue(self.inst, ingredient.type)
    return current >= ingredient.amount, current
  end
  return next(self, ingredient)
end

local function _hookBuilderConsume(next, self, ingredients, recname, discounted)
  if not self.freebuildmode then
    local recipe = AllRecipes[recname]
    if recipe then
      for _, v in pairs(recipe.character_ingredients) do
        local handlers = _registry[v.type]
        if handlers then
          handlers.Consume(self.inst, v.amount)
        end
      end
    end
  end
  return next(self, ingredients, recname, discounted)
end

AddComponentPostInit("builder", function(self)
  ArkHookFunction(self, "HasCharacterIngredient", _hookBuilderHas)
  ArkHookFunction(self, "RemoveIngredients", _hookBuilderConsume)
end)

-- ── 客户端 builder_replica Hook ───────────────────────────────────────────────

local function _hookBuilderReplicaHas(next, self, ingredient, ...)
  local handlers = _registry[ingredient.type]
  if handlers then
    if handlers.HasClient then
      return handlers.HasClient(self.inst, ingredient.amount)
    end
    if handlers.Has then
      return handlers.Has(self.inst, ingredient.amount)
    end
    local current = GetStoredValue(self.inst, ingredient.type)
    return current >= ingredient.amount, current
  end
  return next(self, ingredient, ...)
end

AddClassPostConstruct("components/builder_replica", function(self)
  ArkHookFunction(self, "HasCharacterIngredient", _hookBuilderReplicaHas)
end)

-- ── IsCharacterIngredient Hook ────────────────────────────────────────────────

ArkHookFunction(GLOBAL, "IsCharacterIngredient", function(next, ingredient)
  if ingredient ~= nil and _registry[ingredient] then
    return true
  end
  return next(ingredient)
end)

-- ── 公开 API ──────────────────────────────────────────────────────────────────

-- 更新角色材料数值，阶梯等级变化时通知 UI 刷新
function GLOBAL.UpdateCharacterIngredient(inst, typeName, value)
  if not _registry[typeName] then return end

  local values = inst[CI_VALUES]
  if not values then
    values = {}
    inst[CI_VALUES] = values
  end

  local oldValue = values[typeName] or 0
  local oldLevel = GetTierLevel(typeName, oldValue)
  local newLevel = GetTierLevel(typeName, value)

  values[typeName] = value

  if oldLevel ~= newLevel then
    NotifyUI(inst)
  end
end

function GLOBAL.AddCharacterIngredient(typeName, handlers)
  assert(type(typeName) == "string",
    "AddCharacterIngredient: typeName 必须是字符串")
  assert(type(handlers) == "table",
    "AddCharacterIngredient: handlers 必须是 table")
  assert(type(handlers.Consume) == "function",
    "AddCharacterIngredient: handlers.Consume 必须是函数")

  CHARACTER_INGREDIENT[string.upper(typeName)] = typeName
  _registry[typeName] = handlers
  if handlers.atlas and handlers.image then
    RegisterInventoryItemAtlas(handlers.atlas, handlers.image)
  end
end
