local SympatheticPendantData = Class(function(self)
  self.resonance_data = {}
end)

local function NormalizeGuidPair(guidA, guidB)
  if guidA < guidB then
    return guidA, guidB
  else
    return guidB, guidA
  end
end

function SympatheticPendantData:GetPairData(guidA, guidB)
  local first, second = NormalizeGuidPair(guidA, guidB)

  if not self.resonance_data[first] then
    self.resonance_data[first] = {}
  end
  if not self.resonance_data[first][second] then
    self.resonance_data[first][second] = { resonance = 0 }
  end
  return self.resonance_data[first][second]
end

function SympatheticPendantData:OnSave()
  if next(self.resonance_data) == nil then
    return nil
  end
  return {
    resonance_data = self.resonance_data
  }
end

function SympatheticPendantData:OnLoad(data)
  if data and data.resonance_data then
    self.resonance_data = data.resonance_data
  end
end

return SympatheticPendantData
