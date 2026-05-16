-- 自定义配方材料（CharacterIngredient）注册系统
-- 允许任意模组注册自定义材料类型，与 DST 制作系统对接。
--
-- 用法：
--   AddCharacterIngredient(typeName, {
--     Has(inst, amount) -> bool, current        服务端：判断玩家是否有足够数量
--     Consume(inst, amount)                     服务端：制作时扣除材料
--     HasClient(inst, amount) -> bool, current  客户端（可选，缺省复用 Has）
--   })

local _registry = {}

-- ── 服务端 builder Hook ───────────────────────────────────────────────────────

local function _hookBuilderHas(next, self, ingredient)
  local handlers = _registry[ingredient.type]
  if handlers then
    return handlers.Has(self.inst, ingredient.amount)
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
    local hasFn = handlers.HasClient or handlers.Has
    return hasFn(self.inst, ingredient.amount)
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

function GLOBAL.AddCharacterIngredient(typeName, handlers)
  assert(type(typeName) == "string",
    "AddCharacterIngredient: typeName 必须是字符串")
  assert(type(handlers) == "table",
    "AddCharacterIngredient: handlers 必须是 table")
  assert(type(handlers.Has) == "function",
    "AddCharacterIngredient: handlers.Has 必须是函数")
  assert(type(handlers.Consume) == "function",
    "AddCharacterIngredient: handlers.Consume 必须是函数")

  CHARACTER_INGREDIENT[string.upper(typeName)] = typeName
  _registry[typeName] = handlers
end
