local assets = {Asset("ANIM", 'anim/ark_gold.zip'), Asset("ATLAS", 'images/ark_item/ark_gold.xml')}

local prefabs = {}
local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  inst.entity:AddNetwork()

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank('ark_gold')
  inst.AnimState:SetBuild('ark_gold')
  inst.AnimState:PlayAnimation('ark_gold')
  inst:AddTag("ark_item")
  inst:AddTag("ark_gold")

  MakeInventoryFloatable(inst)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")
  inst:AddComponent("stackable")
  inst.components.stackable.maxsize = TUNING.STACK_SIZE_TINYITEM

  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem.atlasname = 'images/ark_item/ark_gold.xml'
  inst.components.inventoryitem.imagename = 'ark_gold'

  inst.components.floater:SetScale(1.0)
  inst.components.floater:SetVerticalOffset(0.1)

  MakeHauntableLaunchAndSmash(inst)
  return inst
end

return Prefab('ark_gold', fn, assets, prefabs)
