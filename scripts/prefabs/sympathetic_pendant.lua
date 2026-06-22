local colors = { "blue", "red", "green", "yellow" }

for _, color in ipairs(colors) do
  RegisterInventoryItemAtlas("images/inventoryimages/sympathetic_pendants.xml", color .. "_pendant.tex")
end
RegisterInventoryItemAtlas("images/inventoryimages/sympathetic_pendants.xml", "gray_pendant.tex")


local assets =
{
  Asset("ANIM", "anim/sympathetic_pendants.zip"),
  Asset("ANIM", "anim/torso_sympathetic_pendants.zip"),
}

local function UpdateColor(inst, color)
  inst._color = color
  inst.components.inventoryitem:ChangeImageName(color .. "_pendant")
  if inst.components.equippable:IsEquipped() then
    local real_color = color == "gray" and "yellow" or color
    local owner = inst.components.inventoryitem.owner
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
      owner:PushEvent("equipskinneditem", inst:GetSkinName())
      owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID,
        "torso_sympathetic_pendants")
    else
      owner.AnimState:OverrideSymbol("swap_body", "torso_sympathetic_pendants", real_color .. "_pendant")
    end
  end
end

local function OnEquip(inst, owner)
  UpdateColor(inst, inst._color)
  inst._new_color = inst:DoPeriodicTask(3, function()
    local new_color = colors[math.random(#colors)]
    while new_color == inst._color do
      new_color = colors[math.random(#colors)]
    end
    UpdateColor(inst, new_color)
  end)
end

local function OnUnequip(inst, owner)
  owner.AnimState:ClearOverrideSymbol("swap_body")
  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("unequipskinneditem", inst:GetSkinName())
  end
  if inst._new_color ~= nil then
    inst._new_color:Cancel()
    inst._new_color = nil
  end
  UpdateColor(inst, "gray")
end

local function OnEquipToModel(inst, owner)
  local real_color = inst._color == "gray" and "green" or inst._color
  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("equipskinneditem", inst:GetSkinName())
    owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID,
      "torso_sympathetic_pendants")
  else
    owner.AnimState:OverrideSymbol("swap_body", "torso_sympathetic_pendants", real_color .. "_pendant")
  end
end


local function GetStatus(inst)
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

  inst._color = "gray"
  inst:AddComponent("inspectable")
  inst.components.inspectable.getstatus = GetStatus

  inst:AddComponent("equippable")
  inst.components.equippable.equipslot = EQUIPSLOTS.BODY
  inst.components.equippable.dapperness = TUNING.DAPPERNESS_SMALL
  inst.components.equippable.is_magic_dapperness = true
  inst.components.equippable:SetOnEquip(OnEquip)
  inst.components.equippable:SetOnUnequip(OnUnequip)
  inst.components.equippable:SetOnEquipToModel(OnEquipToModel)
  inst.components.equippable.walkspeedmult = 1.2

  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem.atlasname = "images/inventoryimages/sympathetic_pendants.xml"
  -- inst.components.inventoryitem:SetOnDroppedFn(TurnOff)
  UpdateColor(inst, inst._color)
  inst:AddComponent("shadowlevel")
  inst.components.shadowlevel:SetDefaultLevel(TUNING.AMULET_SHADOW_LEVEL)
  return inst
end
return Prefab("sympathetic_pendant", fn, assets)
