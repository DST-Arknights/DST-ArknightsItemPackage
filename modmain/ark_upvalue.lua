
local GLOBAL = rawget(_G, "GLOBAL") or _G

local REPLACED_FUNCTION_CHAIN = setmetatable({}, { __mode = "k" })

local function NormalizeOptions(opts)
    opts = opts or {}

    return {
        maxdepth = opts.maxdepth or 5,
        file = opts.file,
    }
end

local function GetSource(fn)
    local info = debug.getinfo(fn, "S")
    return info and info.source or ""
end

local function MatchFile(fn, file)
    return not file or GetSource(fn):match(file) ~= nil
end

local function LinkReplacedFunction(newfn, oldfn)
    if type(newfn) ~= "function" or type(oldfn) ~= "function" or newfn == oldfn then
        return
    end

    local chain = REPLACED_FUNCTION_CHAIN[newfn]
    if chain == nil then
        REPLACED_FUNCTION_CHAIN[newfn] = { oldfn }
        return
    end

    for _, previous in ipairs(chain) do
        if previous == oldfn then
            return
        end
    end

    chain[#chain + 1] = oldfn
end

local function CreateSlot(owner, index, upname, depth)
    local slot = {
        owner = owner,
        index = index,
        name = upname,
        depth = depth,
        source = GetSource(owner),
    }

    function slot:Get()
        local _, value = debug.getupvalue(self.owner, self.index)
        self.value = value
        return value
    end

    function slot:Set(newvalue)
        local oldvalue = self:Get()

        if type(newvalue) == "function" then
            LinkReplacedFunction(newvalue, oldvalue)
        end

        debug.setupvalue(self.owner, self.index, newvalue)
        self.value = newvalue

        return oldvalue, newvalue
    end

    function slot:Replace(replacer)
        if type(replacer) ~= "function" then
            return nil, nil, "replacer must be a function"
        end

        local oldvalue = self:Get()
        local newvalue = replacer(oldvalue, self)
        local previous, current = self:Set(newvalue)
        return previous, current
    end

    slot.value = slot:Get()
    return slot
end

local function Find(fn, name, opts, state)
    if type(fn) ~= "function" or type(name) ~= "string" then
        return nil
    end

    if state == nil then
        state = {
            depth = 0,
            visited = {},
            opts = NormalizeOptions(opts),
        }
    end

    if state.visited[fn] then
        return nil
    end
    state.visited[fn] = true

    local i = 1
    while true do
        local upname, upvalue = debug.getupvalue(fn, i)
        if not upname then
            break
        end

        if upname == name and MatchFile(fn, state.opts.file) then
            return CreateSlot(fn, i, upname, state.depth)
        end

        if state.depth < state.opts.maxdepth and type(upvalue) == "function" then
            local found = Find(upvalue, name, nil, {
                depth = state.depth + 1,
                visited = state.visited,
                opts = state.opts,
            })
            if found then
                return found
            end
        end

        i = i + 1
    end

    if state.depth < state.opts.maxdepth then
        local chain = REPLACED_FUNCTION_CHAIN[fn]
        if chain then
            for _, previous in ipairs(chain) do
                local found = Find(previous, name, nil, {
                    depth = state.depth + 1,
                    visited = state.visited,
                    opts = state.opts,
                })
                if found then
                    return found
                end
            end
        end
    end

    return nil
end

local function Get(fn, name, opts)
    local slot = Find(fn, name, opts)
    if not slot then
        return false
    end

    return true, slot:Get(), slot
end

local function Set(fn, name, value, opts)
    local slot = Find(fn, name, opts)
    if not slot then
        return false
    end

    local oldvalue, newvalue = slot:Set(value)
    return true, oldvalue, newvalue, slot
end

local function Replace(fn, name, replacer, opts)
    local slot = Find(fn, name, opts)
    if not slot then
        return false
    end

    local oldvalue, newvalue, err = slot:Replace(replacer)
    if err then
        return false, err
    end

    return true, oldvalue, newvalue, slot
end

GLOBAL.ArkFindUpvalue = Find
GLOBAL.ArkGetUpvalue = Get
GLOBAL.ArkSetUpvalue = Set
GLOBAL.ArkReplaceUpvalue = Replace
GLOBAL.ArkUpdateUpvalue = Replace
