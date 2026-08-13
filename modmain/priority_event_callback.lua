-- priority_event_callback.lua
-- 竞争事件监听：同一 (source, event, group) 内，按 priority 选最高者执行，fn 返回 false 则顺延。
--
-- API（EntityScript 方法，成对使用，不做原版 monkeypatch）：
--   inst:PriorityListenForEvent(event, fn, source, options)
--   inst:PriorityRemoveEventCallback(event, fn, source)
--
-- options = { priority = 0, group = "default" }
--
-- 契约：
--   * fn(inst, data) 返回 false  → 放弃本次事件，顺延给优先级次高者
--   * fn(inst, data) 返回其他值  → 认领，停止遍历（返回 nil 也算认领）
--   * 同 priority 时先注册者优先
--   * 开发者应成对使用注册/移除；移除时传注册时的原始 fn 与 source 即可（内部按注册时的 group 精确匹配）
--
-- 内存注意：
--   * 注册路径完全复用 vanilla EntityScript:ListenForEvent 的监听挂接，event_listeners / event_listening
--     两表由 vanilla 维护，RemoveEventCallback / RemoveAllEventCallbacks 天然对称清理 boundfn
--   * 仲裁索引表 _event_listeners 以 source 为弱键，source 生命周期结束即被回收
--   * 若 source 是长生命周期对象（如 TheWorld / _G），开发者在不再需要时必须成对调用 Remove

local _event_listeners = setmetatable({}, { __mode = "k" }) -- [source][event][group][fn] = binding

local _source_order = 0

local function _GetGroupListeners(source, event, group)
    local source_listeners = _event_listeners[source]
    if source_listeners == nil then
        source_listeners = {}
        _event_listeners[source] = source_listeners
    end

    local event_listeners = source_listeners[event]
    if event_listeners == nil then
        event_listeners = {}
        source_listeners[event] = event_listeners
    end

    local group_listeners = event_listeners[group]
    if group_listeners == nil then
        group_listeners = {}
        event_listeners[group] = group_listeners
    end

    return group_listeners
end

local function _RemoveGroupListener(source, event, group, fn)
    local source_listeners = _event_listeners[source]
    if source_listeners == nil then
        return
    end

    local event_listeners = source_listeners[event]
    if event_listeners == nil then
        return
    end

    local group_listeners = event_listeners[group]
    if group_listeners == nil then
        return
    end

    group_listeners[fn] = nil

    if next(group_listeners) == nil then
        event_listeners[group] = nil
    end
    if next(event_listeners) == nil then
        source_listeners[event] = nil
    end
    if next(source_listeners) == nil then
        _event_listeners[source] = nil
    end
end

local function _IsBoundStillRegistered(source, event, group, binding)
    local source_listeners = _event_listeners[source]
    if source_listeners == nil then
        return false
    end
    local event_listeners = source_listeners[event]
    if event_listeners == nil then
        return false
    end
    local group_listeners = event_listeners[group]
    if group_listeners == nil then
        return false
    end
    return group_listeners[binding.fn] == binding
end

-- 组内仲裁：按 priority 降序（同 priority 先注册优先）调用，fn 返回 false 顺延，其他值认领并停止。
-- group_listeners._active 防止同组多个 boundfn 触发时重复仲裁（第二次调用直接返回）。
local function _Dispatch(source, event, group, inst, data)
    local source_listeners = _event_listeners[source]
    if source_listeners == nil then
        return
    end
    local event_listeners = source_listeners[event]
    if event_listeners == nil then
        return
    end
    local group_listeners = event_listeners[group]
    if group_listeners == nil then
        return
    end

    if group_listeners._active then
        return
    end
    group_listeners._active = true

    local ordered = {}
    for fn, binding in pairs(group_listeners) do
        if fn ~= "_active" and _IsBoundStillRegistered(source, event, group, binding) then
            ordered[#ordered + 1] = binding
        end
    end

    table.sort(ordered, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.order < b.order
    end)

    for i = 1, #ordered do
        local binding = ordered[i]
        local result = binding.fn(inst, data)
        if result ~= false then
            break
        end
    end

    group_listeners._active = nil
end

function EntityScript:PriorityListenForEvent(event, fn, source, options)
    source = source or self

    options = options or {}
    local priority = options.priority or 0
    local group = options.group or "default"

    local group_listeners = _GetGroupListeners(source, event, group)
    if group_listeners[fn] ~= nil then
        return -- 已注册，不重复挂接
    end

    _source_order = _source_order + 1

    local binding =
    {
        fn = fn,
        priority = priority,
        order = _source_order,
    }

    -- 复用 vanilla 监听注册：boundfn 挂在 source 上，listener 是 self。
    -- event_listeners / event_listening 两表都由 vanilla 维护，RemoveEventCallback 时对称清理。
    binding.boundfn = function(inst, data)
        _Dispatch(source, event, group, inst, data)
    end

    group_listeners[fn] = binding
    self:ListenForEvent(event, binding.boundfn, source)
end

function EntityScript:PriorityRemoveEventCallback(event, fn, source)
    source = source or self

    local source_listeners = _event_listeners[source]
    if source_listeners == nil then
        return
    end
    local event_listeners = source_listeners[event]
    if event_listeners == nil then
        return
    end

    -- 跨 group 精确匹配：fn 是原始函数，binding 记录其注册时的 group，取出 boundfn 后从 vanilla 移除
    for group, group_listeners in pairs(event_listeners) do
        local binding = group_listeners[fn]
        if binding ~= nil then
            self:RemoveEventCallback(event, binding.boundfn, source)
            _RemoveGroupListener(source, event, group, fn)
            return
        end
    end
end
