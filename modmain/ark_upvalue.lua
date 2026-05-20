
-- 获取指定 upvalue
local function Get(fn, name, opts)
    if type(fn) ~= "function" then return false end

    opts = opts or {}
    local maxlevel = opts.maxlevel or 5
    local maxup = opts.max or 20
    local level = opts.level or 0
    local file = opts.file
    local visited = opts.visited or {}

    if visited[fn] then return false end
    visited[fn] = true

    for i = 1, maxup do
        local upname, upvalue = debug.getupvalue(fn, i)
        if not upname then break end

        if upname == name then
            if not file or (debug.getinfo(fn).source or ""):match(file) then
                return true, upvalue
            end
        end

        if level < maxlevel and type(upvalue) == "function" then
            local found, value = Get(upvalue, name, {
                maxlevel = maxlevel,
                max = maxup,
                level = level + 1,
                file = file,
                visited = visited
            })
            if found then return true, value end
        end
    end

    return false
end

-- 设置指定 upvalue
local function Set(fn, name, value, opts)
    if type(fn) ~= "function" then return false end

    opts = opts or {}
    local maxlevel = opts.maxlevel or 5
    local maxup = opts.max or 20
    local level = opts.level or 0
    local file = opts.file
    local visited = opts.visited or {}

    if visited[fn] then return false end
    visited[fn] = true

    for i = 1, maxup do
        local upname, upvalue = debug.getupvalue(fn, i)
        if not upname then break end

        if upname == name then
            if not file or (debug.getinfo(fn).source or ""):match(file) then
                return debug.setupvalue(fn, i, value)
            end
        end

        if level < maxlevel and type(upvalue) == "function" then
            local success = Set(upvalue, name, value, {
                maxlevel = maxlevel,
                max = maxup,
                level = level + 1,
                file = file,
                visited = visited
            })
            if success then return success end
        end
    end

    return false
end

GLOBAL.ArkGetUpvalue = Get
GLOBAL.ArkSetUpvalue = Set
