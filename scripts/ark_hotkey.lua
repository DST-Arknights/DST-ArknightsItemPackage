local HotKeyManager = {
    instances = {},         -- [player] = manager
    persistentData = {}     -- [userid] = { [name] = hotkey }
}

-- 浅拷贝工具函数
local function shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
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
        local userid = player.userid or ""
        return HotKeyManager.persistentData[userid] or {}
    end
    
    -- 保存数据
    local function saveData(data)
        local userid = player.userid or ""
        HotKeyManager.persistentData[userid] = data
    end
    
    -- 获取当前热键
    function manager:GetHotkey(name)
        local data = loadData()
        return data[name]
    end
    
    -- 设置热键
    function manager:SetHotkey(name, hotkey)
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
        local hotkey = self:GetHotkey(name)
        if not hotkey and defaultHotkey then
            -- 如果没有已保存的热键，使用默认值并保存
            hotkey = defaultHotkey
            self:SetHotkey(name, hotkey)
        end
        self.registry[name] = {
            hotkey = hotkey,
            handler = handler,
            defaultHotkey = defaultHotkey,  -- 保存默认值
        }

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

    return manager
end
GLOBAL.GetHotKeyManager = HotKeyManager.Get
return HotKeyManager
