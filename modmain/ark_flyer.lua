-------------------------------------------------------------------
-- ark_flyer 飞行动画 stategraph 钩子
-- 启用飞行后角色常态浮空，起飞/降落分别播放过渡动画
-------------------------------------------------------------------

local function IsFlying(inst)
    return inst.components.ark_flyer ~= nil
        and inst.components.ark_flyer:IsFlying()
end

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
        local orig = state.onenter
        state.onenter = function(inst, ...)
            if orig then orig(inst, ...) end
            onenter_fn(inst, ...)
        end
    end

    if onexit_fn then
        local orig = state.onexit
        state.onexit = function(inst, ...)
            onexit_fn(inst, ...)
            if orig then orig(inst, ...) end
        end
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
        inst.AnimState:PlayAnimation("ark_fly_pre")
        inst.AnimState:PushAnimation("ark_fly_loop", true)
    end))

    -- 全局事件：降落，播放退出动画；若正在 run 则重置状态以立即落地
    table.insert(sg.events, EventHandler("ark_land", function(inst)
        local cur = inst.sg.currentstate and inst.sg.currentstate.name
        if cur == "run" or cur == "run_start" or cur == "run_stop" then
            inst.sg:GoToState(cur)
            return
        end
        inst.AnimState:PlayAnimation("ark_fly_pst")
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

    -- idle：飞行时始终浮空（读档恢复时也保证 fly_loop）
    HookState(sg, "idle",
        function(inst)
            if not IsActiveFlyer(inst) then return end
            if not inst.AnimState:IsCurrentAnimation("ark_fly_loop") then
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