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
  return math.max(tonumber(value) or 0, 0)
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

local function PlayStateAnimation(inst)
  local anim = inst._isdeployed and GetIdleAnimation(inst) or "place"
  inst.AnimState:PlayAnimation(anim, true)
end

local function PlayTransientAnimation(inst, anim)
  inst._playingtransientanim = true
  inst.AnimState:PlayAnimation(anim)
end

local function OnFuelDirty(inst)
  if not inst._playingtransientanim then
    PlayStateAnimation(inst)
  end
end

local function OnAnimOver(inst)
  if inst._playingtransientanim then
    inst._playingtransientanim = nil
    PlayStateAnimation(inst)
  end
end

local function StopFuelConsumption(inst)
  inst.components.fueled:StopConsuming()
end

local function ConfigureFuel(inst)
  inst:AddComponent("fueled")
  inst.components.fueled:InitializeFuelLevel(MAX_FUEL)
  inst.components.fueled.accepting = true
  inst.components.fueled.bonusmult = 5
  inst.components.fueled.secondaryfueltype = FUELTYPE.CHEMICAL
  inst.components.fueled:SetDepletedFn(StopFuelConsumption)
  inst.components.fueled:SetTakeFuelFn(StopFuelConsumption)
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
  return consumed
end

local function CopyFuelPercent(source, target)
  if source.components.fueled == nil or target.components.fueled == nil then
    return
  end
  target.components.fueled:SetPercent(GetFuelPercent(source))
  target.components.fueled:StopConsuming()
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
  PlayTransientAnimation(inst, "hit")
end

local function SetDeploymentState(inst, deployed, playopen)
  if inst._isdeployed == deployed then
    if not inst._playingtransientanim then
      PlayStateAnimation(inst)
    end
    return
  end

  inst._isdeployed = deployed
  inst._playingtransientanim = nil

  RemovePhysicsColliders(inst)

  if deployed then
    inst:AddTag("structure")
    MakeObstaclePhysics(inst, 0.8)

    inst.components.inventoryitem.nobounce = true

    inst.components.workable:SetWorkable(true)
    inst.components.sanityaura.aura = TUNING.SANITYAURA_TINY
    inst.components.ark_supply_charger:SetEnabled(true)
    EnsureRangeFx(inst)
  else
    inst:RemoveTag("structure")
    MakeInventoryPhysics(inst)

    inst.components.inventoryitem.nobounce = false

    inst.components.workable:SetWorkable(false)
    inst.components.sanityaura.aura = 0
    inst.components.ark_supply_charger:SetEnabled(false)
    RemoveRangeFx(inst)
  end

  inst.Physics:Stop()

  if deployed and playopen then
    PlayTransientAnimation(inst, "open")
  else
    PlayStateAnimation(inst)
  end
end

local function OnDeploy(inst, pt, deployer)
  inst.Physics:Stop()
  inst.Physics:Teleport(pt:Get())
  SetDeploymentState(inst, true, true)
end

local function OnBecomeInventoryItem(inst)
  SetDeploymentState(inst, false)
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
  inst.AnimState:PlayAnimation("place", true)

  MakeInventoryFloatable(inst)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst._isdeployed = nil
  inst._playingtransientanim = nil
  inst._rangefx = nil

  inst:AddComponent("inspectable")
  inst:AddComponent("inventoryitem")
  inst.components.inventoryitem:SetOnPutInInventoryFn(OnBecomeInventoryItem)
  inst.components.inventoryitem:SetOnDroppedFn(OnBecomeInventoryItem)

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
    SetDeploymentState(owner, data ~= nil and data.isdeployed == true)
  end

  SetDeploymentState(inst, false)

  return inst
end

return Prefab("ark_portable_supply", fn, assets),
    MakePlacer("ark_portable_supply_placer", "ark_portable_supply", "ark_portable_supply", "place")
