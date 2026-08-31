-- 地图选择器运行实体：服务端保存确认回调，客户端收到 selector id 后打开原版地图。

local function ClearLocalOwner(inst)
  local player = ThePlayer
  if player ~= nil and player._now_target_selector == inst then
    player._now_target_selector = nil
    player._now_target_selector_obj = nil
  end
end

local function OpenMapForLocalPlayer(inst)
  if inst._map_opened then
    return
  end
  local player = ThePlayer
  if player == nil or inst.entity:GetParent() ~= player or player.components.playercontroller == nil then
    return
  end
  local id = inst._selector_id:value()
  local selector = id ~= "" and GetTargetSelector(id) or nil
  if selector == nil then
    return
  end

  inst._map_opened = true
  player._now_target_selector = inst
  player._now_target_selector_obj = selector

  if player.HUD ~= nil and player.HUD:IsMapScreenOpen() then
    local mapscreen = TheFrontEnd:GetActiveScreen()
    if mapscreen ~= nil and mapscreen.SetNewMapTarget ~= nil then
      mapscreen:SetNewMapTarget(inst, ACTIONS.ARK_TARGET_SELECT_MAP)
    end
  else
    player.components.playercontroller:PullUpMap(inst, ACTIONS.ARK_TARGET_SELECT_MAP)
  end
end

local function ScheduleOpenMap(inst)
  inst:DoTaskInTime(0, OpenMapForLocalPlayer)
end

local function OnCancelMapTarget(inst, doer)
  if inst._confirmed:value() then
    return
  end
  if TheWorld.ismastersim then
    if inst.CancelSelection ~= nil then
      inst:CancelSelection(doer)
    end
  elseif doer == ThePlayer then
    SendModRPCToServer(GetModRPC("arkTargetSelector", "Cancel"), inst.GUID)
  end
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddNetwork()

  inst:AddTag("CLASSIFIED")
  inst:AddTag("NOCLICK")
  inst.entity:SetCanSleep(false)

  inst._selector_id = net_string(inst.GUID, "map_target_selector._id", "selector_id_dirty")
  inst._confirmed = net_bool(inst.GUID, "map_target_selector._confirmed", "confirmed_dirty")

  inst.OpenMapForLocalPlayer = OpenMapForLocalPlayer
  inst:ListenForEvent("cancelmaptarget", OnCancelMapTarget)
  inst:ListenForEvent("onremove", ClearLocalOwner)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    inst:ListenForEvent("selector_id_dirty", ScheduleOpenMap)
    inst.OnEntityReplicated = ScheduleOpenMap
    return inst
  end

  inst.persists = false
  return inst
end

return Prefab("map_target_selector", fn)
