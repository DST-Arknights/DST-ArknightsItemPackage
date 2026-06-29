local emotions = { "sad", "angry", "confused", "happy", "normal" }

for _, emotion in ipairs(emotions) do
  RegisterInventoryItemAtlas("images/inventoryimages/sympathetic_pendants.xml", emotion .. ".tex")
end

local MAX_EMPATHY = 100
local LIGHT_HEIGHT = 1.1
local LIGHT_REFRESH_INTERVAL = 10 * FRAMES
local LIGHT_TRANSITION_INTERVAL = 2 * FRAMES
local LIGHT_TRANSITION_ALPHA = 0.28
local BASE_LIGHT_RADIUS = 2
local BASE_LIGHT_INTENSITY = 0.65
local BASE_LIGHT_FALLOFF = 0.7
local LIGHT_MAX_MULT = 4
local BASE_BLOOM_SYMBOL_LIGHTOVERRIDE = 0.46
local BONUS_BLOOM_SYMBOL_LIGHTOVERRIDE = 0.46
local BASE_BLOOM_ADDCOLOUR = 0.22
local BONUS_BLOOM_ADDCOLOUR = 0.35
local MAX_RESONANCE_PARTNERS = 3

local prefabs = {
  "sympathetic_pendant_light",
}

local LIGHT_SETTINGS_BY_EMOTION = {
  sad = {
    colour = { 0.15, 0.35, 1.0 },
  },
  angry = {
    colour = { 1.0, 0.12, 0.08 },
  },
  confused = {
    colour = { 0.1, 1.0, 0.2 },
  },
  happy = {
    colour = { 1.0, 0.85, 0.0 },
  },
  normal = {
    colour = { 0.85, 0.85, 0.75 },
  },
}

local assets =
{
  Asset("ANIM", "anim/sympathetic_pendants.zip"),
  Asset("ANIM", "anim/torso_sympathetic_pendants.zip"),
}

local ForEachNearbyPlayer

local function Clamp01(value)
  return math.max(0, math.min(1, value or 0))
end

local function Lerp(a, b, t)
  return a + (b - a) * t
end

local function GetEmotionLightSettings(emotion)
  return LIGHT_SETTINGS_BY_EMOTION[emotion] or LIGHT_SETTINGS_BY_EMOTION.normal
end

local function HasEquippedPendant(player)
  return player ~= nil
    and player.components ~= nil
    and player.components.sympathetic_pendant ~= nil
    and player.components.sympathetic_pendant:HasEquippedItem()
end

local function CopyLightState(state)
  local colour = state ~= nil and state.colour or nil
  return {
    radius = state ~= nil and state.radius or 0,
    intensity = state ~= nil and state.intensity or 0,
    falloff = state ~= nil and state.falloff or BASE_LIGHT_FALLOFF,
    colour = {
      colour ~= nil and colour[1] or 1,
      colour ~= nil and colour[2] or 1,
      colour ~= nil and colour[3] or 1,
    },
  }
end

local function MakeDefaultVisibleLightState()
  return {
    radius = BASE_LIGHT_RADIUS,
    intensity = BASE_LIGHT_INTENSITY,
    falloff = BASE_LIGHT_FALLOFF,
    colour = { 223 / 255, 208 / 255, 69 / 255 },
  }
end

local function ApplyLightState(inst, state)
  inst.Light:SetRadius(state.radius)
  inst.Light:SetIntensity(state.intensity)
  inst.Light:SetFalloff(state.falloff)
  inst.Light:SetColour(state.colour[1], state.colour[2], state.colour[3])
  inst.Light:Enable(state.intensity > 0.01 or state.radius > 0.01)
end

local function IsLightStateClose(current, target)
  return math.abs((current.radius or 0) - (target.radius or 0)) <= 0.02
    and math.abs((current.intensity or 0) - (target.intensity or 0)) <= 0.02
    and math.abs((current.falloff or 0) - (target.falloff or 0)) <= 0.02
    and math.abs((current.colour[1] or 0) - (target.colour[1] or 0)) <= 0.02
    and math.abs((current.colour[2] or 0) - (target.colour[2] or 0)) <= 0.02
    and math.abs((current.colour[3] or 0) - (target.colour[3] or 0)) <= 0.02
end

local function StopLightTransition(inst)
  if inst._transition_task ~= nil then
    inst._transition_task:Cancel()
    inst._transition_task = nil
  end
end

local function UpdateLightTransition(inst)
  if inst._current_light == nil or inst._target_light == nil then
    StopLightTransition(inst)
    return
  end

  local current = inst._current_light
  local target = inst._target_light
  current.radius = Lerp(current.radius, target.radius, LIGHT_TRANSITION_ALPHA)
  current.intensity = Lerp(current.intensity, target.intensity, LIGHT_TRANSITION_ALPHA)
  current.falloff = Lerp(current.falloff, target.falloff, LIGHT_TRANSITION_ALPHA)
  current.colour[1] = Lerp(current.colour[1], target.colour[1], LIGHT_TRANSITION_ALPHA)
  current.colour[2] = Lerp(current.colour[2], target.colour[2], LIGHT_TRANSITION_ALPHA)
  current.colour[3] = Lerp(current.colour[3], target.colour[3], LIGHT_TRANSITION_ALPHA)

  if IsLightStateClose(current, target) then
    inst._current_light = CopyLightState(target)
    current = inst._current_light
    StopLightTransition(inst)
  end

  ApplyLightState(inst, current)
end

local function SetLightTarget(inst, state)
  inst._target_light = CopyLightState(state)

  if inst._light_initialized ~= true or inst._current_light == nil then
    inst._current_light = CopyLightState(inst._target_light)
    ApplyLightState(inst, inst._current_light)
    StopLightTransition(inst)
    inst._light_initialized = true
    return
  end

  if IsLightStateClose(inst._current_light, inst._target_light) then
    inst._current_light = CopyLightState(inst._target_light)
    ApplyLightState(inst, inst._current_light)
    StopLightTransition(inst)
    return
  end

  if inst._transition_task == nil then
    inst._transition_task = inst:DoPeriodicTask(LIGHT_TRANSITION_INTERVAL, UpdateLightTransition)
  end
  UpdateLightTransition(inst)
end

local function CopyBloomState(state)
  local addcolour = state ~= nil and state.addcolour or nil
  return {
    enabled = state ~= nil and state.enabled or false,
    symbol_lightoverride = state ~= nil and state.symbol_lightoverride or 0,
    addcolour = {
      addcolour ~= nil and addcolour[1] or 0,
      addcolour ~= nil and addcolour[2] or 0,
      addcolour ~= nil and addcolour[3] or 0,
      addcolour ~= nil and addcolour[4] or 0,
    },
  }
end

local function IsBloomStateClose(current, target)
  return current.enabled == target.enabled
    and math.abs((current.symbol_lightoverride or 0) - (target.symbol_lightoverride or 0)) <= 0.02
    and math.abs((current.addcolour[1] or 0) - (target.addcolour[1] or 0)) <= 0.02
    and math.abs((current.addcolour[2] or 0) - (target.addcolour[2] or 0)) <= 0.02
    and math.abs((current.addcolour[3] or 0) - (target.addcolour[3] or 0)) <= 0.02
    and math.abs((current.addcolour[4] or 0) - (target.addcolour[4] or 0)) <= 0.02
end

local function ClearOwnerPendantBloom(owner)
  if owner == nil or not owner:IsValid() then
    return
  end

  owner.AnimState:ClearSymbolBloom("swap_body")
  owner.AnimState:SetSymbolLightOverride("swap_body", 0)
  owner.AnimState:SetSymbolAddColour("swap_body", 0, 0, 0, 0)
end

local function ApplyBloomState(inst, owner, state)
  local previous_owner = inst._bloom_owner
  if previous_owner ~= nil and previous_owner ~= owner then
    ClearOwnerPendantBloom(previous_owner)
  end

  if not state.enabled then
    ClearOwnerPendantBloom(owner)
    inst._bloom_owner = nil
    return
  end

  if owner ~= nil and owner:IsValid() then
    owner.AnimState:SetSymbolBloom("swap_body")
    owner.AnimState:SetSymbolLightOverride("swap_body", state.symbol_lightoverride)
    owner.AnimState:SetSymbolAddColour("swap_body", state.addcolour[1], state.addcolour[2], state.addcolour[3], state.addcolour[4])
    inst._bloom_owner = owner
  else
    inst._bloom_owner = nil
  end
end

local function StopBloomTransition(inst)
  if inst._bloom_transition_task ~= nil then
    inst._bloom_transition_task:Cancel()
    inst._bloom_transition_task = nil
  end
end

local function UpdateBloomTransition(inst)
  if inst._current_bloom == nil or inst._target_bloom == nil then
    StopBloomTransition(inst)
    return
  end

  local current = inst._current_bloom
  local target = inst._target_bloom
  current.enabled = target.enabled
  current.symbol_lightoverride = Lerp(current.symbol_lightoverride, target.symbol_lightoverride, LIGHT_TRANSITION_ALPHA)
  current.addcolour[1] = Lerp(current.addcolour[1], target.addcolour[1], LIGHT_TRANSITION_ALPHA)
  current.addcolour[2] = Lerp(current.addcolour[2], target.addcolour[2], LIGHT_TRANSITION_ALPHA)
  current.addcolour[3] = Lerp(current.addcolour[3], target.addcolour[3], LIGHT_TRANSITION_ALPHA)
  current.addcolour[4] = Lerp(current.addcolour[4], target.addcolour[4], LIGHT_TRANSITION_ALPHA)

  if IsBloomStateClose(current, target) then
    inst._current_bloom = CopyBloomState(target)
    current = inst._current_bloom
    StopBloomTransition(inst)
  end

  ApplyBloomState(inst, inst._target_bloom_owner, current)
end

local function SetBloomTarget(inst, owner, state)
  inst._target_bloom_owner = owner
  inst._target_bloom = CopyBloomState(state)

  if inst._bloom_initialized ~= true or inst._current_bloom == nil then
    inst._current_bloom = CopyBloomState(inst._target_bloom)
    ApplyBloomState(inst, owner, inst._current_bloom)
    StopBloomTransition(inst)
    inst._bloom_initialized = true
    return
  end

  if IsBloomStateClose(inst._current_bloom, inst._target_bloom) then
    inst._current_bloom = CopyBloomState(inst._target_bloom)
    ApplyBloomState(inst, owner, inst._current_bloom)
    StopBloomTransition(inst)
    return
  end

  if inst._bloom_transition_task == nil then
    inst._bloom_transition_task = inst:DoPeriodicTask(LIGHT_TRANSITION_INTERVAL, UpdateBloomTransition)
  end
  UpdateBloomTransition(inst)
end

local function ClearPendantBloom(inst, owner)
  StopBloomTransition(inst)
  ClearOwnerPendantBloom(owner or inst._bloom_owner)
  inst._bloom_owner = nil
  inst._current_bloom = nil
  inst._target_bloom = nil
  inst._target_bloom_owner = nil
  inst._bloom_initialized = nil
end

local function GetEquippedOwner(inst)
  if inst.components.equippable:IsEquipped() then
    return inst.components.inventoryitem.owner
  end
end

local function RefreshPlayerPendantLights(player)
  if player == nil or player.components == nil or player.components.sympathetic_pendant == nil then
    return
  end

  player.components.sympathetic_pendant:ForEachEquippedItem(function(item)
    if item.RefreshResonanceLight ~= nil then
      item:RefreshResonanceLight()
    end
  end)
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

local function GetResonanceTier(empathy)
  if empathy >= 75 then
    return 1.0
  elseif empathy >= 50 then
    return 0.75
  elseif empathy >= 25 then
    return 0.5
  else
    return 0.25
  end
end

local function PlayersTick(player1, player2)
  -- 只有双方都佩戴时才累计共振值
  if not HasEquippedPendant(player1) or not HasEquippedPendant(player2) then
    return
  end

  local data = GetPlayersDataOrDefault(player1, player2)
  if data.empathy < MAX_EMPATHY then
    data.empathy = data.empathy + 1
    SavePlayersData(player1, player2, data)
    -- 通知双方刷新各自的亮度
    RefreshPlayerPendantLights(player1)
    RefreshPlayerPendantLights(player2)
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

local function CalculateResonanceBonus(inst, owner, emotion)
  local totalContribution = 0
  local partnerCount = 0

  -- 只计算佩戴了首饰的同伴，最多3个
  ForEachNearbyPlayer(inst, function(player)
    if partnerCount >= MAX_RESONANCE_PARTNERS then
      return
    end

    -- 只有对方也佩戴了首饰才计算共振
    if not HasEquippedPendant(player) then
      return
    end

    partnerCount = partnerCount + 1
    local data = GetPlayersDataOrDefault(owner, player)
    local tierBonus = GetResonanceTier(data.empathy or 0)
    totalContribution = totalContribution + tierBonus
  end)

  -- 归一化到 0-1 范围：3个伙伴满档时达到 1.0
  local bonus = Clamp01(totalContribution / MAX_RESONANCE_PARTNERS)
  return bonus, partnerCount
end

local function BuildLightTargetState(emotion, bonus)
  local settings = GetEmotionLightSettings(emotion)
  local lightMult = 1 + (LIGHT_MAX_MULT - 1) * Clamp01(bonus)

  return {
    radius = BASE_LIGHT_RADIUS * lightMult,
    intensity = BASE_LIGHT_INTENSITY * lightMult,
    falloff = BASE_LIGHT_FALLOFF,
    colour = settings.colour,
  }
end

local function BuildBloomTargetState(emotion, bonus)
  local settings = GetEmotionLightSettings(emotion)
  local bloomMult = 1 + Clamp01(bonus)
  local addStrength = math.min(1,
    (BASE_BLOOM_ADDCOLOUR + BONUS_BLOOM_ADDCOLOUR * bonus) * bloomMult)
  local symbolLightOverride = Clamp01(
    (BASE_BLOOM_SYMBOL_LIGHTOVERRIDE + BONUS_BLOOM_SYMBOL_LIGHTOVERRIDE * bonus) * bloomMult)

  return {
    enabled = true,
    symbol_lightoverride = symbolLightOverride,
    addcolour = {
      settings.colour[1] * addStrength,
      settings.colour[2] * addStrength,
      settings.colour[3] * addStrength,
      1,
    },
  }
end

local function AttachLightToOwner(light, owner)
  if light == nil or owner == nil then
    return
  end

  light.entity:SetParent(owner.entity)
  light.Transform:SetPosition(0, LIGHT_HEIGHT, 0)
end

local function RemovePendantLight(inst)
  if inst._resonance_light ~= nil then
    if inst._resonance_light:IsValid() then
      inst._resonance_light:Remove()
    end
    inst._resonance_light = nil
  end
end

local function EnsurePendantLight(inst, owner, emotion)
  if owner == nil or not owner:IsValid() then
    return nil
  end

  local spawned = false
  if inst._resonance_light == nil or not inst._resonance_light:IsValid() then
    inst._resonance_light = SpawnPrefab("sympathetic_pendant_light")
    spawned = inst._resonance_light ~= nil
  end

  if inst._resonance_light ~= nil then
    AttachLightToOwner(inst._resonance_light, owner)
    if spawned or inst._resonance_light._light_initialized ~= true then
      inst._resonance_light:SetTargetLight(BuildLightTargetState(emotion or GetPlayerEmotion(owner), 0))
    end
  end

  return inst._resonance_light
end

local function UpdateResonanceLight(inst)
  local owner = GetEquippedOwner(inst)
  if owner == nil or not owner:IsValid() then
    RemovePendantLight(inst)
    ClearPendantBloom(inst, owner)
    return
  end

  local emotion = GetPlayerEmotion(owner)
  local light = EnsurePendantLight(inst, owner, emotion)
  if light == nil or light.SetTargetLight == nil then
    return
  end

  local bonus, partnerCount = CalculateResonanceBonus(inst, owner, emotion)
  inst._resonance_bonus = bonus
  inst._resonance_partner_count = partnerCount
  light:SetTargetLight(BuildLightTargetState(emotion, bonus))
  SetBloomTarget(inst, owner, BuildBloomTargetState(emotion, bonus))
end

local function StartResonanceLightTask(inst)
  if inst._resonance_light_task ~= nil then
    return
  end

  inst._resonance_light_task = inst:DoPeriodicTask(LIGHT_REFRESH_INTERVAL, function()
    inst:RefreshResonanceLight()
  end)
end

local function StopResonanceLightTask(inst)
  if inst._resonance_light_task ~= nil then
    inst._resonance_light_task:Cancel()
    inst._resonance_light_task = nil
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

ForEachNearbyPlayer = function(inst, fn)
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
    inst:RefreshResonanceLight()
    ForEachNearbyPlayer(inst, function(player)
      RefreshPlayerPendantLights(player)
    end)
  end
end

local function OnEquip(inst, owner)
  owner.components.sympathetic_pendant:SetEquippedItem(inst)
  owner:ListenForEvent("sympathetic_pendant_state_dirty", inst._on_state_dirty)
  local emotion = GetPlayerEmotion(owner)
  EnsurePendantLight(inst, owner, emotion)
  SetEmotion(inst, emotion)
  inst.components.playerprox:ForceUpdate()
  RefreshStateBuffs(inst, owner, emotion)
  StartResonanceLightTask(inst)
  inst:RefreshResonanceLight()
end

local function OnUnequip(inst, owner)
  if inst._on_state_dirty ~= nil then
    owner:RemoveEventCallback("sympathetic_pendant_state_dirty", inst._on_state_dirty)
  end
  ForEachNearbyPlayer(inst, function(player)
    RefreshPlayerPendantLights(player)
  end)
  StopResonanceLightTask(inst)
  RemovePendantLight(inst)
  ClearPendantBloom(inst, owner)
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

  RefreshPlayerPendantLights(owner)
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
    inst:RefreshResonanceLight()
    RefreshPlayerPendantLights(player)
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

  inst:RefreshResonanceLight()
  RefreshPlayerPendantLights(player)
end


local function GetStatus(inst)
  return "GENERIC"
end

local function lightfn()
  local inst = CreateEntity()
  local defaultLightState = MakeDefaultVisibleLightState()

  inst.entity:AddTransform()
  inst.entity:AddLight()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")

  inst.Light:SetRadius(defaultLightState.radius)
  inst.Light:SetFalloff(defaultLightState.falloff)
  inst.Light:SetIntensity(defaultLightState.intensity)
  inst.Light:SetColour(defaultLightState.colour[1], defaultLightState.colour[2], defaultLightState.colour[3])
  inst.Light:EnableClientModulation(true)

  ApplyLightState(inst, defaultLightState)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst.persists = false
  inst.entity:SetCanSleep(false)
  inst._current_light = CopyLightState(defaultLightState)
  inst._target_light = CopyLightState(inst._current_light)
  inst._light_initialized = false
  inst.SetTargetLight = SetLightTarget
  inst.OnRemoveEntity = StopLightTransition

  return inst
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
  inst.RefreshResonanceLight = UpdateResonanceLight
  inst.OnRemoveEntity = function(inst)
    StopResonanceLightTask(inst)
    RemovePendantLight(inst)
    ClearPendantBloom(inst, inst._bloom_owner)
  end
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
  inst.components.equippable.walkspeedmult = 1.02

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
return Prefab("sympathetic_pendant", fn, assets, prefabs),
  Prefab("sympathetic_pendant_light", lightfn)
