AddAction('ARK_TRANSFER', STRINGS.ACTIONS.ARK_TRANSFER, function(act)
  local target = act.target or act.invobject
  if target.components.ark_transfer then
    return target.components.ark_transfer:Transfer(act.doer)
  end
  return false
end)
ACTIONS.ARK_TRANSFER.distance = 2

AddComponentAction("SCENE", "ark_transfer", function(inst, doer, actions, right)
    if right then
        table.insert(actions, ACTIONS.ARK_TRANSFER)
    end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.ARK_TRANSFER, "give"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.ARK_TRANSFER, "give"))
