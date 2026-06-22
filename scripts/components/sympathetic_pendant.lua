local SympatheticPendant = Class(function(self, inst)
  self.inst = inst
  self.data = {
    -- key: otheruserid, value: table,
    -- "KU_xxxxx": { resonance = 0}
  }
end)

function SympatheticPendant:SetData(inst, data)
  if not inst or not inst.userid then
    return
  end
  local user_data = self.data[inst.userid] or {}
  user_data = MergeeMaps(user_data, data)
  self.data[inst.userid] = user_data
end

function SympatheticPendant:OnSave()
  return self.data
end

function SympatheticPendant:OnLoad(data)
  self.data = data or {}
end

return SympatheticPendant
