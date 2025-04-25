local common = require("ark_common")

local assets = {Asset("ANIM", "anim/ark_training_station.zip"),
  Asset("ATLAS", "images/ark_training_station.xml"),
  Asset("ATLAS", "images/map_icons/ark_training_station.xml"),
  }

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()
  inst.entity:AddMiniMapEntity()

  MakeObstaclePhysics(inst, .4)

  inst.AnimState:SetBank("ark_training_station")
  inst.AnimState:SetBuild("ark_training_station")
  inst.AnimState:PlayAnimation("idle", true)

  inst.MiniMapEntity:SetIcon("ark_training_station.tex")

  inst:AddTag("structure")
  inst:AddTag("ark_training_station")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")
  inst:AddComponent("lootdropper")
  inst:AddComponent("workable")
  inst:AddComponent("prototyper")
  inst.scrapbook_specialinfo = "ARK_TRAINING_STATION"

  inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.ARK_TRAINING_STATION_ONE
  inst.components.prototyper.onactivate = function(inst, doer, recipe)
    if not doer or not doer.components.ark_skill or not recipe then
      return
    end
    local skillIdx, level = common.parseArkSkillLevelUpPrefabName(recipe.name)
    if not skillIdx or not level then
      return
    end
    doer.components.ark_skill:SetSkillLevel(skillIdx, level)
  end
  inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
  inst.components.workable:SetWorkLeft(4)
  inst.components.workable:SetOnFinishCallback(function(inst, worker)
    inst.components.lootdropper:DropLoot()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("wood")
    inst:Remove()
  end)

  MakeSnowCovered(inst)
  MakeHauntableWork(inst)

  return inst
end

return Prefab("ark_training_station", fn, assets),
  MakePlacer('ark_training_station_placer', 'ark_training_station', 'ark_training_station', 'idle')
