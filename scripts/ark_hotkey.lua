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
        registry = {},      -- 改为 { [name] = {hotkey=key, handler=func} }
        hooksInstalled = false,
        origOnRawKey = nil,
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
    
    -- 重置热键
    function manager:ResetHotkey(name)
        local data = loadData()
        data[name] = nil
        saveData(data)
    end
    
    -- 注册热键处理器
    function manager:Register(name, handler, defaultHotkey)
        local hotkey = self:GetHotkey(name) or defaultHotkey
        self.registry[name] = {
            hotkey = hotkey,
            handler = handler
        }
        
        self:_installHook()
    end
    
    -- 注销热键
    function manager:Unregister(name)
        self.registry[name] = nil
    end
    
    -- 添加临时按键监听器（返回取消函数）
    function manager:AddTempListener(callback)
        local listener = { callback = callback }
        table.insert(self.tempListeners, listener)
        
        return function()
            for i, v in ipairs(self.tempListeners) do
                if v == listener then
                    table.remove(self.tempListeners, i)
                    break
                end
            end
        end
    end

    function manager:RemoveTempListener(callback)
        for i, v in ipairs(self.tempListeners) do
            if v.callback == callback then
                table.remove(self.tempListeners, i)
                break
            end
        end
    end
    
    -- 清除所有临时监听器
    function manager:ClearAllTempListeners()
        self.tempListeners = {}
    end
    
    -- 安装HUD钩子（改进版）
    function manager:_installHook()
        if self.hooksInstalled or not player.hud then return end
        
        self.hooksInstalled = true
        self.origOnRawKey = player.hud.OnRawKey
        
        player.hud.OnRawKey = function(_, key, down)
            -- 1. 优先处理临时监听器
            if #self.tempListeners > 0 then
                local listeners = shallowCopy(self.tempListeners)
                for _, listener in ipairs(listeners) do
                    pcall(listener.callback, key, down)
                end
                return true
            end
            
            -- 2. 常规热键处理（允许同一个按键触发多个handler）
            if down then
                local triggered = false
                for name, info in pairs(self.registry) do
                    if info.hotkey == key then
                        pcall(info.handler, name, key)
                        triggered = true
                    end
                end
                return triggered
            end
            
            return self.origOnRawKey(_, key, down)
        end
    end
    
    return manager
end
GLOBAL.GetHotKeyManager = HotKeyManager.Get
return HotKeyManager
