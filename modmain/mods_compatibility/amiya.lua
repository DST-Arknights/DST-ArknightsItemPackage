local enable = GetModConfigData('amiya_hecheng_collect')
if not enable then
    return
end

local AmiyaHeCheng = 'amiya_hecheng'

CHARACTER_INGREDIENT[string.upper(AmiyaHeCheng)] = AmiyaHeCheng

local _IsCharacterIngredient = IsCharacterIngredient
function GLOBAL.IsCharacterIngredient(ingredient)
  ArkLogger:Debug('IsCharacterIngredient', ingredient)
  if ingredient == AmiyaHeCheng then
    return true
  end
  return _IsCharacterIngredient(ingredient)
end
-- 放入时自动转为合成玉数值
AddComponentPostInit("inventory", function(self)
  local _GiveItem = self.GiveItem
  function self:GiveItem(item, slot, src_pos)
    if item.prefab == AmiyaHeCheng and not item._ark_allow_inventory and self.inst.components.ark_currency then
      local num = item.components.stackable and item.components.stackable:StackSize() or 1
      self.inst.components.ark_currency:AddArkCurrencyByType('ark_diamond_shd', num)
      item:Remove()
      return
    end
    return _GiveItem(self, item, slot, src_pos)
  end
end)

-- 服务端: HasCharacterIngredient + RemoveIngredients
AddComponentPostInit("builder", function(self)
  -- 检查amiya_hecheng时, 把背包物品数 + ark_diamond_shd货币一起计入
  local _HasCharacterIngredient = self.HasCharacterIngredient
  function self:HasCharacterIngredient(ingredient)
    ArkLogger:Debug('HasCharacterIngredient', ingredient.type)
    if ingredient.type == AmiyaHeCheng and self.inst.components.ark_currency ~= nil then
      -- 先调用原链(Amiya mod的hook)获取背包里的amiya_hecheng物品数
      local _, item_count = _HasCharacterIngredient(self, ingredient)
      item_count = item_count or 0
      local currency = self.inst.components.ark_currency:GetArkCurrencyByType('ark_diamond_shd') or 0
      local total = item_count + currency
      ArkLogger:Debug('HasCharacterIngredient', ingredient.type, item_count, currency, total)
      if total >= ingredient.amount then
        return true, total
      else
        return false, total
      end
    end
    return _HasCharacterIngredient(self, ingredient)
  end

  -- 配方扣除: 优先扣背包里的amiya_hecheng, 不足部分从ark_diamond_shd货币扣
  local _RemoveIngredients = self.RemoveIngredients
  self.RemoveIngredients = function(self, ingredients, recname, discounted)
    if not self.freebuildmode and self.inst.components.ark_currency ~= nil then
      local recipe = AllRecipes[recname]
      if recipe then
        for _, v in pairs(recipe.character_ingredients) do
          if v.type == AmiyaHeCheng then
            -- 通过原链获取背包里实际的amiya_hecheng物品数量
            local _, item_count = _HasCharacterIngredient(self, v)
            item_count = item_count or 0
            local deficit = math.max(0, v.amount - item_count)
            if deficit > 0 then
              self.inst.components.ark_currency:AddArkCurrencyByType('ark_diamond_shd', -deficit)
            end
          end
        end
      end
    end
    return _RemoveIngredients(self, ingredients, recname, discounted)
  end
end)

-- 客户端: HasCharacterIngredient 补充ark_diamond_shd货币计数
AddClassPostConstruct('components/builder_replica', function(self)
  local _HasCharacterIngredient = self.HasCharacterIngredient
  self.HasCharacterIngredient = function(self, ingredient, ...)
    if ingredient.type == AmiyaHeCheng and self.inst.replica.ark_currency ~= nil then
      -- 先调用原链获取背包里的amiya_hecheng物品数
      local _, item_count = _HasCharacterIngredient(self, ingredient, ...)
      item_count = item_count or 0
      local currency = self.inst.replica.ark_currency:GetArkCurrencyByType('ark_diamond_shd') or 0
      local total = item_count + currency
      if total >= ingredient.amount then
        return true, total
      else
        return false, total
      end
    end
    return _HasCharacterIngredient(self, ingredient, ...)
  end
end)