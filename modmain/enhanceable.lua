local ENHANCE_TYPE = {}
GLOBAL.ENHANCE_TYPE = ENHANCE_TYPE

function GLOBAL.RegisterEnhanceType(type, condition)
  if not type or not condition then
    return
  end
  ENHANCE_TYPE[type] = condition
end

AddAction("ENHANCE", STRINGS.ACTIONS.ENHANCE.GENERIC, function(act)
  if act.invobject and act.target and act.target.components.enhanceable then
    local can, reason = act.target.components.enhanceable:CanEnhance(act.invobject, act.doer)
    if can then
      act.target.components.enhanceable:Enhance(act.invobject, act.doer)
      return true
    end
    return false, reason
  end
end)

AddComponentAction("USEITEM", "item_enhance", function(inst, doer, target, actions, right)
  for type, condition in pairs(ENHANCE_TYPE) do
    if target:HasTag(type .. "_enhanceable") then
      if type(condition) == "string" then
        if inst.prefab == condition then
          table.insert(actions, ACTIONS.ENHANCE)
          return
        end
      elseif type(condition) == "function" then
        if condition(inst, doer, target) then
          table.insert(actions, ACTIONS.ENHANCE)
          return
        end
      elseif type(condition) == "table" then
        for _, prefab in ipairs(condition) do
          if inst.prefab == prefab then
            table.insert(actions, ACTIONS.ENHANCE)
            return
          end
        end
      end
    end
  end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.ENHANCE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.ENHANCE, "doshortaction"))
