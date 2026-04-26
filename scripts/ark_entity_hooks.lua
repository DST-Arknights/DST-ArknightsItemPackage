-- 技能 / 天赋共用的 Hook 链与事件监听基础设施
-- 包含：
--   M.CopySaveData(data)
--   M.InstallManagerHooks(cls)   安装 _GetOrCreateHookChain / _HookRegister / _HookUnregister
--   M.InstallItemBase(cls)       安装 _InitItemBase / _AddCallback / _RemoveCallback /
--                                     HookFunction / UnhookFunction /
--                                     ListenForEvent / RemoveEventCallback / _CleanupOwnedHooks

local M = {}

-- ── 工具函数 ─────────────────────────────────────────────────────────────────

function M.CopySaveData(data)
  local copy = {}
  for key, value in pairs(data) do
    copy[key] = value
  end
  return copy
end

-- ── Manager 端：共享 Hook 链 ─────────────────────────────────────────────────
-- 每个 (obj, funcName) 对只替换一次原函数，所有 SingleItem 的中间件统一调度，
-- 避免多个天赋/技能重复包装同一函数导致的调用栈嵌套问题。

function M.InstallManagerHooks(cls)

  -- 获取或创建 hook 链；首次调用时替换 obj[funcName] 为调度器。
  function cls:_GetOrCreateHookChain(obj, funcName)
    local id = tostring(obj) .. "\0" .. funcName
    if not self._sharedHookRegistry[id] then
      local original = obj[funcName]
      assert(type(original) == "function",
        "HookFunction: '" .. tostring(funcName) .. "' 不是函数: " .. tostring(obj))
      local entry = {
        id       = id,
        obj      = obj,
        key      = funcName,
        original = original,
        mws      = {},  -- 有序列表 { token, fn }，无空洞
      }
      obj[funcName] = function(...)
        local mws = entry.mws
        local idx = 0
        local function callNext(...)
          idx = idx + 1
          if mws[idx] then
            return mws[idx].fn(callNext, ...)
          else
            return entry.original(...)
          end
        end
        return callNext(...)
      end
      self._sharedHookRegistry[id] = entry
    end
    return self._sharedHookRegistry[id]
  end

  -- 向 hook 链末尾追加一个中间件，返回 (token, entryId)。
  function cls:_HookRegister(obj, funcName, fn)
    local entry = self:_GetOrCreateHookChain(obj, funcName)
    local token = Symbol("hook_" .. tostring(funcName))
    table.insert(entry.mws, { token = token, fn = fn })
    return token, entry.id
  end

  -- 移除指定 token 的中间件（幂等）。
  -- 链空时调度器仍留在 obj 上作为透传，不还原原函数：
  -- 其他模组可能在任意时刻包装了同一接口，强制还原会抹掉它们的 hook。
  function cls:_HookUnregister(token, entryId)
    if token == nil then return end
    local entry = self._sharedHookRegistry[entryId]
    if not entry then return end
    for i, mw in ipairs(entry.mws) do
      if mw.token == token then
        table.remove(entry.mws, i)
        return
      end
    end
  end

end

-- ── Item 端：Callback / Hook / Listener 基础设施 ─────────────────────────────
-- 安装到 SingleSkill / SingleTalent 等 item 类。
-- InstallItemBase 在类定义后立即调用（如 InstallItemBase(SingleSkill)）。
-- 构造函数中需调用 self:_InitItemBase() 来初始化实例字段。

function M.InstallItemBase(cls)

  -- 初始化 item 运行态字段（构造函数末尾调用）
  function cls:_InitItemBase()
    self._callbacks      = {}
    self._ownedTokens    = {}
    self._ownedListeners = {}
  end

  -- ── 内部 Callback 工具 ─────────────────────────────────────────────────

  function cls:_AddCallback(eventName, fn)
    if fn == nil then return end
    local list = self._callbacks[eventName]
    if not list then
      list = {}
      self._callbacks[eventName] = list
    end
    for _, cb in ipairs(list) do
      if cb == fn then return end
    end
    table.insert(list, fn)
  end

  function cls:_RemoveCallback(eventName, fn)
    if fn == nil then return end
    local list = self._callbacks[eventName]
    if not list then return end
    for i, cb in ipairs(list) do
      if cb == fn then
        table.remove(list, i)
        return
      end
    end
  end

  -- ── Hook 系统 ─────────────────────────────────────────────────────────

  -- 注册一个与本 item 生命周期绑定的函数中间件。
  -- fn 签名：function(next, ...) ... return next(...) end
  -- 返回 token，可传入 UnhookFunction 做定点移除。
  function cls:HookFunction(obj, funcName, fn)
    local token, entryId = self.manager:_HookRegister(obj, funcName, fn)
    table.insert(self._ownedTokens, { token = token, entryId = entryId })
    return token
  end

  -- 定点移除指定 token 的中间件；token 不存在或已清理时静默返回（幂等）。
  function cls:UnhookFunction(token)
    if token == nil then return end
    for i, owned in ipairs(self._ownedTokens) do
      if owned.token == token then
        self.manager:_HookUnregister(token, owned.entryId)
        table.remove(self._ownedTokens, i)
        return
      end
    end
  end

  -- ── Listener 系统 ─────────────────────────────────────────────────────

  -- 注册一个与本 item 生命周期绑定的事件监听。
  -- 签名：ListenForEvent(event, fn, [source])
  --   source 为 nil 时监听 self.inst 自身；为外部实体时框架自动在其 onremove 时清理。
  -- 返回 token，可传入 RemoveEventCallback 做定点移除。
  function cls:ListenForEvent(event, fn, source)
    local listener = self.inst
    local token = Symbol("listen_" .. tostring(event))
    local entry = {
      token          = token,
      listener       = listener,
      event          = event,
      fn             = fn,
      source         = source,  -- nil == 监听自身
      sourceRemoveFn = nil,
    }
    -- source 是外部实体时，注册 onremove 守卫，source 死亡时自动清理本条记录
    if source ~= nil and source ~= listener then
      entry.sourceRemoveFn = function()
        self:RemoveEventCallback(token)
      end
      listener:ListenForEvent("onremove", entry.sourceRemoveFn, source)
    end
    table.insert(self._ownedListeners, entry)
    listener:ListenForEvent(event, fn, source)
    return token
  end

  -- 定点移除指定 token 的事件监听；token 不存在或已清理时静默返回（幂等）。
  function cls:RemoveEventCallback(token)
    if token == nil then return end
    local listeners = self._ownedListeners
    for i, entry in ipairs(listeners) do
      if entry.token == token then
        entry.listener:RemoveEventCallback(entry.event, entry.fn, entry.source)
        if entry.sourceRemoveFn then
          entry.listener:RemoveEventCallback("onremove", entry.sourceRemoveFn, entry.source)
        end
        table.remove(listeners, i)
        return
      end
    end
  end

  -- ── 兜底清理 ──────────────────────────────────────────────────────────

  -- 清理本 item 注册的所有 hook 与事件监听（由 Remove 在最后调用，作为安全兜底）。
  function cls:_CleanupOwnedHooks()
    for _, owned in ipairs(self._ownedTokens) do
      self.manager:_HookUnregister(owned.token, owned.entryId)
    end
    self._ownedTokens = {}
    local listeners = self._ownedListeners
    self._ownedListeners = {}
    for _, entry in ipairs(listeners) do
      entry.listener:RemoveEventCallback(entry.event, entry.fn, entry.source)
      if entry.sourceRemoveFn then
        entry.listener:RemoveEventCallback("onremove", entry.sourceRemoveFn, entry.source)
      end
    end
  end

end

return M
