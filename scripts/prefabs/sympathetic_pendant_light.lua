local LIGHT_TRANSITION_ALPHA = 0.14
local LIGHT_TRANSITION_INTERVAL = 2 * FRAMES

local default_light = {
  colour = { 1, 1, 1 },
  radius = 1,
  falloff = 0.5,
  intensity = 0.8,
}

local function CopyLightState(state)
  local colour = state and state.colour or default_light.colour
  return {
    colour = { colour[1], colour[2], colour[3] },
    radius = state and state.radius or default_light.radius,
    falloff = state and state.falloff or default_light.falloff,
    intensity = state and state.intensity or default_light.intensity,
  }
end

local function IsLightStateClose(current, target)
  return math.abs((current.radius or 0) - (target.radius or 0)) <= 0.02
      and math.abs((current.intensity or 0) - (target.intensity or 0)) <= 0.02
      and math.abs((current.falloff or 0) - (target.falloff or 0)) <= 0.02
      and math.abs((current.colour[1] or 0) - (target.colour[1] or 0)) <= 0.02
      and math.abs((current.colour[2] or 0) - (target.colour[2] or 0)) <= 0.02
      and math.abs((current.colour[3] or 0) - (target.colour[3] or 0)) <= 0.02
end
local function ApplyLightState(inst, state)
  inst.Light:SetRadius(state.radius)
  inst.Light:SetFalloff(state.falloff)
  inst.Light:SetIntensity(state.intensity)
  inst.Light:SetColour(unpack(state.colour))
  inst.Light:Enable(state.intensity > 0.01 or state.radius > 0.01)
end
local function StopLightTransition(inst)
  if inst._transition_task ~= nil then
    inst._transition_task:Cancel()
    inst._transition_task = nil
  end
end

local function UpdateLightTransition(inst)
  if inst.current_light == nil or inst.target_light == nil then
    StopLightTransition(inst)
    return
  end

  local current = inst.current_light
  local target = inst.target_light
  current.radius = Lerp(current.radius, target.radius, LIGHT_TRANSITION_ALPHA)
  current.intensity = Lerp(current.intensity, target.intensity, LIGHT_TRANSITION_ALPHA)
  current.falloff = Lerp(current.falloff, target.falloff, LIGHT_TRANSITION_ALPHA)
  current.colour[1] = Lerp(current.colour[1], target.colour[1], LIGHT_TRANSITION_ALPHA)
  current.colour[2] = Lerp(current.colour[2], target.colour[2], LIGHT_TRANSITION_ALPHA)
  current.colour[3] = Lerp(current.colour[3], target.colour[3], LIGHT_TRANSITION_ALPHA)

  if IsLightStateClose(current, target) then
    inst.current_light = CopyLightState(target)
    current = inst.current_light
    StopLightTransition(inst)
  end

  ApplyLightState(inst, current)
end

local function UpdateLight(inst, state)
  inst.target_light = CopyLightState(state)
  if inst.current_light == nil or IsLightStateClose(inst.current_light, inst.target_light) then
    inst.current_light = CopyLightState(inst.target_light)
    ApplyLightState(inst, inst.current_light)
    StopLightTransition(inst)
    return
  end
  if inst._transition_task == nil then
    inst._transition_task = inst:DoPeriodicTask(LIGHT_TRANSITION_INTERVAL, UpdateLightTransition)
  end
end
local function lightfn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddLight()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  inst.target_light = CopyLightState(default_light)
  inst.current_light = nil
  inst.UpdateLight = UpdateLight
  ApplyLightState(inst, inst.target_light)
  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst.persists = false
  inst.entity:SetCanSleep(false)
  return inst
end
return Prefab("sympathetic_pendant_light", lightfn)
