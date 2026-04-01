local _OldListenForEvent = EntityScript.ListenForEvent
local _OldRemoveEventCallback = EntityScript.RemoveEventCallback

local _priority_meta = setmetatable({}, { __mode = "k" })
local _priority_bindings = setmetatable({}, { __mode = "k" })
local _priority_competitors = setmetatable({}, { __mode = "k" })

local _priority_order = 0

local function _GetSourceBindings(source)
    local source_bindings = _priority_bindings[source]
    if source_bindings == nil then
        source_bindings = {}
        _priority_bindings[source] = source_bindings
    end
    return source_bindings
end

local function _GetEventBindings(source, event)
    local source_bindings = _GetSourceBindings(source)
    local event_bindings = source_bindings[event]
    if event_bindings == nil then
        event_bindings = {}
        source_bindings[event] = event_bindings
    end
    return event_bindings
end

local function _GetSourceCompetitors(source)
    local source_competitors = _priority_competitors[source]
    if source_competitors == nil then
        source_competitors = {}
        _priority_competitors[source] = source_competitors
    end
    return source_competitors
end

local function _GetGroupCompetitors(source, event, group)
    local source_competitors = _GetSourceCompetitors(source)

    local event_competitors = source_competitors[event]
    if event_competitors == nil then
        event_competitors = {}
        source_competitors[event] = event_competitors
    end

    local group_competitors = event_competitors[group]
    if group_competitors == nil then
        group_competitors = {}
        event_competitors[group] = group_competitors
    end

    return group_competitors
end

local function _ArrayRemoveValue(array, value)
    for i = #array, 1, -1 do
        if array[i] == value then
            table.remove(array, i)
            return true
        end
    end
    return false
end

local function _IsBoundWrapperStillRegistered(binding)
    local source = binding.source
    local listener = binding.listener

    if source == nil or listener == nil then
        return false
    end

    local listeners = source.event_listeners
    if listeners == nil then
        return false
    end

    listeners = listeners[binding.event]
    if listeners == nil then
        return false
    end

    local fns = listeners[listener]
    if fns == nil then
        return false
    end

    for i = 1, #fns do
        if fns[i] == binding.boundfn then
            return true
        end
    end

    return false
end

local function _PruneCompetitors(group_competitors)
    for i = #group_competitors, 1, -1 do
        if not _IsBoundWrapperStillRegistered(group_competitors[i]) then
            table.remove(group_competitors, i)
        end
    end
end

local function _GetBestBinding(source, event, group)
    local source_competitors = _priority_competitors[source]
    if source_competitors == nil then
        return nil
    end

    local event_competitors = source_competitors[event]
    if event_competitors == nil then
        return nil
    end

    local group_competitors = event_competitors[group]
    if group_competitors == nil then
        return nil
    end

    _PruneCompetitors(group_competitors)

    local best = nil
    for i = 1, #group_competitors do
        local binding = group_competitors[i]
        if best == nil
            or binding.priority > best.priority
            or (binding.priority == best.priority and binding.order < best.order) then
            best = binding
        end
    end

    return best
end

local function _RegisterPriorityBinding(binding)
    local event_bindings = _GetEventBindings(binding.source, binding.event)

    local listener_bindings = event_bindings[binding.listener]
    if listener_bindings == nil then
        listener_bindings = setmetatable({}, { __mode = "k" })
        event_bindings[binding.listener] = listener_bindings
    end

    listener_bindings[binding.markerfn] = binding

    local group_competitors = _GetGroupCompetitors(binding.source, binding.event, binding.group)
    group_competitors[#group_competitors + 1] = binding
end

local function _UnregisterPriorityBinding(binding)
    local source_bindings = _priority_bindings[binding.source]
    if source_bindings ~= nil then
        local event_bindings = source_bindings[binding.event]
        if event_bindings ~= nil then
            local listener_bindings = event_bindings[binding.listener]
            if listener_bindings ~= nil then
                listener_bindings[binding.markerfn] = nil
                if next(listener_bindings) == nil then
                    event_bindings[binding.listener] = nil
                end
            end

            if next(event_bindings) == nil then
                source_bindings[binding.event] = nil
            end
        end

        if next(source_bindings) == nil then
            _priority_bindings[binding.source] = nil
        end
    end

    local source_competitors = _priority_competitors[binding.source]
    if source_competitors ~= nil then
        local event_competitors = source_competitors[binding.event]
        if event_competitors ~= nil then
            local group_competitors = event_competitors[binding.group]
            if group_competitors ~= nil then
                _ArrayRemoveValue(group_competitors, binding)
                if #group_competitors == 0 then
                    event_competitors[binding.group] = nil
                end
            end

            if next(event_competitors) == nil then
                source_competitors[binding.event] = nil
            end
        end

        if next(source_competitors) == nil then
            _priority_competitors[binding.source] = nil
        end
    end
end

local function _FindPriorityBinding(listener, source, event, markerfn)
    local source_bindings = _priority_bindings[source]
    if source_bindings == nil then
        return nil
    end

    local event_bindings = source_bindings[event]
    if event_bindings == nil then
        return nil
    end

    local listener_bindings = event_bindings[listener]
    if listener_bindings == nil then
        return nil
    end

    return listener_bindings[markerfn]
end

function GLOBAL.PriorityEventCallback(fn, options)
    assert(type(fn) == "function", "PriorityEventCallback expects a function")

    local markerfn = function(...)
        return fn(...)
    end

    options = options or {}

    _priority_meta[markerfn] =
    {
        rawfn = fn,
        priority = options.priority or 0,
        group = options.group or "default",
    }

    return markerfn
end

function EntityScript:ListenForEvent(event, fn, source)
    local meta = _priority_meta[fn]
    if meta == nil then
        return _OldListenForEvent(self, event, fn, source)
    end

    source = source or self

    local existing = _FindPriorityBinding(self, source, event, fn)
    if existing ~= nil then
        return
    end

    _priority_order = _priority_order + 1

    local binding =
    {
        listener = self,
        source = source,
        event = event,
        markerfn = fn,
        priority = meta.priority,
        group = meta.group,
        order = _priority_order,
    }

    binding.boundfn = function(inst, data)
        local best = _GetBestBinding(binding.source, binding.event, binding.group)
        if best ~= binding then
            return
        end
        return meta.rawfn(inst, data)
    end
    _RegisterPriorityBinding(binding)

    return _OldListenForEvent(self, event, binding.boundfn, source)
end

function EntityScript:RemoveEventCallback(event, fn, source)
    local meta = _priority_meta[fn]
    if meta == nil then
        return _OldRemoveEventCallback(self, event, fn, source)
    end

    source = source or self

    local binding = _FindPriorityBinding(self, source, event, fn)
    if binding == nil then
        return
    end

    _UnregisterPriorityBinding(binding)
    return _OldRemoveEventCallback(self, event, binding.boundfn, source)
end
