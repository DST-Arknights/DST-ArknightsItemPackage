local Noop = function() end

AddStategraphState("wilson", State {
  name = "ark_aoe_select",
  onenter = function(inst)
    inst:PerformBufferedAction()
  end,
})

AddStategraphState("wilson_client", State {
  name = "ark_aoe_select",

  onenter = function(inst)
    inst:PerformPreviewBufferedAction()
  end,
})

local function HookWilsonSg(sg)
  local actionhandlers = sg.actionhandlers
  ArkHookFunction(actionhandlers[ACTIONS.CASTAOE], "deststate", function(next, inst, action, ...)
    if inst._now_ark_aoe_selector then
      return "ark_aoe_select"
    end
    return next(inst, action, ...)
  end)
end

AddStategraphPostInit("wilson", HookWilsonSg)
AddStategraphPostInit("wilson_client", HookWilsonSg)

ArkHookFunction(ACTIONS.CASTAOE, "stroverridefn", function(next, act, ...)
  if act.doer._now_ark_aoe_selector then
    return act.doer._now_ark_aoe_selector.components.spellbook:GetSpellName()
  end
  return next(act, ...)
end)

ArkHookFunction(ACTIONS.CASTAOE, "fn", function(next, act, ...)
  if act.doer._now_ark_aoe_selector then
    local act_post = act:GetActionPoint()
    if act.doer._now_ark_aoe_selector.components.aoespell:CanCast(act.doer, act_post) then
      return act.doer._now_ark_aoe_selector.components.aoespell:CastSpell(act.doer, act_post)
    end
    return false
  end
  return next(act, ...)
end)

local function StopAoeSelect(doer)
  if doer._now_ark_aoe_selector then
    if doer.sg.currentstate and doer.sg.currentstate.name == "ark_aoe_select" then
      doer.sg:GoToState("idle")
    end
    doer._now_ark_aoe_selector:Remove()
    doer._now_ark_aoe_selector = nil
  end
end

local function StartAoeSelect(doer, style, fn, cancel_fn)
  fn = fn or Noop
  cancel_fn = cancel_fn or Noop

  StopAoeSelect(doer)

  local spell = SpawnPrefab("ark_skill_spell")
  doer._now_ark_aoe_selector = spell
  spell.components.aoespell:SetSpellFn(function(inst, doer, pos)
    fn(doer, pos)
    StopAoeSelect(doer)
  end)
  spell.onstoptargetingfn = function(inst)
    cancel_fn(doer)
  end
  spell.entity:SetParent(doer.entity)
  spell.Network:SetClassifiedTarget(doer)
end

GLOBAL.StartAoeSelect = StartAoeSelect
GLOBAL.StopAoeSelect = StopAoeSelect
