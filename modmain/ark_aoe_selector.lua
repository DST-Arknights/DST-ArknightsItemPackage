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
    inst.components.locomotor:Stop()
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

-- StartAoeSelect(doer, opts)
-- opts.onSelect: function(doer, pos) - 选择确认回调（必选）
-- opts.onCancel: function(doer) - 取消回调（可选）
-- opts.config: table - 传递给 prefab 的配置（可选，用于覆盖默认 reticule/aoetargeting 配置）
local function StartAoeSelect(doer, opts)
  opts = opts or {}
  local OnSelected = opts.OnSelected or Noop
  local config = opts.config or {}

  StopAoeSelect(doer)

  local spell = SpawnPrefab("ark_aoe_selector")
  doer._now_ark_aoe_selector = spell
  spell._ark_aoe_config:set(json.encode(config))

  spell.components.aoespell:SetSpellFn(function(inst, doer, pos)
    OnSelected(doer, pos)
    StopAoeSelect(doer)
  end)
  spell.entity:SetParent(doer.entity)
  spell.Network:SetClassifiedTarget(doer)
end

GLOBAL.StartAoeSelect = StartAoeSelect
GLOBAL.StopAoeSelect = StopAoeSelect
