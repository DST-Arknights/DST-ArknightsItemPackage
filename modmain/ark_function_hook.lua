-- 全局函数 Hook 工具，供其他模组调用。
-- 对同一 (obj, funcName) 只安装一次调度器，所有中间件共享同一条链，
-- 避免多次包装导致的调用栈嵌套。
--
-- 注册表以弱 key 持有 obj，obj 被 GC 后对应条目自动消失。
--
-- 用法：
--   ArkHooks.HookFunction(obj, funcName, fn)
--   ArkHooks.UnhookFunction(obj, funcName, fn)
--
-- fn 签名：function(next, ...) ... return next(...) end

-- ── 注册表 ────────────────────────────────────────────────────────────────────
-- _registry[obj] = { [funcName] = entry }
-- entry = { original = fn, mws = [ fn, ... ] }
local _registry = setmetatable({}, { __mode = "k" })

-- ── 核心逻辑 ──────────────────────────────────────────────────────────────────

local function _getOrCreateEntry(obj, funcName)
  local objHooks = _registry[obj]
  if not objHooks then
    objHooks = {}
    _registry[obj] = objHooks
  end

  local entry = objHooks[funcName]
  if not entry then
    local original = obj[funcName]
    assert(type(original) == "function",
      "ArkHooks.HookFunction: '" .. tostring(funcName) .. "' 不是函数: " .. tostring(obj))
    entry = {
      original = original,
      mws      = {},
    }
    -- 安装调度器；链空时透传，不还原原函数（保持与其他模组 hook 的兼容性）
    -- dispatch(i) 每层使用独立的 i 值，支持同一函数的递归/重入调用。
    obj[funcName] = function(...)
      local mws = entry.mws
      local function dispatch(i, ...)
        if mws[i] then
          return mws[i](function(...) return dispatch(i + 1, ...) end, ...)
        else
          return entry.original(...)
        end
      end
      return dispatch(1, ...)
    end
    objHooks[funcName] = entry
  end

  return entry
end

-- ── 公开 API ──────────────────────────────────────────────────────────────────

--- 向 obj[funcName] 中间件链末尾追加 fn。允许多次注册同一 fn，每次注册对应一次独立调用。
--- @param obj      table|userdata  目标对象
--- @param funcName string          被 hook 的方法名
--- @param fn       function        中间件，签名 function(next, ...) end
local function HookFunction(obj, funcName, fn)
  local t = type(obj)
  assert(t == "table" or t == "userdata",
    "ArkHooks.HookFunction: obj 必须是 table 或 userdata，得到 " .. t)
  assert(type(funcName) == "string",
    "ArkHooks.HookFunction: funcName 必须是字符串")
  assert(type(fn) == "function",
    "ArkHooks.HookFunction: fn 必须是函数")

  local entry = _getOrCreateEntry(obj, funcName)
  table.insert(entry.mws, fn)
end

--- 移除 obj[funcName] 中间件链中的 fn（幂等，不存在时静默返回）。
--- @param obj      table|userdata  目标对象
--- @param funcName string          被 hook 的方法名
--- @param fn       function        传入 HookFunction 的同一函数引用
local function UnhookFunction(obj, funcName, fn)
  if obj == nil or fn == nil then return end
  local objHooks = _registry[obj]
  if not objHooks then return end
  local entry = objHooks[funcName]
  if not entry then return end
  local mws = entry.mws
  for i, mw in ipairs(mws) do
    if mw == fn then
      table.remove(mws, i)
      return
    end
  end
end

-- ── 导出 ──────────────────────────────────────────────────────────────────────

GLOBAL.ArkHookFunction   = HookFunction
GLOBAL.ArkUnhookFunction = UnhookFunction
