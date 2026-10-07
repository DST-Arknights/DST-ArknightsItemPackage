local COLOUR = { 0.55, 0.8, 1, 1 }
local FONT_SIZE = 24
local HEIGHT = 50
local RISE = 30
local PROXY_LIFETIME = 1

local function ShowChargeNumber(inst)
  if inst._shown then
    return
  end

  local amount = inst._amount:value()
  local target = inst._target:value()
  local player = ThePlayer
  if amount <= 0 or target == nil or not target:IsValid()
      or player == nil or player.HUD == nil or player.HUD.popupstats_root == nil then
    return
  end

  local PopupNumber = require "widgets/popupnumber"
  local popup = player.HUD.popupstats_root:AddChild(PopupNumber(
    player, string.format("+%g", amount),
    FONT_SIZE, target:GetPosition(), HEIGHT, COLOUR, false
  ))
  popup.text:SetFont(SEGEOUI_ALPHANUM_ITALICFONT)
  -- Keep the native rise/fade lifetime, but move only vertically.
  popup.xoffs = 0
  popup.yoffs = HEIGHT
  popup.speed = 0
  popup.rise = RISE
  popup.drop = 0
  ArkHookFunction(popup, "OnUpdate", function(next, self, dt)
    if target:IsValid() then
      self.pos = target:GetPosition()
    end
    return next(self, dt)
  end)
  inst._shown = true
end

local function OnChargeDirty(inst)
  if inst._shown or inst._showtask ~= nil then
    return
  end

  -- Read the initial target and amount after network deserialization.
  inst._showtask = inst:DoTaskInTime(0, function()
    inst._showtask = nil
    ShowChargeNumber(inst)
  end)
end

local function SetCharge(inst, target, amount)
  inst.Transform:SetPosition(target.Transform:GetWorldPosition())
  inst._target:set(target)
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
  inst._target = net_entity(inst.GUID, "ark_supply_charge_number.target", "chargedirty")
  inst._amount = net_float(inst.GUID, "ark_supply_charge_number.amount", "chargedirty")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    inst:ListenForEvent("chargedirty", OnChargeDirty)
    -- Also read the initial snapshot; _shown prevents duplicate popups.
    OnChargeDirty(inst)
    return inst
  end

  inst.SetCharge = SetCharge
  inst:DoTaskInTime(PROXY_LIFETIME, inst.Remove)
  return inst
end

return Prefab("ark_supply_charge_number", fn)
