-- 仅声明实时归属关系；世界死亡监听负责有界溯源和经验结算。
local ArkKillTransfer = Class(function(self, inst)
  self.inst = inst
  self._creditTargetFn = nil
end)

-- fn(source, victim) 返回下一层归属实体，或 nil。
function ArkKillTransfer:SetCreditTargetFn(fn)
  assert(fn == nil or type(fn) == "function", "kill credit resolver must be a function or nil")
  self._creditTargetFn = fn
end

function ArkKillTransfer:GetCreditTarget(victim)
  if self._creditTargetFn ~= nil then
    return self._creditTargetFn(self.inst, victim)
  end
end

return ArkKillTransfer
