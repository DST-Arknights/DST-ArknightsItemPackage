-------------------------------------------------------------------
-- ark_flyer 组件副本 (replica)
--
-- 网络变量唯一安装点：net_flying / net_percent。
-- 主机端 AddComponent 时同样会创建 replica（ReplicateComponent），
-- 因此组件不重复定义网络变量，直接通过 inst.replica.ark_flyer 读写。
-------------------------------------------------------------------

local FLY_HEIGHT = 0.5
local MOTOR_K = 32

local function IsPredictionEnabled(inst)
    local locomotor = inst.components and inst.components.locomotor
    return locomotor ~= nil and locomotor.is_prediction_enabled == true
end

local function RefreshClientState(inst)
    local replica = inst.replica and inst.replica.ark_flyer
    if replica ~= nil then
        replica:RefreshClientUpdate()
    end
end

local function OnNetStateDirty(inst)
    RefreshClientState(inst)
end

local function OnMovementPrediction(inst, enable)
    local replica = inst.replica and inst.replica.ark_flyer
    if replica == nil then
        return
    end

    if enable then
        -- player_common 在推送事件后才创建 locomotor，延后一帧再检查。
        inst:DoTaskInTime(0, RefreshClientState)
    else
        replica:StopClientUpdate()
        replica:RestoreGroundPhysics()
    end
end

local ArkFlyerReplica = Class(function(self, inst)
    self.inst = inst
    self.updating = false
    self.physics_flying = false

    -- 飞行状态开关；net_percent 为 0~1 的目标高度，高度 = FLY_HEIGHT * percent
    self.net_flying  = net_bool(inst.GUID, "ark_flyer_flying",  "ark_flyer_flying_dirty")
    self.net_percent = net_float(inst.GUID, "ark_flyer_percent", "ark_flyer_percent_dirty")

    if not TheWorld.ismastersim then
        inst:ListenForEvent("ark_flyer_flying_dirty", OnNetStateDirty)
        inst:ListenForEvent("ark_flyer_percent_dirty", OnNetStateDirty)
        inst:ListenForEvent("enablemovementprediction", OnMovementPrediction)
    end
end)

function ArkFlyerReplica:IsFlying()
    return self.net_flying:value()
end

function ArkFlyerReplica:GetPercent()
    return self.net_percent:value()
end

function ArkFlyerReplica:DriveHeight()
    local inst = self.inst
    if not inst.Physics then
        return
    end

    local vx, _, vz = inst.Physics:GetMotorVel()
    local _, y = inst.Transform:GetWorldPosition()
    inst.Physics:SetMotorVel(vx, (FLY_HEIGHT * self:GetPercent() - y) * MOTOR_K, vz)
end

function ArkFlyerReplica:ApplyFlyingPhysics()
    if self.physics_flying or not self.inst.Physics then
        return
    end

    RemovePhysicsColliders(self.inst)
    self.physics_flying = true
end

function ArkFlyerReplica:RestoreGroundPhysics()
    if not self.physics_flying then
        return
    end

    if not self.inst:HasTag("playerghost") and self.inst.Physics then
        ChangeToCharacterPhysics(self.inst)
    end
    self.physics_flying = false
end

function ArkFlyerReplica:StartClientUpdate()
    if not self.updating then
        self.updating = true
        self.inst:StartUpdatingComponent(self)
    end
end

function ArkFlyerReplica:StopClientUpdate()
    if self.updating then
        self.updating = false
        self.inst:StopUpdatingComponent(self)
    end
end

function ArkFlyerReplica:RefreshClientUpdate()
    if TheWorld.ismastersim then
        return
    end

    if IsPredictionEnabled(self.inst) and self:IsFlying() then
        self:ApplyFlyingPhysics()
        self:StartClientUpdate()
        self:DriveHeight()
    else
        self:StopClientUpdate()
        self:RestoreGroundPhysics()
    end
end

function ArkFlyerReplica:OnUpdate()
    if not IsPredictionEnabled(self.inst) or not self:IsFlying() then
        self:StopClientUpdate()
        self:RestoreGroundPhysics()
        return
    end

    self:DriveHeight()
end

function ArkFlyerReplica:OnRemoveFromEntity()
    if not TheWorld.ismastersim then
        self.inst:RemoveEventCallback("ark_flyer_flying_dirty", OnNetStateDirty)
        self.inst:RemoveEventCallback("ark_flyer_percent_dirty", OnNetStateDirty)
        self.inst:RemoveEventCallback("enablemovementprediction", OnMovementPrediction)
    end

    self:StopClientUpdate()
    self:RestoreGroundPhysics()
end

return ArkFlyerReplica
