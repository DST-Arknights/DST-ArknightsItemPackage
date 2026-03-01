local Immobilizable = Class(function(self, inst)
    self.inst = inst
    self.is_immobilized = false
    self.task = nil
    self.fxdata = {
    }
    self.fxchildren = {}

    self.inst:AddTag("immobilizable")
end)

function Immobilizable:OnRemoveFromEntity()
    self.inst:RemoveTag("immobilizable")
    self.inst:RemoveTag("immobilized")

    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    self:ClearImmobilizeFX()
end

local function CancelBufferedAction(inst)
    if inst.bufferedaction ~= nil then
        inst:ClearBufferedAction()
    end
end

function Immobilizable:IsImmobilized()
    return self.is_immobilized
end

function Immobilizable:AddImmobilizeFX(prefab, offset)
    if prefab == nil then
        return
    end
    offset = offset or { x = 0, y = 0, z = 0 }
    table.insert(self.fxdata, { prefab = prefab, x = offset.x or 0, y = offset.y or 0, z = offset.z or 0 })
end

function Immobilizable:SpawnImmobilizeFX()
    self:ClearImmobilizeFX()

    for _, data in ipairs(self.fxdata) do
        local fx = self.inst:SpawnChild(data.prefab)
        if fx ~= nil then
            local r, sz, ht = GetCombatFxSize(self.inst)
            local scalex, scaley, scalez = self.inst.Transform:GetScale()
            fx.Transform:SetPosition(data.x, data.y, data.z)
            fx.Transform:SetScale(1 / scalex * r, 1 / scaley * r, 1 / scalez * r)
            table.insert(self.fxchildren, fx)
        end
    end
end

function Immobilizable:ClearImmobilizeFX()
    for i, fx in ipairs(self.fxchildren) do
        if fx ~= nil and fx:IsValid() then
            fx:Remove()
        end
        self.fxchildren[i] = nil
    end
end

function Immobilizable:Immobilize(duration)
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    if self.is_immobilized then
        if duration ~= nil and duration > 0 then
            self.task = self.inst:DoTaskInTime(duration, function()
                if self.inst:IsValid() then
                    self:Unimmobilize()
                end
            end)
        end
        return
    end

    self.is_immobilized = true
    self.inst:AddTag("immobilized")

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

    self:SpawnImmobilizeFX()

    self.inst:StopBrain("immobilized")
    self.inst:PushEvent("immobilize")

    if duration ~= nil and duration > 0 then
        self.task = self.inst:DoTaskInTime(duration, function()
            if self.inst:IsValid() then
                self:Unimmobilize()
            end
        end)
    end
end

function Immobilizable:Unimmobilize()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    if not self.is_immobilized then
        return
    end

    self.is_immobilized = false
    self.inst:RemoveTag("immobilized")
    self:ClearImmobilizeFX()

    if not (self.inst.components.health ~= nil and self.inst.components.health:IsDead()) then
        self.inst:RestartBrain("immobilized")
    end

    self.inst:PushEvent("unimmobilize")
end

return Immobilizable
