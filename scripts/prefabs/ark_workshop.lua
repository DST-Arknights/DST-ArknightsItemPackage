local assets = {Asset("ANIM", "anim/ark_workshop.zip"), Asset("MINIMAP_IMAGE", "tab_crafting_table"),
  }
local prefabs = {}

local function complete_onturnon(inst)
  if inst.AnimState:IsCurrentAnimation("idle_loop") then
    -- NOTE: push again even if already playing, in case an idle was also pushed
    inst.AnimState:PushAnimation("idle_loop", true)
  else
    inst.AnimState:PlayAnimation("idle_loop", true)
  end
  if not inst.SoundEmitter:PlayingSound("idlesound") then
    inst.SoundEmitter:PlaySound("dontstarve/common/ancienttable_LP", "idlesound")
  end
end

local function complete_onturnoff(inst) inst.AnimState:PushAnimation("idle") end

local function complete_onhammered(inst, worker) inst:Remove() end

local function onbuilt(inst)
  inst.AnimState:PlayAnimation("place")
  inst.AnimState:PushAnimation("idle", false)
end
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

  inst.AnimState:SetBank("ark_workshop")
  inst.AnimState:SetBuild("ark_workshop")
  inst.AnimState:PlayAnimation("idle")

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
  inst:AddTag("ark_workshop")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst._activecount = 0

  inst:AddComponent("inspectable")

  inst:AddComponent("prototyper")

  inst:AddComponent("workable")

  MakeHauntableWork(inst)
  inst.scrapbook_specialinfo = "ARK_WORKSHOP"

  inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.ARK_WORKSHOP_ONE

  inst.components.prototyper.onturnon = complete_onturnon
  inst.components.prototyper.onturnoff = complete_onturnoff

  inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
  inst.components.workable:SetWorkLeft(10)
  inst.components.workable:SetMaxWork(10)
  inst.components.workable:SetOnFinishCallback(complete_onhammered)
  inst.components.workable:SetOnWorkCallback(onhit)
  inst:ListenForEvent("onbuilt", onbuilt)

  return inst
end

return Prefab("ark_workshop", fn, assets, prefabs),
  MakePlacer("ark_workshop_placer", "ark_workshop", "ark_workshop", "idle")
