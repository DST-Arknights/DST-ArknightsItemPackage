local common = require "ark_common"
local arkItemDeclare = common.getAllArkItemDeclare()

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
        eater.AddDebuff(buff)
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

local function ComponentCookable(inst, args)
  if not TheWorld.ismastersim then
    return inst
  end
  args = args or {}
  inst:AddComponent("cookable")
  -- inst.components.cookable.product = args.product or nil
  -- inst.components.cookable:SetOnCookedFn(args.oncookedfn or nil)
  
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

  -- 可烹饪组件
  -- @param inst
  -- @param args.product 烹饪后的物品
  -- @param args.oncookedfn 烹饪后的回调函数
  ComponentCookable = ComponentCookable,

  -- 作为燃料添加后爆炸
  -- @param inst
  -- @param args
  componentFuelExplosive = componentFuelExplosive,

  -- 保鲜组件
  -- @param inst
  -- @param args.percent_increase 保鲜百分比
  componentPreservative = componentPreservative

}

for _, item in ipairs(arkItemDeclare) do
  if item.template then
    for k, args in pairs(item.template) do
      if type(template[k]) == 'function' then
        print('item '.. item.prefab .. ' add template ' .. k)
        AddPrefabPostInit(item.prefab, function(inst)
          template[k](inst, args)
        end)
      end
    end
  end
end
