local ENHANCE_TYPE = {}
GLOBAL.ENHANCE_TYPE = ENHANCE_TYPE

function GLOBAL.RegisterEnhanceType(enhance_type, condition)
  if not enhance_type or not condition then
    return
  end
  if type (condition) == "string" then
    ENHANCE_TYPE[enhance_type] = function(inst) return inst.prefab == condition end
  elseif type(condition) == "function" then
    ENHANCE_TYPE[enhance_type] = condition
  elseif type(condition) == "table" then
    ENHANCE_TYPE[enhance_type] = function(inst)
      for _, prefab in pairs(condition) do
        if inst.prefab == prefab then
          return true
        end
      end
      return false
    end
  else
    ENHANCE_TYPE[enhance_type] = function(inst) return false end
  end
  -- ENHANCE_TYPE[enhance_type] = condition
end

AddAction("ENHANCE", STRINGS.ACTIONS.ENHANCE.GENERIC, function(act)
  if act.invobject and act.target and act.target.components.enhanceable then
    return act.target.components.enhanceable:Enhance(act.invobject, act.doer)
  end
  return false
end)

AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
  if not target or not target:HasTag("enhanceable") then
    return
  end
  for enhance_type, condition in pairs(ENHANCE_TYPE) do
    if target:HasTag(enhance_type .. "_enhanceable") then
      if condition(inst, doer, target) then
        table.insert(actions, ACTIONS.ENHANCE)
        return
      end
    end
  end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.ENHANCE, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.ENHANCE, "doshortaction"))
