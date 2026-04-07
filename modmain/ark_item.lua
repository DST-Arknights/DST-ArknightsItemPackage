local arkItemDeclare = require "ark_item_declare"
local common = require "ark_common"
local utils = require "ark_utils"

local function addItemRecipe(item)
  if not item.recipe then return end
  for i = 1, #item.recipe do
    local recipe = item.recipe[i]
    local ingredients = {}
    for k = 1, #recipe do
      local ingredient = recipe[k]
      table.insert(ingredients, Ingredient(ingredient.prefab, ingredient.count))
    end
    local assetsCode = common.getPrefabAssetsCode(item.prefab)
    local recipeCode = item.prefab
    AddRecipe2(recipeCode, ingredients, TECH.ARK_ITEM_ONE, {
      nounlock = true,
      atlas = assetsCode.atlas,
      image = assetsCode.image
    })
  end
end

local dropMap = {}
local function addItemDrop(item)
  if not item.drop then return end
  for i = 1, #item.drop do
    local drop = item.drop[i]
    if not dropMap[drop.prefab] then
      dropMap[drop.prefab] = {}
    end
    table.insert(dropMap[drop.prefab], {
      prefab = item.prefab,
      adapter = drop.adapter or 'AddChanceLoot',
      value = drop.value or 1
    })
  end
end


local function componentArkCurrentItem(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  assert(args.currencyType, 'currencyType is required')
  assert(args.value, 'value is required')
  inst:AddComponent('ark_currency_item')
  inst.components.ark_currency_item:AddPrice(args)
end

local function componentEdible(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  inst:AddComponent('edible')
  inst.components.edible.foodtype = args.foodtype or FOODTYPE.GENERIC
  inst.components.edible.healthvalue = args.healthvalue or 0
  inst.components.edible.hungervalue = args.hungervalue or 0
  inst.components.edible.sanityvalue = args.sanityvalue or 0
  inst.components.edible.secondaryfoodtype = args.secondaryfoodtype or nil
  inst.components.edible.sanityvalue = args.sanityvalue or 0
  inst.components.edible.temperaturedelta = args.temperaturedelta or 0
  inst.components.edible.temperatureduration = args.temperatureduration or 0
  inst.components.edible.nochill = args.nochill or nil
  inst.components.edible.spice = args.spice or nil
  if args.oneatenfn then
    inst.components.edible:SetOnEatenFn(args.oneatenfn)
  elseif args.oneatenbuffs then
    for _, buff in ipairs(args.oneatenbuffs) do
      inst.components.edible:SetOnEatenFn(function(inst, eater)
        if type(buff) == 'string' then
          eater:AddDebuff(buff, buff)
        elseif type(buff) == 'table' then
          eater:AddDebuff(buff.name, buff.prefab, buff.data, buff.skin_test, buff.pref_buff_fn)
          return
        end
      end)
    end
  end
end

local function MakeMediumBurnable(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  GLOBAL.MakeMediumBurnable(inst, args.time, args.offset, args.structure, args.sym)
end

local function MakeSmallBurnable(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  GLOBAL.MakeSmallBurnable(inst, args.time, args.offset, args.structure, args.sym)
end

local function MakeLargeBurnable(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  GLOBAL.MakeLargeBurnable(inst, args.time, args.offset, args.structure, args.sym)
end

local function ComponentFuel(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  inst:AddComponent("fuel")
  inst.components.fuel.fuelvalue = args.fuelvalue or 0
  inst.components.fuel.fueltype = args.fueltype or FUELTYPE.BURNABLE
  if args.ontakefn then
    inst.components.fuel:SetOnTakenFn(args.ontakefn)
  end
end

local function ComponentExplosive(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  MakeSmallBurnable(inst, {
    time = 3 + math.random() * 3
  })
  MakeSmallPropagator(inst)
  inst.components.burnable:SetOnBurntFn(nil)
  inst.components.burnable:SetOnIgniteFn(function(inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_fuse_LP", "hiss")
    DefaultBurnFn(inst)
end)
  inst.components.burnable:SetOnExtinguishFn(function(inst)
    inst.SoundEmitter:KillSound("hiss")
    DefaultExtinguishFn(inst)
end)
  inst:AddComponent("explosive")
  inst.components.explosive:SetOnExplodeFn(function(inst)
    inst.SoundEmitter:KillSound("hiss")
    SpawnPrefab("explode_small").Transform:SetPosition(inst.Transform:GetWorldPosition())
  end)
  inst.components.explosive.explosivedamage = TUNING.GUNPOWDER_DAMAGE

end

-- 作为燃料添加后爆炸
local function componentFuelExplosive(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  ComponentFuel(inst, args)
  ComponentExplosive(inst, args)
  inst.components.fuel:SetOnTakenFn(function(inst, target)
    if not target then
      return
    end
    local newPrefab = SpawnPrefab(inst.prefab)
    newPrefab.Transform:SetPosition(target.Transform:GetWorldPosition())
    -- 点燃
    newPrefab.components.burnable:Ignite()
  end)
end

local function componentPreservative(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  inst:AddComponent("preservative")
  inst.components.preservative.percent_increase = args.percent_increase or 0
end

local template = {
  -- 物品使用后可以增加货币的组件
  -- @param inst
  -- @param args.currencyType 金币类型
  -- @param args.value 价格
  componentArkCurrentItem = componentArkCurrentItem,
  -- 可食用物品组件
  -- @param inst
  -- @param args.foodtype 食物类型
  -- @param args.healthvalue 食用后增加的生命值
  -- @param args.hungervalue 食用后增加的饥饿值
  -- @param args.sanityvalue 食用后增加的精神值
  -- @param args.secondaryfoodtype 食物类型
  -- @param args.sanityvalue 食用后增加的精神值
  -- @param args.temperaturedelta 食用后增加的温度
  -- @param args.temperatureduration 食用后增加的温度持续时间
  -- @param args.nochill 食用后是否不会降低温度
  -- @param args.spice 食用后增加的香料
  -- @param args.oneatenfn 食用后的回调函数
  componentEdible = componentEdible,
  -- 可燃烧物品组件
  -- @param inst
  -- @param args.time 燃烧时间
  -- @param args.offset 燃烧偏移
  -- @param args.structure 燃烧结构
  -- @param args.sym 燃烧符号
  MakeMediumBurnable = MakeMediumBurnable,
  MakeSmallBurnable = MakeSmallBurnable,
  MakeLargeBurnable = MakeLargeBurnable,

  -- 燃料组件
  -- @param inst
  -- @param args.fuelvalue 燃料值
  -- @param args.fueltype 燃料类型
  -- @param args.ontakefn 燃烧回调函数
  ComponentFuel = ComponentFuel,

  -- 爆炸组件
  -- @param inst
  -- @param args
  ComponentExplosive = ComponentExplosive,

  -- 作为燃料添加后爆炸
  -- @param inst
  -- @param args
  componentFuelExplosive = componentFuelExplosive,

  -- 保鲜组件
  -- @param inst
  -- @param args.percent_increase 保鲜百分比
  componentPreservative = componentPreservative

}

local function addItemTemplate(item)
  if not item.template then return end
  for k, args in pairs(item.template) do
    if type(template[k]) == 'function' then
      AddPrefabPostInit(item.prefab, function(inst)
        template[k](inst, args)
      end)
    end
  end
end

for i = 1, #arkItemDeclare do
  local item = arkItemDeclare[i]
  local assetsCode = common.getPrefabAssetsCode(item.prefab)
  RegisterInventoryItemAtlas(assetsCode.atlas, assetsCode.image)
  addItemRecipe(item)
  if TUNING.ARK_CONFIG.enable_all_materials_drop then
    addItemDrop(item)
  end
  addItemTemplate(item)
  if item.ingredientValues then
    -- cancook 默认为true
    local cancook = true
    if item.ingredientValues.cancook ~= nil then
      cancook = item.ingredientValues.cancook
    end
    -- candry 默认为false
    local candry = false
    if item.ingredientValues.candry ~= nil then
      candry = item.ingredientValues.candry
    end
    AddIngredientValues({item.prefab}, item.ingredientValues.tags, cancook, candry)
  end
end

AddComponentPostInit("lootdropper", function(self)
    function self:AddLoot(prefab, num)
        num = math.max(1, num or 1)

        if self.loot == nil then
            self.loot = {}
            self._loot_unshared = true
        elseif not self._loot_unshared then
            -- Break shared loot table reference (e.g. tallbird's local loot upvalue)
            self.loot = shallowcopy(self.loot)
            self._loot_unshared = true
        end

        for i = 1, num do
            table.insert(self.loot, prefab)
        end
    end
end)

for k, v in pairs(dropMap) do
  AddPrefabPostInit(k, function(inst)
      for i = 1, #v do
        local adapter = inst.components.lootdropper and inst.components.lootdropper[v[i].adapter]
        if adapter then
          adapter(inst.components.lootdropper, v[i].prefab, v[i].value)
        end
      end
  end)
end
