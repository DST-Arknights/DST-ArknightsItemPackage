local Controllable = Class(function(self, inst)
    self.inst = inst
    self.is_controlled = false
    self.oncontrolstartfn = nil
    self.oncontrolendfn = nil
    self.controls = {}

    self.inst:AddTag("controllable")
end)

local function CancelBufferedAction(inst)
    if inst.bufferedaction ~= nil then
        inst:ClearBufferedAction()
    end
end

local function CountTable(source)
    local count = 0
    for _ in pairs(source) do
        count = count + 1
    end
    return count
end

local function GetTableKeys(source)
    local keys = {}
    for key in pairs(source) do
        table.insert(keys, key)
    end
    return keys
end

local function ResolveControlDefinition(key)
    local getDefinition = rawget(_G, "GetControlDefinition")
    assert(type(getDefinition) == "function", "GetControlDefinition is not available.")
    assert(type(key) == "string" and key ~= "", "Control key is invalid.")
    return getDefinition(key)
end

function Controllable:IsControlled()
    return self.is_controlled
end

function Controllable:SetOnControlStart(fn)
    self.oncontrolstartfn = fn
end

function Controllable:SetOnControlEnd(fn)
    self.oncontrolendfn = fn
end

function Controllable:GetControlCount()
    return CountTable(self.controls)
end

function Controllable:_CancelControlTask(control)
    if control.task ~= nil then
        control.task:Cancel()
        control.task = nil
    end
end

function Controllable:_ClearControlFX(control)
    for i, fx in ipairs(control.fxchildren) do
        if fx ~= nil and fx:IsValid() then
            fx:Remove()
        end
        control.fxchildren[i] = nil
    end
end

function Controllable:_SpawnControlFX(control)
    self:_ClearControlFX(control)

    local getCombatFxSize = rawget(_G, "GetCombatFxSize")
    assert(type(getCombatFxSize) == "function", "GetCombatFxSize is not available.")

    for _, data in ipairs(control.definition.fx) do
        local fx = self.inst:SpawnChild(data.prefab)
        if fx ~= nil then
            local radius = getCombatFxSize(self.inst)
            local scalex, scaley, scalez = self.inst.Transform:GetScale()
            fx.Transform:SetPosition(data.x, data.y, data.z)
            fx.Transform:SetScale(1 / scalex * radius, 1 / scaley * radius, 1 / scalez * radius)
            table.insert(control.fxchildren, fx)
        end
    end
end

function Controllable:_EnterControlled(key, duration)
    if self.is_controlled then
        return
    end

    self.is_controlled = true
    self.inst:AddTag("controlled")

    CancelBufferedAction(self.inst)

    if self.inst.components.combat ~= nil then
        self.inst.components.combat:SetTarget(nil)
    end

    if self.inst.components.locomotor ~= nil then
        self.inst.components.locomotor:Stop()
    end

    if self.inst.sg ~= nil then
        self.inst.sg:GoToState("idle")
    end

    self.inst:StopBrain("controlled")

    if self.oncontrolstartfn ~= nil then
        self.oncontrolstartfn(self.inst)
    end

    self.inst:PushEvent("controlstart", { key = key, duration = duration })
end

function Controllable:_ExitControlled(key)
    if not self.is_controlled then
        return
    end

    self.is_controlled = false
    self.inst:RemoveTag("controlled")

    if not (self.inst.components.health ~= nil and self.inst.components.health:IsDead()) then
        self.inst:RestartBrain("controlled")
    end

    if self.oncontrolendfn ~= nil then
        self.oncontrolendfn(self.inst)
    end

    self.inst:PushEvent("controlend", { key = key })
end

function Controllable:_RemoveControl(key, skip_exit)
    local control = self.controls[key]
    if control == nil then
        return false
    end

    self:_CancelControlTask(control)
    self:_ClearControlFX(control)
    self.controls[key] = nil

    if control.definition.onRemove ~= nil then
        control.definition.onRemove(self.inst, key, control)
    end

    if not skip_exit and next(self.controls) == nil then
        self:_ExitControlled(key)
    end

    return true
end

function Controllable:ApplyControl(key, duration)
    local definition = ResolveControlDefinition(key)
    if duration == nil then
        duration = definition.duration
    end

    local control = self.controls[key]
    local is_new_control = control == nil
    if is_new_control then
        control = {
            key = key,
            definition = definition,
            fxchildren = {},
            task = nil,
        }
        self.controls[key] = control
    else
        control.definition = definition
        self:_CancelControlTask(control)
    end

    if is_new_control then
        self:_SpawnControlFX(control)
        if definition.onApply ~= nil then
            definition.onApply(self.inst, key, control)
        end
    end

    self:_EnterControlled(key, duration)

    if duration ~= nil and duration > 0 then
        control.task = self.inst:DoTaskInTime(duration, function()
            if self.inst:IsValid() then
                self:RemoveControl(key)
            end
        end)
    end

    return control
end

function Controllable:RemoveControl(key)
    return self:_RemoveControl(key, false)
end

function Controllable:HasControl(key)
    return self.controls[key] ~= nil
end

function Controllable:OnRemoveFromEntity()
    self.inst:RemoveTag("controllable")
    self.inst:RemoveTag("controlled")

    for _, key in ipairs(GetTableKeys(self.controls)) do
        self:_RemoveControl(key, true)
    end

    self.is_controlled = false
end

function Controllable:ClearControls()
    local had_control = next(self.controls) ~= nil
    for _, key in ipairs(GetTableKeys(self.controls)) do
        self:_RemoveControl(key, true)
    end

    if had_control then
        self:_ExitControlled(nil)
    end

    return had_control
end

return Controllable