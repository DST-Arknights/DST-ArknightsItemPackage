local ark_items = require("ark_item_prefabs")
local utils = require("ark_utils")
local common = require("ark_common")

local function makeArkItem(config)
    local assets = {Asset("ANIM", "anim/ark_item.zip"), Asset("ATLAS", "images/ark_item/" .. config.prefab .. ".xml")}
    local prefabs = {}
    if config.recipe then
        for i = 1, #config.recipe do
            for j = 1, #config.recipe[i] do
                table.insert(prefabs, common.genArkItemPrefabCode(config.recipe[i][j].prefab))
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

        inst.AnimState:SetBank("ark_item")
        inst.AnimState:SetBuild("ark_item")
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
        inst.components.inventoryitem.imagename = config.prefab
        inst.components.inventoryitem.atlasname = "images/ark_item/" .. config.prefab .. ".xml"

        inst.components.floater:SetScale(1.0)
        inst.components.floater:SetVerticalOffset(0.1)

        MakeHauntableLaunchAndSmash(inst)
        return inst
    end

    return Prefab(common.genArkItemPrefabCode(config.prefab), fn, assets, prefabs)
end

local ret = {}
for k = 1, #ark_items do
    table.insert(ret, makeArkItem(ark_items[k]))
end
return unpack(ret)
