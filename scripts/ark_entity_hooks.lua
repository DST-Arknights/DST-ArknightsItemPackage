-- 技能 / 天赋共用的 Hook 链与事件监听基础设施
-- 包含：
--   M.CopySaveData(data)
--   M.InstallItemBase(cls)       安装 _InitItemBase / _AddCallback / _RemoveCallback /
--                                     HookFunction / UnhookFunction /
--                                     ListenForEvent / RemoveEventCallback / _CleanupOwnedHooks
--
-- Hook 底层实现由全局 ArkHookFunction / ArkUnhookFunction 提供（modmain/ark_function_hook.lua）。

local M = {}

-- ── 工具函数 ─────────────────────────────────────────────────────────────────

function M.CopySaveData(data)
  local copy = {}
  for key, value in pairs(data) do
    copy[key] = value
  end
  return copy
end

-- ── Item 端：Callback / Hook / Listener 基础设施 ─────────────────────────────
-- 安装到 SingleSkill / SingleTalent 等 item 类。
-- InstallItemBase 在类定义后立即调用（如 InstallItemBase(SingleSkill)）。
-- 构造函数中需调用 self:_InitItemBase() 来初始化实例字段。

function M.InstallItemBase(cls)

  -- 初始化 item 运行态字段（构造函数末尾调用）
  function cls:_InitItemBase()
    self._callbacks      = {}
    self._ownedHooks     = {}  -- { obj, funcName, fn }
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
  -- 允许多次注册同一 fn，每次注册对应一次独立的链条调用；UnhookFunction 每次只移除一条。
  -- fn 签名：function(next, ...) ... return next(...) end
  function cls:HookFunction(obj, funcName, fn)
    ArkHookFunction(obj, funcName, fn)
    table.insert(self._ownedHooks, { obj = obj, funcName = funcName, fn = fn })
  end

  -- 移除指定中间件；不存在或已清理时静默返回（幂等）。
  function cls:UnhookFunction(obj, funcName, fn)
    ArkUnhookFunction(obj, funcName, fn)
    local hooks = self._ownedHooks
    for i, owned in ipairs(hooks) do
      if owned.obj == obj and owned.funcName == funcName and owned.fn == fn then
        table.remove(hooks, i)
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
    for _, owned in ipairs(self._ownedHooks) do
      ArkUnhookFunction(owned.obj, owned.funcName, owned.fn)
    end
    self._ownedHooks = {}
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
