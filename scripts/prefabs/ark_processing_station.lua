local assets = {Asset("ANIM", "anim/crafting_table.zip"), Asset("MINIMAP_IMAGE", "tab_crafting_table"),
  Asset("SCRIPT", "scripts/prefabs/ruinsrespawner.lua")}
local prefabs = {}

local function complete_onturnon(inst)
  if inst.AnimState:IsCurrentAnimation("proximity_loop") then
    -- NOTE: push again even if already playing, in case an idle was also pushed
    inst.AnimState:PushAnimation("proximity_loop", true)
  else
    inst.AnimState:PlayAnimation("proximity_loop", true)
  end
  if not inst.SoundEmitter:PlayingSound("idlesound") then
    inst.SoundEmitter:PlaySound("dontstarve/common/ancienttable_LP", "idlesound")
  end
end

local function complete_onturnoff(inst) inst.AnimState:PushAnimation("idle_full") end

local function complete_onhammered(inst, worker) inst:Remove() end
local function commonFn() return inst end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddMiniMapEntity()
  inst.entity:AddSoundEmitter()
  inst.entity:AddLight()
  inst.entity:AddNetwork()

  MakeObstaclePhysics(inst, 0.8, 1.2)

  inst.MiniMapEntity:SetPriority(5)
  inst.MiniMapEntity:SetIcon("tab_crafting_table.png")

  inst.AnimState:SetBank("crafting_table")
  inst.AnimState:SetBuild("crafting_table")
  inst.AnimState:PlayAnimation("idle_full")

  inst.Light:Enable(false)
  inst.Light:SetRadius(0)
  inst.Light:SetFalloff(1)
  inst.Light:SetIntensity(.5)
  inst.Light:SetColour(1, 1, 1)
  inst.Light:EnableClientModulation(true)

  inst:AddTag("altar")
  inst:AddTag("structure")
  inst:AddTag("stone")

  -- prototyper (from prototyper component) added to pristine state for optimization
  inst:AddTag("ark_processing_station")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst._activecount = 0

  inst:AddComponent("inspectable")

  inst:AddComponent("prototyper")

  inst:AddComponent("workable")

  MakeHauntableWork(inst)
  inst.scrapbook_specialinfo = "ARK_PROCESSING_STATION"

  inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.ARK_PROCESSING_STATION_ONE

  inst.components.prototyper.onturnon = complete_onturnon
  inst.components.prototyper.onturnoff = complete_onturnoff

  inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
  inst.components.workable:SetWorkLeft(10)
  inst.components.workable:SetMaxWork(10)
  inst.components.workable:SetOnFinishCallback(complete_onhammered)

  return inst
end

return Prefab("ark_processing_station", fn, assets, prefabs),
  MakePlacer("ark_processing_station_placer", "crafting_table", "crafting_table", "idle_full")
