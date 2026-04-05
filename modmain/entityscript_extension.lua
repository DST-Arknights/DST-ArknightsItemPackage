local _RemoveComponent = EntityScript.RemoveComponent

function EntityScript:RemoveComponent(name)
  local cmp = self.components[name]
  if cmp then
    if type(cmp.OnPreRemoveFromEntity) == "function" then
      cmp:OnPreRemoveFromEntity()
    end
  end
  return _RemoveComponent(self, name)
end
