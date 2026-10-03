-------------------------------------------------------------------
-- ark_flyer 飞行辅助
--  - 飞行动画 stategraph 钩子
--  - locomotor.RunForward 后维持飞行高度（移动会覆盖垂直马达速度）
-------------------------------------------------------------------

local function IsFlying(inst)
    -- 从 replica 判断：启用预测补偿后客户端读不到服务端组件。
    -- 副本先于组件加载，但普通角色没有该组件，故保留 nil 保护。
    local replica = inst.replica and inst.replica.ark_flyer
    return replica ~= nil and replica:IsFlying()
end

-- 冰面滑倒由 slipperyfeet 累积滑倒值触发，与物理碰撞无关。
-- 飞行时通过原接口清零，避免触发 feetslipped 或把累积值带到落地后。
AddComponentPostInit("slipperyfeet", function(cmp)
    ArkHookFunction(cmp, "SetCurrent", function(next, self, value)
        if IsFlying(self.inst) then
            value = 0
        end
        return next(self, value)
    end)
end)

-- 有网络变量（replica：net_flying/net_percent）的组件必须在实体创建时就装好，
-- 否则引擎的副本同步会出问题（客户端 replica 依据服务端同步的 tag 建立）。
-- 故所有玩家在 postInit 后即内置 ark_flyer 组件。
AddPlayerPostInit(function(inst)
    if TheWorld.ismastersim and not inst.components.ark_flyer then
        inst:AddComponent("ark_flyer")
    end

    -- 原生 run_start/run 状态的时间线会调用 PlayFootstep。
    -- 飞行时直接拦截默认脚步音，结束飞行后仍恢复原处理逻辑。
    local old_footstepoverridefn = inst.footstepoverridefn
    if old_footstepoverridefn ~= nil then
        inst.footstepoverridefn = function(volume, ispredicted)
            if IsFlying(inst) then
                return true
            end
            return old_footstepoverridefn(volume, ispredicted)
        end
    end
end)

local function RefreshClientFlyer(inst)
    local replica = inst.replica and inst.replica.ark_flyer
    if replica ~= nil then
        replica:RefreshClientUpdate()
    end
end

-- 移动会重新设置 SetMotorVel，垂直分量被覆盖导致高度掉落。
-- 飞行中的角色在 RunForward 后再次调用 DriveHeight 维持高度（参考伊蕾娜模组）。
AddComponentPostInit("locomotor", function(cmp)
    local RunForward = cmp.RunForward
    cmp.RunForward = function(self, ...)
        RunForward(self, ...)
        local flyer = self.inst.components and self.inst.components.ark_flyer
        if flyer and flyer:IsFlying() then
            flyer:DriveHeight()
        else
            local replica = self.inst.replica and self.inst.replica.ark_flyer
            if replica and replica:IsFlying() then
                replica:DriveHeight()
            end
        end
    end

    if not TheWorld.ismastersim then
        -- 预测开启时 locomotor 是动态创建的；此时服务端可能已经在飞行。
        cmp.inst:DoTaskInTime(0, RefreshClientFlyer)
    end
end)

local function IsActiveFlyer(inst)
    return IsFlying(inst)
        and not inst.sg.statemem.riding
        and not inst.sg.statemem.heavy
end

------------------------------------------------------------------------

local function HookState(sg, state_name, onenter_fn, onexit_fn)
    local state = sg.states[state_name]
    if not state then return end

    if onenter_fn then
        ArkHookFunction(state, "onenter", function(next, inst, ...)
            next(inst, ...)
            -- 原状态可能在 onenter 内跳转，不能再覆盖新状态的动画。
            if inst.sg.currentstate == state then
                onenter_fn(inst, ...)
            end
        end)
    end

    if onexit_fn then
        ArkHookFunction(state, "onexit", function(next, inst, ...)
            onexit_fn(inst, ...)
            return next(inst, ...)
        end)
    end
end

------------------------------------------------------------------------

local function ApplyHooks(sg)
    -- 全局事件：起飞，播放入场动画后循环浮空；若正在 run 则重置状态
    table.insert(sg.events, EventHandler("ark_takeoff", function(inst)
        local cur = inst.sg.currentstate and inst.sg.currentstate.name
        if cur == "run" or cur == "run_start" or cur == "run_stop" then
            inst.sg:GoToState(cur)
            return
        end
        inst.AnimState:PlayAnimation("ark_fly_loop", true)
    end))

    -- 全局事件：降落，播放退出动画；若正在 run 则重置状态以立即落地
    table.insert(sg.events, EventHandler("ark_land", function(inst)
        local cur = inst.sg.currentstate and inst.sg.currentstate.name
        if cur == "run" or cur == "run_start" or cur == "run_stop" then
            inst.sg:GoToState(cur)
            return
        end
        inst.AnimState:PlayAnimation("ark_fly_loop", true)
    end))

    -- run_start：飞行时保持浮空循环
    HookState(sg, "run_start",
        function(inst)
            if not IsActiveFlyer(inst) then return end
            if not inst.AnimState:IsCurrentAnimation("ark_fly_loop") then
                inst.AnimState:PlayAnimation("ark_fly_loop", true)
            end
        end,
        nil
    )

    -- run：飞行时保持浮空循环，刷新 timeout
    HookState(sg, "run",
        function(inst)
            if not IsActiveFlyer(inst) then return end
            if not inst.AnimState:IsCurrentAnimation("ark_fly_loop") then
                inst.AnimState:PlayAnimation("ark_fly_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,
        nil
    )

    -- run_stop：飞行时保持浮空循环，不落地
    HookState(sg, "run_stop",
        function(inst)
            if not IsActiveFlyer(inst) then return end
            if not inst.AnimState:IsCurrentAnimation("ark_fly_loop") then
                inst.AnimState:PlayAnimation("ark_fly_loop", true)
            end
        end,
        nil
    )

    -- idle：只替换真正的待机动画，保留预测动作交接和动作收尾。
    HookState(sg, "idle",
        function(inst, pushanim)
            if not IsActiveFlyer(inst) then return end
            -- 客户端 noanim 表示预览已被服务端确认；cancel/nopredict/pausepredict
            -- 表示预测被服务端打断。这些分支必须继续由服务端接管动画。
            if not TheWorld.ismastersim and
                (pushanim == "noanim" or pushanim == "cancel"
                    or inst:HasTag("nopredict") or inst:HasTag("pausepredict")) then
                return
            end
            if pushanim then
                -- idle(true) 要把循环接在 pickup_pst 等收尾动画之后。
                inst.AnimState:PushAnimation("ark_fly_loop", true)
            elseif not inst.AnimState:IsCurrentAnimation("ark_fly_loop") then
                inst.AnimState:PlayAnimation("ark_fly_loop", true)
            end
        end,
        nil
    )

    -- funnyidle：飞行时跳过
    HookState(sg, "funnyidle",
        function(inst)
            if IsActiveFlyer(inst) then
                inst.sg:GoToState("idle")
            end
        end,
        nil
    )
end

------------------------------------------------------------------------

AddStategraphPostInit("wilson",        ApplyHooks)
AddStategraphPostInit("wilson_client", ApplyHooks)
