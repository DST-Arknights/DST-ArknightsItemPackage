local EMOTIONS = { "sad", "angry", "confused", "happy", "normal" }

local assets =
{
  Asset("ANIM", "anim/sympathetic_pendants.zip"),
  Asset("ANIM", "anim/torso_sympathetic_pendants.zip"),
}
local prefabs = { "sympathetic_pendant_light" }

local function GetOwnerBuffPrefab(emotion)
  return "sympathetic_pendant_" .. emotion .. "_owner_buff"
end

local function GetSharedBuffPrefab(emotion)
  return "sympathetic_pendant_" .. emotion .. "_shared_buff"
end

for _, emotion in ipairs(EMOTIONS) do
  table.insert(prefabs, GetOwnerBuffPrefab(emotion))
  table.insert(prefabs, GetSharedBuffPrefab(emotion))
end

local function SetEmotion(inst, owner, emotion)
  inst.components.inventoryitem:ChangeImageName(emotion)
  if owner then
    local skin_build = inst:GetSkinBuild()
    if skin_build then
      owner:PushEvent("equipskinneditem", inst:GetSkinName())
      owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID,
        "torso_sympathetic_pendants")
    else
      owner.AnimState:OverrideSymbol("swap_body", "torso_sympathetic_pendants", emotion)
    end
    owner.AnimState:SetSymbolBloom("swap_body")
    owner.AnimState:SetSymbolLightOverride("swap_body", 1)
    owner.AnimState:SetSymbolAddColour("swap_body", 0.05, 0.05, 0.05, 0.5)
  end
end

local function OnEquip(inst, owner)
  inst:SetEmotion(owner, "normal")
  if owner.components.sympathetic_pendant then
    owner.components.sympathetic_pendant:EquipPendant(inst)
  end
end

local function OnUnequip(inst, owner)
  inst:SetEmotion(owner, "normal")
  if owner.components.sympathetic_pendant then
    owner.components.sympathetic_pendant:UnequipPendant(inst)
  end
  owner.AnimState:ClearOverrideSymbol("swap_body")
  local skin_build = inst:GetSkinBuild()
  if skin_build then
    owner:PushEvent("unequipskinneditem", inst:GetSkinName())
  end
  owner.AnimState:ClearSymbolBloom("swap_body")
  owner.AnimState:SetSymbolLightOverride("swap_body", 0)
  owner.AnimState:SetSymbolAddColour("swap_body", 0, 0, 0, 1)
end

local function OnEquipToModel(inst, owner)
  inst:SetEmotion(owner, "normal")
  if owner.components.sympathetic_pendant then
    owner.components.sympathetic_pendant:UnequipPendant(inst)
  end
end

local function GetStatus(inst)
  local owner = inst.components.inventoryitem.owner
  if owner and owner.components.sympathetic_pendant then
    local emotion = owner.components.sympathetic_pendant:GetEmotion()
    if emotion == 'normal' then
      return "GENERIC"
    else
      return string.upper(emotion)
    end
  end
  return "GENERIC"
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()
  inst.entity:AddSoundEmitter()

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("sympathetic_pendants")
  inst.AnimState:SetBuild("sympathetic_pendants")
  inst.AnimState:PlayAnimation("idle")
  inst.scrapbook_anim = "idle"

  inst:AddTag("sympathetic_pendant")

  MakeInventoryFloatable(inst, "med", nil, 0.6)
  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
    return inst
  end
  inst:AddComponent("inspectable")
  inst.components.inspectable.getstatus = GetStatus

  inst:AddComponent("equippable")
  inst.components.equippable.equipslot = EQUIPSLOTS.BODY
  inst.components.equippable.dapperness = TUNING.DAPPERNESS_SMALL
  inst.components.equippable.is_magic_dapperness = true
  inst.components.equippable:SetOnEquip(OnEquip)
  inst.components.equippable:SetOnUnequip(OnUnequip)
  inst.components.equippable:SetOnEquipToModel(OnEquipToModel)
  inst.components.equippable.walkspeedmult = TUNING.SYMPATHETIC_PENDANT.SPEED_MULT

  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem.atlasname = "images/inventoryimages/sympathetic_pendants.xml"
  inst.SetEmotion = SetEmotion
  inst:SetEmotion(nil, "normal")
  inst:AddComponent("shadowlevel")
  inst.components.shadowlevel:SetDefaultLevel(TUNING.AMULET_SHADOW_LEVEL)

  inst:AddComponent("temperature")

  return inst
end

return Prefab("sympathetic_pendant", fn, assets, prefabs)
