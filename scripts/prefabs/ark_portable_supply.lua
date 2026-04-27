require "prefabutil"

local assets =
{
  Asset("ANIM", "anim/ark_portable_supply.zip"),
  Asset("ATLAS", "images/inventoryimages/ark_portable_supply.xml"),
}

local MAX_FUEL = TUNING.TOTAL_DAY_TIME
local DEFAULT_SCAN_RANGE = 16
local DEFAULT_SCAN_INTERVAL = 1
local DEFAULT_CHARGE_AMOUNT = 5

RegisterInventoryItemAtlas("images/inventoryimages/ark_portable_supply.xml", "ark_portable_supply.tex")

local function ClampNonNegative(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  return value
end

local function GetFuelPercent(inst)
  local fueled = inst.components.fueled
  if fueled == nil or fueled.GetPercent == nil then
    return 0
  end
  return math.max(0, math.min(1, fueled:GetPercent()))
end

local function GetFuelAmount(inst)
  local fueled = inst.components.fueled
  if fueled == nil then
    return 0
  end
  return math.max(0, fueled.currentfuel or 0)
end

local function GetIdleAnimation(inst)
  local percent = GetFuelPercent(inst)
  if percent <= 0 then
    return "idle_0"
  elseif percent <= (1 / 3) then
    return "idle_1"
  elseif percent <= (2 / 3) then
    return "idle_2"
  end
  return "idle_3"
end

local function PlayIdleAnimation(inst)
  inst.AnimState:PlayAnimation(GetIdleAnimation(inst), true)
end

local function OnFuelDirty(inst)
  if inst._restoreidle then
    return
  end
  PlayIdleAnimation(inst)
end

local function OnAnimOver(inst)
  if inst._restoreidle then
    inst._restoreidle = nil
    PlayIdleAnimation(inst)
  end
end

local function ConfigureFuel(inst)
  inst:AddComponent("fueled")
  inst.components.fueled:InitializeFuelLevel(MAX_FUEL)
  inst.components.fueled.accepting = true
  inst.components.fueled.bonusmult = 5
  inst.components.fueled.secondaryfueltype = FUELTYPE.CHEMICAL
  inst.components.fueled:SetDepletedFn(function(owner)
    owner.components.fueled:StopConsuming()
    OnFuelDirty(owner)
  end)
  inst.components.fueled:SetTakeFuelFn(function(owner)
    owner.components.fueled:StopConsuming()
    OnFuelDirty(owner)
  end)
  inst.components.fueled:StopConsuming()
end

local function ConsumePortableSupplyFuel(inst, amount)
  local fueled = inst.components.fueled
  if fueled == nil then
    return 0
  end

  local requested = ClampNonNegative(amount)
  local currentfuel = GetFuelAmount(inst)
  local consumed = math.min(requested, currentfuel)
  if consumed <= 0 then
    return 0
  end

  fueled:DoDelta(-consumed)
  fueled:StopConsuming()
  OnFuelDirty(inst)
  return consumed
end

local function CopyFuelPercent(source, target)
  if source.components.fueled == nil or target.components.fueled == nil then
    return
  end
  target.components.fueled:SetPercent(GetFuelPercent(source))
  target.components.fueled:StopConsuming()
  OnFuelDirty(target)
end

local function SpawnCollapsedFx(inst)
  local fx = SpawnPrefab("collapse_small")
  if fx ~= nil then
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
  end
end

local function RemoveRangeFx(inst)
  if inst._rangefx ~= nil then
    if inst._rangefx:IsValid() then
      inst._rangefx:Remove()
    end
    inst._rangefx = nil
  end
end

local function EnsureRangeFx(inst)
  if inst._rangefx ~= nil and inst._rangefx:IsValid() then
    return inst._rangefx
  end

  local fx = SpawnPrefab("ark_portable_supply_range")
  if fx == nil then
    return nil
  end

  fx.entity:SetParent(inst.entity)
  fx.Transform:SetPosition(0, 0, 0)
  inst._rangefx = fx
  return fx
end

local function DropAsItem(inst)
  local item = SpawnPrefab("ark_portable_supply")
  if item ~= nil then
    item.Transform:SetPosition(inst.Transform:GetWorldPosition())
    CopyFuelPercent(inst, item)
  end
end

local function OnHammered(inst, worker)
  RemoveRangeFx(inst)
  DropAsItem(inst)
  SpawnCollapsedFx(inst)
  inst:Remove()
end

local function OnHit(inst, worker)
  inst.AnimState:PlayAnimation("hit")
  inst._restoreidle = true
end

local function SetInventoryState(inst)
  if not inst._isdeployed then
    return
  end

  inst._isdeployed = false
  inst:RemoveTag("structure")

  RemovePhysicsColliders(inst)
  MakeInventoryPhysics(inst)
  inst.Physics:Stop()

  if inst.components.inventoryitem ~= nil then
    inst.components.inventoryitem.nobounce = false
  end

  inst.components.workable:SetWorkable(false)
  inst.components.sanityaura.aura = 0
  inst.components.ark_supply_charger:SetEnabled(false)
  RemoveRangeFx(inst)

  PlayIdleAnimation(inst)
end

local function SetDeployedState(inst, playopen)
  if inst._isdeployed then
    return
  end

  inst._isdeployed = true
  inst:AddTag("structure")

  RemovePhysicsColliders(inst)
  MakeObstaclePhysics(inst, 0.8)
  inst.Physics:Stop()

  if inst.components.inventoryitem ~= nil then
    inst.components.inventoryitem.nobounce = true
  end

  inst.components.workable:SetWorkable(true)
  inst.components.sanityaura.aura = TUNING.SANITYAURA_TINY
  inst.components.ark_supply_charger:SetEnabled(true)
  EnsureRangeFx(inst)

  if playopen then
    inst.AnimState:PlayAnimation("open")
    inst._restoreidle = true
  else
    PlayIdleAnimation(inst)
  end
end

local function OnDeploy(inst, pt, deployer)
  inst.Physics:Stop()
  inst.Physics:Teleport(pt:Get())
  SetDeployedState(inst, true)
end

local function OnPutInInventory(inst)
  SetInventoryState(inst)
end

local function OnDropped(inst)
  SetInventoryState(inst)
end

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()

  MakeInventoryPhysics(inst)
  inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.LESS] / 2)

  inst.AnimState:SetBank("ark_portable_supply")
  inst.AnimState:SetBuild("ark_portable_supply")
  inst.AnimState:PlayAnimation("idle_3", true)

  MakeInventoryFloatable(inst)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst._isdeployed = false
  inst._rangefx = nil

  inst:AddComponent("inspectable")
  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem:SetOnPutInInventoryFn(OnPutInInventory)
  inst.components.inventoryitem:SetOnDroppedFn(OnDropped)

  ConfigureFuel(inst)

  inst:AddComponent("deployable")
  inst.components.deployable.ondeploy = OnDeploy
  inst.components.deployable:SetDeployMode(DEPLOYMODE.DEFAULT)
  inst.components.deployable:SetDeploySpacing(DEPLOYSPACING.LESS)

  inst:AddComponent("sanityaura")
  inst.components.sanityaura.aura = 0

  inst:AddComponent("ark_supply_charger")
  inst.components.ark_supply_charger:SetRange(DEFAULT_SCAN_RANGE)
  inst.components.ark_supply_charger:SetScanInterval(DEFAULT_SCAN_INTERVAL)
  inst.components.ark_supply_charger:SetChargeAmount(DEFAULT_CHARGE_AMOUNT)
  inst.components.ark_supply_charger:SetFuelAmountFn(GetFuelAmount)
  inst.components.ark_supply_charger:SetConsumeFuelFn(ConsumePortableSupplyFuel)
  inst.components.ark_supply_charger:SetEnabled(false)

  inst:AddComponent("workable")
  inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
  inst.components.workable:SetWorkLeft(4)
  inst.components.workable:SetOnFinishCallback(OnHammered)
  inst.components.workable:SetOnWorkCallback(OnHit)
  inst.components.workable:SetWorkable(false)

  inst:ListenForEvent("animover", OnAnimOver)
  inst:ListenForEvent("percentusedchange", function(owner)
    OnFuelDirty(owner)
  end)

  MakeHauntableWork(inst)

  inst:ListenForEvent("onremove", function(owner)
    RemoveRangeFx(owner)
  end)

  inst.OnSave = function(owner, data)
    data.isdeployed = owner._isdeployed or nil
  end
  inst.OnLoad = function(owner, data)
    if data ~= nil and data.isdeployed then
      SetDeployedState(owner, false)
    else
      PlayIdleAnimation(owner)
    end
  end

  PlayIdleAnimation(inst)

  return inst
end

return Prefab("ark_portable_supply", fn, assets),
    MakePlacer("ark_portable_supply_placer", "ark_portable_supply", "ark_portable_supply", "place")
