local function ApplyFlyingPhysics(inst)
    inst.Physics:SetCollisionMask(
        TheWorld:CanFlyingCrossBarriers()
        and COLLISION.GROUND
        or COLLISION.WORLD
    )
end

local function RestoreGroundPhysics(inst)
    if not inst:HasTag("playerghost") then
        ChangeToCharacterPhysics(inst)
    end
end

------------------------------------------------------------------------

local ArkFlyer = Class(function(self, inst)
    self.inst    = inst
    self.flying  = false

    inst:ListenForEvent("ms_respawnedfromghost", function()
        self:Land()
    end)
end)

------------------------------------------------------------------------

function ArkFlyer:TakeOff()
    if self.flying then return end
    self.flying = true

    local inst = self.inst
    inst:AddTag("flying")

    ApplyFlyingPhysics(inst)

    inst.components.locomotor:EnableGroundSpeedMultiplier(false)
    inst.components.carefulwalker.carefulwalkingspeedmult = 1

    if inst.components.drownable then
        if TheWorld:HasTag("cave") then
            inst:RemoveComponent("drownable")
        else
            inst.components.drownable.enabled = false
        end
    end

    inst:PushEvent("ark_takeoff")
end

function ArkFlyer:Land()
    if not self.flying then return end
    self.flying = false

    local inst = self.inst
    inst:RemoveTag("flying")

    RestoreGroundPhysics(inst)

    inst.components.locomotor:EnableGroundSpeedMultiplier(true)
    inst.components.carefulwalker.carefulwalkingspeedmult = TUNING.CAREFUL_SPEED_MOD

    if TheWorld:HasTag("cave") then
        if not inst.components.drownable then
            inst:AddComponent("drownable")
        end
    elseif inst.components.drownable then
        inst.components.drownable.enabled = true
    end

    if inst.components.drownable and inst.components.drownable:ShouldDrown() then
        inst.sg:GoToState("sink_fast")
        return
    end

    if TheWorld:HasTag("cave") and not inst:IsOnPassablePoint() then
        local fx = SpawnPrefab("spawn_fx_medium_static")
        if fx then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end
        inst:PutBackOnGround()
    end

    inst:PushEvent("ark_land")
end

function ArkFlyer:Toggle()
    if self.flying then self:Land() else self:TakeOff() end
end

function ArkFlyer:IsFlying()
    return self.flying
end

------------------------------------------------------------------------
-- 持久化

function ArkFlyer:OnSave()
    return { flying = self.flying }
end

function ArkFlyer:OnLoad(data)
    if data and data.flying then
        self:TakeOff()
    end
end

------------------------------------------------------------------------

return ArkFlyer