local ArkHotKey = {}

-- 统一热键管理器：只管理热键的映射、注册与分发，不关心“技能”等上层概念。
-- API（注入到 ThePlayer）：
--   SaveArkHotKey(context, id, key | nil)  -- 保存/清除自定义绑定（持久化）
--   GetArkHotKey(context, id)              -- 读取当前生效绑定（自定义优先）
--   LoadArkHotKey()                        -- 异步加载自定义绑定
--   RefreshArkHotKey()                     -- 预留（目前无副作用）
--   RegisterArkHotKey(context, id, handler, defaultKey)
--   UnregisterArkHotKey(context, id)
--   BeginArkHotKeyCapture(context, callback)
--   EndArkHotKeyCapture()
--   GetArkHotKeyManager()
--
-- 运行期：
--   - 通过 HookHUD(hud) 接管 OnRawKey，只要有注册项，就能把按键分发给对应 handler
--   - 冲突检测：FindIdByHotKey(context, key, onlyRegistered)

local function getStorageKey(player)
  return "ark_hotkeys_" .. (player.userid or "") .. "_" .. (player.prefab or "")
end

function ArkHotKey.Create(player)
  local mgr = {
    player = player,
    default = {},            -- { [context] = { [id] = key } }
    custom = nil,            -- 磁盘持久化数据；结构同上
    registry = {},          -- { [context] = { [id] = handler_fn } }
    _hook_installed = false,
    _orig_OnRawKey = nil,
    _capture = { context = nil, callback = nil },
  }

  -- 工具
  local function ensureContext(t, ctx)
    if not t[ctx] then t[ctx] = {} end
    return t[ctx]
  end

  -- 默认映射：注册时可提供 defaultKey 写入
  function mgr:SetDefault(context, id, key)
    local ctx = ensureContext(self.default, context)
    if ctx[id] == nil then
      ctx[id] = key
    end
  end

  -- 查询当前生效映射（自定义优先）
  function mgr:Get(context, id)
    local ctxCustom = self.custom and self.custom[context] or nil
    if ctxCustom and ctxCustom[id] ~= nil then
      return ctxCustom[id]
    end
    local ctxDefault = self.default[context]
    return ctxDefault and ctxDefault[id] or nil
  end

  -- 写入/清除自定义映射并持久化
  function mgr:Save(context, id, hotKey)
    ensureContext(self, 'custom')
    ensureContext(self.custom, context)
    if hotKey == nil then
      self.custom[context][id] = nil
    else
      self.custom[context][id] = hotKey
    end
    if TheSim and json then
      TheSim:SetPersistentString(getStorageKey(self.player), json.encode(self.custom), false)
    end
  end

  -- 无副作用占位：保留兼容性
  function mgr:Refresh()
    -- 需要时可重建缓存；当前分发直接 Get 即可
  end

  -- 异步加载自定义映射
  function mgr:Load()
    if not TheSim then return end
    TheSim:GetPersistentString(getStorageKey(self.player), function(ok, str)
      if not ok then
        self.custom = {}
        self:Refresh()
        return
      end
      local ok2, data = pcall(json.decode, str)
      if not ok2 then
        self.custom = {}
        self:Refresh()
        return
      end
      self.custom = data or {}
      self:Refresh()
    end)
  end

  -- 注册/注销运行期处理器
  function mgr:Register(context, id, handler, defaultKey)
    local ctx = ensureContext(self.registry, context)
    ctx[id] = handler
    if defaultKey ~= nil then
      self:SetDefault(context, id, defaultKey)
    end
  end

  function mgr:Unregister(context, id)
    local ctx = self.registry[context]
    if ctx then
      ctx[id] = nil
    end
  end

  -- 冲突检测：默认仅在“已注册”的 id 范围内检查
  function mgr:FindIdByHotKey(context, hotKey, onlyRegistered)
    onlyRegistered = (onlyRegistered ~= false)
    if onlyRegistered then
      local ctx = self.registry[context]
      if not ctx then return nil end
      for id, _ in pairs(ctx) do
        if self:Get(context, id) == hotKey then
          return id
        end
      end
      return nil
    end
    -- 扩大到默认+自定义的并集
    local seen = {}
    if self.default[context] then
      for id, _ in pairs(self.default[context]) do seen[id] = true end
    end
    if self.custom and self.custom[context] then
      for id, _ in pairs(self.custom[context]) do seen[id] = true end
    end
    for id, _ in pairs(seen) do
      if self:Get(context, id) == hotKey then return id end
    end
    return nil
  end

  -- 捕获设置：用于“按任意键设置”为 UI 回调提供按键与冲突 id
  function mgr:BeginCapture(context, callback)
    self._capture.context = context
    self._capture.callback = callback
  end
  function mgr:EndCapture()
    self._capture.context = nil
    self._capture.callback = nil
  end

  -- 安装 HUD 钩子（幂等）
  function mgr:HookHUD(hud)
    if self._hook_installed or not hud then return self end
    self._hook_installed = true
    self._orig_OnRawKey = hud.OnRawKey

    local selfmgr = self
    function hud:OnRawKey(key, down)
      if not down then
        return selfmgr._orig_OnRawKey(self, key, down)
      end

      -- 1) 设置捕获期：优先把按键交给 UI 设置逻辑
      local capture_cb = selfmgr._capture.callback or self._settingSkillHotKeyCallback -- 向后兼容旧逻辑，默认 context='skill'
      if capture_cb then
        local context = selfmgr._capture.context or 'skill'
        local conflictId = selfmgr:FindIdByHotKey(context, key, true)
        pcall(capture_cb, key, conflictId)
        return true
      end

      -- 2) 正常分发：遍历注册表，按 context+id 的生效键触发 handler
      local handled = false
      for context, ids in pairs(selfmgr.registry) do
        for id, handler in pairs(ids) do
          if selfmgr:Get(context, id) == key then
            pcall(handler, context, id, key)
            handled = true
          end
        end
      end
      if handled then return true end

      return selfmgr._orig_OnRawKey(self, key, down)
    end

    return self
  end

  -- 注入 ThePlayer API（幂等）
  function mgr:AttachToPlayer()
    local p = self.player
    if not p then return self end
    p.SaveArkHotKey = function(_, context, id, hotKey) self:Save(context, id, hotKey) end
    p.GetArkHotKey = function(_, context, id) return self:Get(context, id) end
    p.LoadArkHotKey = function(_) self:Load() end
    p.RefreshArkHotKey = function(_) self:Refresh() end
    p.RegisterArkHotKey = function(_, context, id, handler, defaultKey) self:Register(context, id, handler, defaultKey) end
    p.UnregisterArkHotKey = function(_, context, id) self:Unregister(context, id) end
    p.BeginArkHotKeyCapture = function(_, context, callback) self:BeginCapture(context, callback) end
    p.EndArkHotKeyCapture = function(_) self:EndCapture() end
    p.GetArkHotKeyManager = function(_) return self end
    return self
  end

  return mgr
end

return ArkHotKey

