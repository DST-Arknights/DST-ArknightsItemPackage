-------------------------------------------------------------------
-- ark_flyer 组件副本 (replica)
--
-- 网络变量唯一安装点：net_flying / net_percent。
-- 主机端 AddComponent 时同样会创建 replica（ReplicateComponent），
-- 因此组件不重复定义网络变量，直接通过 inst.replica.ark_flyer 读写。
-------------------------------------------------------------------

local ArkFlyerReplica = Class(function(self, inst)
    self.inst = inst

    -- 飞行状态开关；net_percent 为 0~1 的目标高度，高度 = FLY_HEIGHT * percent
    self.net_flying  = net_bool(inst.GUID, "ark_flyer_flying",  "ark_flyer_flying_dirty")
    self.net_percent = net_float(inst.GUID, "ark_flyer_percent", "ark_flyer_percent_dirty")
end)

function ArkFlyerReplica:IsFlying()
    return self.net_flying:value()
end

function ArkFlyerReplica:GetPercent()
    return self.net_percent:value()
end

return ArkFlyerReplica
