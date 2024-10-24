local utils = require("ark_utils")
local common = require("ark_common")
local arkItemDeclare = common.getAllArkItemDeclare()

local function makeArkItem(config)
  local assetsCode = common.getPrefabAssetsCode(config.prefab, false)
  local assets = {Asset("ANIM", assetsCode.anim), Asset("ATLAS", assetsCode.atlas)}
  local prefabs = {}
  if config.recipe then
    for i = 1, #config.recipe do
      for j = 1, #config.recipe[i] do
        table.insert(prefabs, config.recipe[i][j].prefab)
      end
    end
  end
  prefabs = utils.uniqueArray(prefabs)
  local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank(assetsCode.animBank)
    inst.AnimState:SetBuild(assetsCode.animBuild)
    inst.AnimState:PlayAnimation(config.prefab)
    inst:AddTag("ark_item")
    inst:AddTag("ark_item_" .. config.prefab)

    MakeInventoryFloatable(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
      return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_TINYITEM

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = assetsCode.image
    inst.components.inventoryitem.atlasname = assetsCode.atlas

    inst.components.floater:SetScale(1.0)
    inst.components.floater:SetVerticalOffset(0.1)

    MakeHauntableLaunchAndSmash(inst)
    return inst
  end

  return Prefab(config.prefab, fn, assets, prefabs)
end

local ret = {}
for k = 1, #arkItemDeclare do
  table.insert(ret, makeArkItem(arkItemDeclare[k]))
end
return unpack(ret)
