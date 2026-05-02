local aliveFxSymbol = Symbol("alive_fx")

local function OnSgStateChange(inst, data)
  if not data or data.newstate ~= "death" then
    return
  end
  local fxs = inst[aliveFxSymbol]
  if fxs then
    local symbols = {}
    for symbol in pairs(fxs) do
      table.insert(symbols, symbol)
    end
    for _, symbol in ipairs(symbols) do
      RemoveAliveFx(inst, symbol)
    end
  end
end


AddPrefabPostInitAny(function(inst)
  inst[aliveFxSymbol] = {}
  inst:ListenForEvent("sgstatechange", OnSgStateChange)
end)

function GLOBAL.AddAliveFx(inst, fx)
  if inst.components.health and inst.components.health:IsDead() then
    return nil
  end
  local fxs = inst[aliveFxSymbol]
  local symbol = Symbol("alive_fx")
  fxs[symbol] = fx
  fx.entity:SetParent(inst.entity)
  fx:ListenForEvent("onremove", function()
    RemoveAliveFx(inst, symbol)
  end)
  return symbol
end

function GLOBAL.GetAliveFx(inst)
  if not inst or not inst:IsValid() then
    return nil
  end
  return inst[aliveFxSymbol]
end

function GLOBAL.RemoveAliveFx(inst, fxSymbol)
  local fxs = inst[aliveFxSymbol]
  local fx = fxs[fxSymbol]
  if fx then
    fxs[fxSymbol] = nil
    if fx:IsValid() then
      fx:Remove()
    end
  end
end