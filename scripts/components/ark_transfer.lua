local ArkTransfer = Class(function(self, inst)
  self.inst = inst
end)

function ArkTransfer:Transfer(doer)
  ArkLogger:Debug("ark_transfer transfer", self.inst, doer)
  return true
end

return ArkTransfer
