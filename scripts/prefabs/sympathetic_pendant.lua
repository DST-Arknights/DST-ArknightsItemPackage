local emotions = { "sad", "angry", "confused", "happy", "normal" }

for _, emotion in ipairs(emotions) do
  RegisterInventoryItemAtlas("images/inventoryimages/sympathetic_pendants.xml", emotion .. ".tex")
end

local MAX_EMPATHY = 100

local assets =
{
  Asset("ANIM", "anim/sympathetic_pendants.zip"),
  Asset("ANIM", "anim/torso_sympathetic_pendants.zip"),
}

local function GetEquippedOwner(inst)
  if inst.components.equippable:IsEquipped() then
    return inst.components.inventoryitem.owner
  end
end

local function SavePlayersData(player1, player2, data)
  if not player1.components.sympathetic_pendant or not player2.components.sympathetic_pendant then
    return
  end
  player1.components.sympathetic_pendant:SetPlayerData(player2, data)
  player2.components.sympathetic_pendant:SetPlayerData(player1, data)
end

local function GetPlayersData(player1, player2)
  if not player1.components.sympathetic_pendant or not player2.components.sympathetic_pendant then
    return nil
  end
  return player1.components.sympathetic_pendant:GetPlayerData(player2)
end

local function GetPlayersDataOrDefault(player1, player2)
  local data = GetPlayersData(player1, player2)
  if data == nil then
    data = { empathy = 0 }
  end
  return data
end

local function PlayersTick(player1, player2)
  local data = GetPlayersDataOrDefault(player1, player2)
  if data.empathy < MAX_EMPATHY then
    data.empathy = data.empathy + 1
    SavePlayersData(player1, player2, data)
  end
end

local function GetPlayerEmotion(player)
  if player ~= nil and player.components ~= nil and player.components.sympathetic_pendant ~= nil then
    return player.components.sympathetic_pendant:GetState() or "happy"
  end
  return "normal"
end

local function SetEmotion(inst, emotion)
  inst.components.inventoryitem:ChangeImageName(emotion)
  local owner = GetEquippedOwner(inst)
  if owner ~= nil then
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
      owner:PushEvent("equipskinneditem", inst:GetSkinName())
      owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID,
        "torso_sympathetic_pendants")
    else
      owner.AnimState:OverrideSymbol("swap_body", "torso_sympathetic_pendants", emotion)
    end
  end
end

local function GetOwnerBuffName(emotion)
  return "sympathetic_pendant_" .. emotion .. "_owner_buff"
end

local function GetSharedBuffPrefab(emotion)
  return "sympathetic_pendant_" .. emotion .. "_shared_buff"
end

local function GetSharedBuffName(inst, emotion)
  return GetSharedBuffPrefab(emotion) .. inst.GUID
end

local function RemoveOwnerBuffs(owner)
  for _, emotion in ipairs(emotions) do
    owner:RemoveDebuff(GetOwnerBuffName(emotion))
  end
end

local function RemoveSharedBuffsFromPlayer(inst, player)
  for _, emotion in ipairs(emotions) do
    player:RemoveDebuff(GetSharedBuffName(inst, emotion))
  end
end

local function ApplyOwnerBuff(owner, emotion)
  RemoveOwnerBuffs(owner)
  owner:AddDebuff(GetOwnerBuffName(emotion), GetOwnerBuffName(emotion))
end

local function ApplySharedBuffToPlayer(inst, player, emotion)
  if player == nil or not player:IsValid() then
    return
  end
  RemoveSharedBuffsFromPlayer(inst, player)
  player:AddDebuff(GetSharedBuffName(inst, emotion), GetSharedBuffPrefab(emotion))
end

local function ForEachNearbyPlayer(inst, fn)
  local owner = GetEquippedOwner(inst)
  if owner == nil then
    return
  end

  local visited = {}
  for player in pairs(inst.components.playerprox.closeplayers) do
    if player ~= owner and player:IsValid() and not visited[player] then
      visited[player] = true
      fn(player)
    end
  end

  for player in pairs(inst.player_tasks) do
    if player ~= owner and player:IsValid() and not visited[player] then
      visited[player] = true
      fn(player)
    end
  end
end

local function RefreshStateBuffs(inst, owner, emotion)
  ApplyOwnerBuff(owner, emotion)
  ForEachNearbyPlayer(inst, function(player)
    ApplySharedBuffToPlayer(inst, player, emotion)
  end)
end

local function ClearStateBuffs(inst, owner)
  RemoveOwnerBuffs(owner)
  ForEachNearbyPlayer(inst, function(player)
    RemoveSharedBuffsFromPlayer(inst, player)
  end)
end

local function OnOwnerStateDirty(inst, owner, data)
  if data ~= nil and data.state ~= nil then
    SetEmotion(inst, data.state)
    RefreshStateBuffs(inst, owner, data.state)
  end
end

local function OnEquip(inst, owner)
  owner.components.sympathetic_pendant:SetEquippedItem(inst)
  owner:ListenForEvent("sympathetic_pendant_state_dirty", inst._on_state_dirty)
  inst.components.playerprox:ForceUpdate()
  local emotion = GetPlayerEmotion(owner)
  SetEmotion(inst, emotion)
  RefreshStateBuffs(inst, owner, emotion)
end

local function OnUnequip(inst, owner)
  if inst._on_state_dirty ~= nil then
    owner:RemoveEventCallback("sympathetic_pendant_state_dirty", inst._on_state_dirty)
  end
  ClearStateBuffs(inst, owner)
  owner.components.sympathetic_pendant:RemoveEquippedItem(inst)
  owner.AnimState:ClearOverrideSymbol("swap_body")
  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("unequipskinneditem", inst:GetSkinName())
  end
  SetEmotion(inst, "normal")
  if inst._buff_task ~= nil then
    inst._buff_task:Cancel()
    inst._buff_task = nil
  end
  for player, task in pairs(inst.player_tasks) do
    if task ~= nil then
      task:Cancel()
    end
    inst.player_tasks[player] = nil
  end
end

local function OnEquipToModel(inst, owner)
  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("equipskinneditem", inst:GetSkinName())
    owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID,
      "torso_sympathetic_pendants")
  else
    owner.AnimState:OverrideSymbol("swap_body", "torso_sympathetic_pendants", "normal")
  end
end

local function OnPlayerNear(inst, player)
  -- 共感效果追加
  local owner = GetEquippedOwner(inst)
  if owner and player ~= owner then
    owner.components.sympathetic_pendant:OnNearbyPlayersChanged()
    ApplySharedBuffToPlayer(inst, player, GetPlayerEmotion(owner))
    if inst.GUID < player.GUID then
      inst.player_tasks[player] = inst:DoPeriodicTask(1, function()
        PlayersTick(owner, player)
      end)
    end
  end
end

local function OnPlayerFar(inst, player)
  local owner = GetEquippedOwner(inst)
  if owner ~= nil then
    owner.components.sympathetic_pendant:OnNearbyPlayersChanged()
  end
  RemoveSharedBuffsFromPlayer(inst, player)
  if inst.player_tasks[player] then
    inst.player_tasks[player]:Cancel()
    inst.player_tasks[player] = nil
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
  inst.player_tasks = {}
  inst._on_state_dirty = function(owner, data)
    OnOwnerStateDirty(inst, owner, data)
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
  inst.components.equippable.walkspeedmult = 1.2

  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem.atlasname = "images/inventoryimages/sympathetic_pendants.xml"
  -- inst.components.inventoryitem:SetOnDroppedFn(TurnOff)
  SetEmotion(inst, "normal")
  inst:AddComponent("shadowlevel")
  inst.components.shadowlevel:SetDefaultLevel(TUNING.AMULET_SHADOW_LEVEL)

  inst:AddComponent("playerprox")
  inst.components.playerprox.period = 30 * FRAMES
  inst.components.playerprox:SetDist(20, 25)
  inst.components.playerprox:SetTargetMode(inst.components.playerprox.TargetModes.AllPlayers)
  inst.components.playerprox:SetPlayerAliveMode(inst.components.playerprox.AliveModes.AliveOnly)
  inst.components.playerprox:SetOnPlayerNear(OnPlayerNear)
  inst.components.playerprox:SetOnPlayerFar(OnPlayerFar)


  inst:AddComponent("temperature")

  return inst
end
return Prefab("sympathetic_pendant", fn, assets)
