local HotKeyManager = {
    instances = {},         -- [player] = manager
    persistentData = {}     -- [userid] = { [name] = hotkey }
}

local PERSISTENT_KEY_PREFIX = "ark_hotkey_"

-- 浅拷贝工具函数
local function shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

local function getUserId(player)
    return player.userid or "local_player"
end

local function getPersistentKey(player)
    return PERSISTENT_KEY_PREFIX .. getUserId(player)
end

local function serializeData(data)
    local lines = { "return {" }
    for name, hotkey in pairs(data) do
        if hotkey ~= nil then
            local serializedHotkey = type(hotkey) == "string" and string.format("%q", hotkey) or tostring(hotkey)
            lines[#lines + 1] = string.format("[%q]=%s,", tostring(name), serializedHotkey)
        end
    end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

local function deserializeData(raw)
    if raw == nil or raw == "" then
        return {}
    end

    local loader = loadstring(raw)
    if type(loader) ~= "function" then
        return {}
    end

    local ok, data = pcall(loader)
    if not ok or type(data) ~= "table" then
        return {}
    end

    local result = {}
    for name, hotkey in pairs(data) do
        if type(name) == "string" and (type(hotkey) == "number" or type(hotkey) == "string") then
            result[name] = hotkey
        end
    end
    return result
end

function HotKeyManager.Get(player)
    if not player then return end
    
    if not HotKeyManager.instances[player] then
        HotKeyManager.instances[player] = HotKeyManager._Create(player)
    end
    return HotKeyManager.instances[player]
end

function HotKeyManager._Create(player)
    local manager = {
        player = player,
        registry = {},      -- { [name] = {hotkey=key, handler=func} }
        hooksInstalled = false,
        controlHandler = nil,  -- 事件处理器引用，用于移除
        tempListeners = {}, -- 临时监听器数组 { callback = function }
        loaded = false,
        loading = false,
        pendingHotkeys = {},
    }
    
    -- 获取热键对应的handler数量
    function manager:GetHotkeyHandlerCount(key)
        if not key then return 0 end
        
        local count = 0
        for _, info in pairs(self.registry) do
            if info.hotkey == key then
                count = count + 1
            end
        end
        return count
    end

    -- 加载持久化数据
    local function loadData()
        local userid = getUserId(player)
        return HotKeyManager.persistentData[userid] or {}
    end
    
    -- 保存数据
    local function saveData(data)
        local userid = getUserId(player)
        HotKeyManager.persistentData[userid] = shallowCopy(data)
        TheSim:SetPersistentString(getPersistentKey(player), serializeData(data), false)
    end

    function manager:_ApplyLoadedData()
        local data = loadData()
        local changed = false

        for name, hotkey in pairs(self.pendingHotkeys) do
            data[name] = hotkey
            changed = true
        end
        self.pendingHotkeys = {}

        for name, info in pairs(self.registry) do
            local hotkey = data[name]
            if hotkey == nil and info.defaultHotkey ~= nil then
                hotkey = info.defaultHotkey
                data[name] = hotkey
                changed = true
            end
            info.hotkey = hotkey
        end

        if changed then
            saveData(data)
        end
    end

    function manager:_EnsureLoaded()
        if self.loaded or self.loading then
            return
        end

        self.loading = true
        TheSim:GetPersistentString(getPersistentKey(player), function(success, raw)
            local userid = getUserId(player)
            HotKeyManager.persistentData[userid] = success and deserializeData(raw) or {}
            self.loading = false
            self.loaded = true
            self:_ApplyLoadedData()
        end)
    end
    
    -- 获取当前热键
    function manager:GetHotkey(name)
        self:_EnsureLoaded()
        if not self.loaded then
            local pendingHotkey = self.pendingHotkeys[name]
            if pendingHotkey ~= nil then
                return pendingHotkey
            end
            return self.registry[name] and self.registry[name].hotkey or nil
        end
        local data = loadData()
        return data[name]
    end
    
    -- 设置热键
    function manager:SetHotkey(name, hotkey)
        self:_EnsureLoaded()
        if not self.loaded then
            self.pendingHotkeys[name] = hotkey
            if self.registry[name] then
                self.registry[name].hotkey = hotkey
            end
            return
        end

        local data = loadData()
        data[name] = hotkey
        saveData(data)
        
        -- 更新registry中的hotkey
        if self.registry[name] then
            self.registry[name].hotkey = hotkey
        end
    end
    
    -- 恢复默认热键
    function manager:RestoreDefaultHotkey(name)
        local info = self.registry[name]
        if info and info.defaultHotkey then
            self:SetHotkey(name, info.defaultHotkey)
        end
    end

    -- 注册热键处理器
    function manager:Register(name, handler, defaultHotkey)
        self.registry[name] = {
            hotkey = defaultHotkey,
            handler = handler,
            defaultHotkey = defaultHotkey,  -- 保存默认值
        }

        self:_EnsureLoaded()
        if self.loaded then
            local hotkey = self:GetHotkey(name)
            if hotkey == nil and defaultHotkey ~= nil then
                hotkey = defaultHotkey
                self:SetHotkey(name, hotkey)
            else
                self.registry[name].hotkey = hotkey
            end
        end

        self:_installHook()
    end
    
    -- 注销热键
    function manager:Unregister(name)
        self.registry[name] = nil
    end
    
    -- 一次性按键监听器（回调返回true时自动移除）
    function manager:ListenOnce(callback)
        local listener = { callback = callback }
        table.insert(self.tempListeners, listener)
    end

    -- 取消一次性监听器
    function manager:CancelListenOnce(callback)
        for i, v in ipairs(self.tempListeners) do
            if v.callback == callback then
                table.remove(self.tempListeners, i)
                break
            end
        end
    end
    
    -- 安装控制事件监听器
    function manager:_installHook()
        if self.hooksInstalled then return end

        self.hooksInstalled = true

        -- 使用 oncontrol 事件处理器
        local function onKeyHandler(key, down)
            if IsPaused() then
                return
            end
            local isenabled, ishudblocking = ThePlayer and ThePlayer.components.playercontroller:IsEnabled() or false, false
            if not isenabled and not ishudblocking then
                return
            end
            -- 1. 优先处理一次性监听器（回调返回true时移除）
            if #self.tempListeners > 0 then
                local listener = self.tempListeners[1]
                local ok, shouldRemove = pcall(listener.callback, key, down)
                if ok and shouldRemove then
                    table.remove(self.tempListeners, 1)
                end
                return
            end

            -- 2. 常规热键处理（允许同一个按键触发多个handler）
            if down then
                for name, info in pairs(self.registry) do
                    if info.hotkey == key then
                        pcall(info.handler, name, key)
                    end
                end
            end
        end

        self.controlHandler = TheInput.onkey:AddEventHandler("onkey", onKeyHandler)
    end

    -- 卸载控制事件监听器
    function manager:_uninstallHook()
        if not self.hooksInstalled then return end

        if self.controlHandler then
            self.controlHandler:Remove()
            self.controlHandler = nil
        end
        self.hooksInstalled = false
    end

    manager:_EnsureLoaded()
    return manager
end

GLOBAL.GetHotKeyManager = HotKeyManager.Get
return HotKeyManager
