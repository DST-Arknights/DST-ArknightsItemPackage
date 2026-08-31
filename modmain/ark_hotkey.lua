local HotKeyManager = {
    instances = setmetatable({}, { __mode = "k" }),
    persistentData = {},
}

local Manager = {}
Manager.__index = Manager

local PERSISTENT_KEY_PREFIX = "ark_hotkey_"

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
            lines[#lines + 1] = string.format("[%q]=%s,", name, serializedHotkey)
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
    if loader == nil then
        return {}
    end

    local ok, data = pcall(loader)
    return ok and data or {}
end

local function createManager(player)
    local userid = getUserId(player)
    local manager = setmetatable({
        player = player,
        userid = userid,
        registry = {},
        data = HotKeyManager.persistentData[userid] or {},
        tempListeners = {},
        controlHandler = nil,
        loaded = false,
        changedBeforeLoad = {},
        saveAfterLoad = false,
    }, Manager)

    HotKeyManager.persistentData[userid] = manager.data
    return manager
end

function HotKeyManager.Get(player)
    if player == nil then
        return nil
    end

    local manager = HotKeyManager.instances[player]
    if manager == nil then
        manager = createManager(player)
        HotKeyManager.instances[player] = manager
        manager:_Initialize()
    end
    return manager
end

function Manager:_Initialize()
    self:_InstallHook()
    self:_LoadPersistentData()
end

function Manager:_Save()
    HotKeyManager.persistentData[self.userid] = self.data
    TheSim:SetPersistentString(getPersistentKey(self.player), serializeData(self.data), false)
end

function Manager:_ApplyDataToRegistry()
    local changed = false

    for name, info in pairs(self.registry) do
        if self.data[name] == nil and info.defaultHotkey ~= nil then
            self.data[name] = info.defaultHotkey
            changed = true
        end
        info.hotkey = self.data[name]
    end

    return changed
end

function Manager:_LoadPersistentData()
    TheSim:GetPersistentString(getPersistentKey(self.player), function(success, raw)
        local loadedData = success and deserializeData(raw) or {}

        for name, hotkey in pairs(loadedData) do
            if not self.changedBeforeLoad[name] then
                self.data[name] = hotkey
            end
        end

        self.loaded = true
        local wroteDefaults = self:_ApplyDataToRegistry()
        local hasLocalChanges = next(self.changedBeforeLoad) ~= nil
        local shouldSave = self.saveAfterLoad or wroteDefaults or hasLocalChanges

        self.changedBeforeLoad = nil
        self.saveAfterLoad = false

        if shouldSave then
            self:_Save()
        end
    end)
end

function Manager:GetHotkeyHandlerCount(key)
    if key == nil then
        return 0
    end

    local count = 0
    for _, info in pairs(self.registry) do
        if info.hotkey == key then
            count = count + 1
        end
    end
    return count
end

function Manager:GetHotkey(name)
    local info = self.registry[name]
    return info and info.hotkey or self.data[name]
end

function Manager:SetHotkey(name, hotkey)
    self.data[name] = hotkey

    local info = self.registry[name]
    if info ~= nil then
        info.hotkey = hotkey
    end

    if self.loaded then
        self:_Save()
    else
        self.changedBeforeLoad[name] = true
    end
end

function Manager:RestoreDefaultHotkey(name)
    local info = self.registry[name]
    if info ~= nil then
        self:SetHotkey(name, info.defaultHotkey)
    end
end

function Manager:Register(name, handler, defaultHotkey)
    local info = self.registry[name] or {}
    info.handler = handler
    info.defaultHotkey = defaultHotkey
    self.registry[name] = info

    if self.data[name] == nil then
        self.data[name] = defaultHotkey
        if self.loaded then
            if defaultHotkey ~= nil then
                self:_Save()
            end
        elseif defaultHotkey ~= nil then
            self.saveAfterLoad = true
        end
    end

    info.hotkey = self.data[name]
end

function Manager:Unregister(name)
    self.registry[name] = nil
end

function Manager:ListenOnce(callback)
    if callback == nil then
        return
    end
    self.tempListeners[#self.tempListeners + 1] = callback
end

function Manager:CancelListenOnce(callback)
    for i, listener in ipairs(self.tempListeners) do
        if listener == callback then
            table.remove(self.tempListeners, i)
            return
        end
    end
end

function Manager:_CanHandleInput()
    if IsPaused() then
        return false
    end

    local controller = self.player and self.player.components and self.player.components.playercontroller or nil
    return controller ~= nil and controller:IsEnabled()
end

function Manager:_DispatchTempListener(key, down)
    local listener = self.tempListeners[1]
    if listener == nil then
        return false
    end

    local ok, shouldRemove = pcall(listener, key, down)
    if ok and shouldRemove then
        table.remove(self.tempListeners, 1)
    end
    return true
end

function Manager:_DispatchHotkeys(key)
    for name, info in pairs(self.registry) do
        if info.hotkey == key then
            pcall(info.handler, name, key)
        end
    end
end

function Manager:_InstallHook()
    if self.controlHandler ~= nil then
        return
    end

    self.controlHandler = TheInput.onkey:AddEventHandler("onkey", function(key, down)
        if not self:_CanHandleInput() then
            return
        end

        if self:_DispatchTempListener(key, down) then
            return
        end

        if down then
            self:_DispatchHotkeys(key)
        end
    end)
end

function Manager:_UninstallHook()
    if self.controlHandler == nil then
        return
    end

    self.controlHandler:Remove()
    self.controlHandler = nil
end

GLOBAL.GetHotKeyManager = HotKeyManager.Get

return HotKeyManager
