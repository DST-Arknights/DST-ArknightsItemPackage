AddPlayerPostInit(function(inst)
  if not TheWorld.ismastersim then
    return
  end

  if inst.components.sympathetic_pendant == nil then
    inst:AddComponent("sympathetic_pendant")
  end
end)