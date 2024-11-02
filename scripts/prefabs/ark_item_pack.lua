local assets =
{
    Asset("ANIM", "anim/ark_item_pack.zip"),
    Asset("ATLAS", "images/ark_item/ark_item_pack.xml"),
}



local prefabs =
{
    "ash",
}

local function onburnt(inst)
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
        inst.components.container:Close()
    end
    inst:Remove()
end

local function onignite(inst)
    if inst.components.container ~= nil then
        inst.components.container.canbeopened = false
    end
end

local function onextinguish(inst)
    if inst.components.container ~= nil then
        inst.components.container.canbeopened = true
    end
end

local function OnPlayerNear(inst)
    inst.AnimState:PushAnimation("open")
    inst.AnimState:PushAnimation("open_idle", true)
end

local function OnPlayerFar(inst)
    inst.AnimState:PushAnimation("close")
    inst.AnimState:PushAnimation("close_idle", true)
end


local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("ark_item_pack")
    inst.AnimState:SetBuild("ark_item_pack")
    inst.AnimState:SetScale(0.75, 0.75)
    inst.AnimState:PlayAnimation("close_idle")

    inst:AddTag("ark_item_pack")

    inst.MiniMapEntity:SetIcon("backpack.png")

    inst.foleysound = "dontstarve/movement/foley/backpack"

    local swap_data = {bank = "backpack1", anim = "anim"}
    MakeInventoryFloatable(inst, "small", 0.2, nil, nil, nil, swap_data)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.canonlygoinpocket = true
    inst.components.inventoryitem.atlasname = 'images/ark_item/ark_item_pack.xml'
    inst.components.inventoryitem.imagename = 'ark_item_pack'

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("ark_item_pack")
    inst.components.container:EnableInfiniteStackSize(true)

    local playerprox = inst:AddComponent("playerprox")
    playerprox:SetTargetMode(playerprox.TargetModes.AnyPlayer)
    playerprox:SetOnPlayerNear(OnPlayerNear)
    playerprox:SetOnPlayerFar(OnPlayerFar)
    playerprox:SetDist(1.7, 1.7)

    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)
    inst.components.burnable:SetOnBurntFn(onburnt)
    inst.components.burnable:SetOnIgniteFn(onignite)
    inst.components.burnable:SetOnExtinguishFn(onextinguish)

    MakeHauntableLaunchAndDropFirstItem(inst)

    return inst
end

return Prefab("ark_item_pack", fn, assets, prefabs)
