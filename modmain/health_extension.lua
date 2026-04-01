local SourceModifierList = require("util/sourcemodifierlist")

AddComponentPostInit("health", function(self)
  -- 最小生命值
  self.minhealthmodifiers = SourceModifierList(self.inst, 0, function(a, b)
    return math.max(a, b)
  end)

  local _SetVal = self.SetVal
  function self:SetVal(val, cause, afflicter)
    local original_minhealth = self.minhealth
    self.minhealth = math.max(self.minhealth, self.minhealthmodifiers:Get())
    local result = _SetVal(self, val, cause, afflicter)
    self.minhealth = original_minhealth
    return result
  end
end)
