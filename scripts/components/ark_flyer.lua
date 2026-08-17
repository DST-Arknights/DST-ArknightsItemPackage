-------------------------------------------------------------------
-- ark_flyer 飞行组件
--
-- 参考伊蕾娜模组 (elenaflyer) 的实现思路：
--   - 用物理马达速度 SetMotorVel 控制垂直高度，而非直接改 y 坐标
--   - 目标高度 = FLY_HEIGHT * percent，percent 为 0~1 的 net_float
--   - 每帧把垂直马达速度设为 (目标高度 - 当前y) * MOTOR_K，平滑趋近
--
-- 网络变量装在 replica（inst.replica.ark_flyer）上，本组件不重复定义，
-- 写入时通过 inst.replica.ark_flyer.net_xxx:set() 完成同步。
-------------------------------------------------------------------

local FLY_HEIGHT = 0.5       -- 最高飞行高度
local FLY_SPEED   = 10     -- 飞行移动速度
local RISE_RATE   = 1.4    -- 起飞快照每秒 percent 增量
local FALL_RATE   = 2.0    -- 降落每秒 percent 减量
local MOTOR_K     = 32     -- 垂直马达比例系数

local function GetReplica(inst)
    return inst.replica and inst.replica.ark_flyer
end

------------------------------------------------------------------------

local function ApplyFlyingPhysics(inst)
    if inst.Physics then
        RemovePhysicsColliders(inst)
    end
    local locomotor = inst.components.locomotor
    if locomotor then
        locomotor:SetSlowMultiplier(.6)
        locomotor.pathcaps = { player = true, ignorecreep = true, allowocean = true }
        locomotor.fasteronroad = false
        locomotor:SetTriggersCreep(false)
        locomotor:SetAllowPlatformHopping(false)
    end
end

local function RestoreGroundPhysics(inst)
    if not inst:HasTag("playerghost") and inst.Physics then
        ChangeToCharacterPhysics(inst)
    end
    local locomotor = inst.components.locomotor
    if locomotor then
        locomotor:SetSlowMultiplier(1)
        locomotor.pathcaps = { player = true, ignorecreep = true }
        locomotor.fasteronroad = true
        locomotor:SetTriggersCreep(true)
        locomotor:SetAllowPlatformHopping(true)
    end
end

------------------------------------------------------------------------

local ArkFlyer = Class(function(self, inst)
    self.inst    = inst
    self.flying  = false
    self.speed   = FLY_SPEED
    self.height  = 0
    self._target = 0

    inst:ListenForEvent("ms_respawnedfromghost", function()
        self:Land()
    end)
end)

------------------------------------------------------------------------
-- 高度 (percent) 读写：网络变量在 replica 上

function ArkFlyer:GetPercent()
    local r = GetReplica(self.inst)
    return r ~= nil and r:GetPercent() or 0
end

function ArkFlyer:SetPercent(v)
    local r = GetReplica(self.inst)
    if r then r.net_percent:set(v) end
end

function ArkFlyer:GetFlyTargetHeight()
    self.height = FLY_HEIGHT * self:GetPercent()
    return self.height
end

-- 把角色物理驱动到目标高度（保留水平分量，避免覆盖移动马达）。
-- 移动会重新设置 SetMotorVel 覆盖垂直分量，故 locomotor.RunForward 后需再次调用。
function ArkFlyer:DriveHeight()
    local inst = self.inst
    if not inst.Physics then return end
    local vx, vy, vz = inst.Physics:GetMotorVel()
    local _, y = inst.Transform:GetWorldPosition()
    inst.Physics:SetMotorVel(vx, (self:GetFlyTargetHeight() - y) * MOTOR_K, vz)
end

function ArkFlyer:OnUpdate(dt)
    if not self.flying then
        self.inst:StopUpdatingComponent(self)
        return
    end

    -- percent 渐变到目标
    local percent = self:GetPercent()
    if self._target > percent then
        self:SetPercent(math.min(percent + RISE_RATE * dt, self._target))
    elseif self._target < percent then
        self:SetPercent(math.max(percent - FALL_RATE * dt, self._target))
    end

    self:DriveHeight()

    -- 降落完成：高度归零后关闭飞行状态（net_flying 同步 false）
    if self._target <= 0 and self:GetFlyTargetHeight() <= 0 then
        self:FinishLand()
    end
end

------------------------------------------------------------------------

function ArkFlyer:TakeOff()
    if self.flying then return end
    self.flying  = true
    self._target = 1

    local inst = self.inst
    inst:AddTag("flying")
    ApplyFlyingPhysics(inst)

    -- drownable 处理
    if inst.components.drownable then
        if TheWorld:HasTag("cave") then
            inst:RemoveComponent("drownable")
        else
            inst.components.drownable.enabled = false
        end
    end

    if inst.DynamicShadow then
        inst.DynamicShadow:Enable(false)
    end

    -- 先同步飞行状态再播事件，客户端 hook 立即判定飞行
    self:SetNetFlying(true)
    inst:StartUpdatingComponent(self)
    inst:PushEvent("ark_takeoff")
end

-- 降落：恢复地面物理，高度由 OnUpdate 渐降到 0 后关闭飞行
function ArkFlyer:Land()
    if not self.flying then return end
    self._target = 0

    local inst = self.inst
    RestoreGroundPhysics(inst)
    inst:RemoveTag("flying")

    -- drownable 恢复
    if TheWorld:HasTag("cave") then
        if not inst.components.drownable then
            inst:AddComponent("drownable")
        end
    elseif inst.components.drownable then
        inst.components.drownable.enabled = true
    end

    if inst.DynamicShadow then
        inst.DynamicShadow:Enable(true)
    end
end

function ArkFlyer:FinishLand()
    self.flying = false
    self:SetNetFlying(false)
    -- 落地事件：hook 播放降落退出动画
    self.inst:PushEvent("ark_land")
end

function ArkFlyer:SetNetFlying(v)
    local r = GetReplica(self.inst)
    if r then r.net_flying:set(v) end
end

function ArkFlyer:IsFlying()
    return self.flying
end

function ArkFlyer:Toggle()
    if self.flying then self:Land() else self:TakeOff() end
end

------------------------------------------------------------------------
-- 持久化

function ArkFlyer:OnSave()
    return { flying = self.flying }
end

function ArkFlyer:OnLoad(data)
    if data and data.flying then
        self:TakeOff()
        -- 读档直接满高度
        self._target = 1
        self:SetPercent(1)
        self:DriveHeight()
    end
end

------------------------------------------------------------------------

return ArkFlyer
