local COLOUR = { 0.55, 0.8, 1, 1 }
local FONT_SIZE = 32
local HEIGHT = 50
local RISE = 30
local PROXY_LIFETIME = 1

local function ShowChargeNumber(inst)
  if inst._shown then
    return
  end

  local amount = inst._amount:value()
  local player = ThePlayer
  if amount <= 0 or player == nil or player.HUD == nil or player.HUD.popupstats_root == nil then
    return
  end

  local PopupNumber = require "widgets/popupnumber"
  local popup = player.HUD.popupstats_root:AddChild(PopupNumber(
    player, string.format("+%g", amount),
    FONT_SIZE, inst:GetPosition(), HEIGHT, COLOUR, false
  ))
  -- Keep the native rise/fade lifetime, but move only vertically.
  popup.xoffs = 0
  popup.yoffs = HEIGHT
  popup.speed = 0
  popup.rise = RISE
  popup.drop = 0
  inst._shown = true
end

local function OnAmountDirty(inst)
  if inst._shown or inst._showtask ~= nil then
    return
  end

  -- Allow the replicated Transform to be positioned before projecting to the HUD.
  inst._showtask = inst:DoTaskInTime(0, function()
    inst._showtask = nil
    ShowChargeNumber(inst)
  end)
end

local function SetCharge(inst, target, amount)
  inst.Transform:SetPosition(target.Transform:GetWorldPosition())
  inst._amount:set(amount)
  -- Remote clients use dirty; the listen-server player displays locally here.
  if not TheNet:IsDedicated() then
    ShowChargeNumber(inst)
  end
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  inst.persists = false
  inst._amount = net_float(inst.GUID, "ark_supply_charge_number.amount", "amountdirty")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    inst:ListenForEvent("amountdirty", OnAmountDirty)
    -- Also read the initial snapshot; _shown prevents duplicate popups.
    OnAmountDirty(inst)
    return inst
  end

  inst.SetCharge = SetCharge
  inst:DoTaskInTime(PROXY_LIFETIME, inst.Remove)
  return inst
end

return Prefab("ark_supply_charge_number", fn)
