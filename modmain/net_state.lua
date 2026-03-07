-- NetState: 一个轻量级网络状态同步封装器
-- 用于在 Don't Starve 中统一管理普通字段（normal）和 classified 字段的网络变量，
-- 支持自动绑定、延迟监听、客户端缓存回填、Attach/Detach 生命周期等。
-------------------------------------------------------------------------------
-- 类型映射：将用户友好的类型名映射到游戏内置的 net 变量构造函数
-- 注意：所有类型必须已在引擎中注册（如 net_int, net_string 等）
-------------------------------------------------------------------------------
local TYPE_MAP = {
  -- 基础标量
  bool = net_bool,
  entity = net_entity,
  float = net_float,

  -- 无符号小整数（按位宽命名）
  tiny = net_tinybyte, -- 3-bit, [0..7]
  tinybyte = net_tinybyte,
  small = net_smallbyte, -- 6-bit, [0..63]
  smallbyte = net_smallbyte,
  byte = net_byte, -- 8-bit, [0..255]

  -- 有符号/无符号整数
  short = net_shortint, -- 16-bit signed
  shortint = net_shortint,
  ushort = net_ushortint, -- 16-bit unsigned
  ushortint = net_ushortint,
  int = net_int, -- 32-bit signed
  uint = net_uint, -- 32-bit unsigned

  -- 其他标量
  hash = net_hash,
  string = net_string,

  -- 字节数组（底层为字符串）
  bytearray = net_bytearray,
  smallbytearray = net_smallbytearray,
  ushortarray = net_ushortarray
}

-- 各类型的默认值：用于未初始化或网络变量尚未创建时的回退值
local TYPE_DEFAULT_VALUE = {
  bool = false,
  entity = nil,
  float = 0,

  tiny = 0,
  tinybyte = 0,
  small = 0,
  smallbyte = 0,
  byte = 0,
  short = 0,
  shortint = 0,
  ushort = 0,
  ushortint = 0,
  int = 0,
  uint = 0,

  hash = 0,
  string = "",

  bytearray = "",
  smallbytearray = "",
  ushortarray = ""
}

-------------------------------------------------------------------------------
-- 工具函数
-------------------------------------------------------------------------------

-- 将 schema 定义字符串（如 "int:classified"）解析为结构化表
-- 示例: "string:classified" => { type = "string", classified = true }
local function ParseSchema(schema)
  local parsed_schema = {}
  for key, def_str in pairs(schema) do
    local def = {}
    for token in string.gmatch(def_str, "([^:]+)") do
      if def.type == nil then
        def.type = token
      else
        def[token] = true -- 标记额外属性（如 classified）
      end
    end
    parsed_schema[key] = def
  end
  return parsed_schema
end

-- 根据过滤条件筛选 schema 子集
local function filterSchema(schema, predicate)
  local result = {}
  for key, def in pairs(schema) do
    if predicate(def) then
      result[key] = def
    end
  end
  return result
end

-- 生成网络变量对应的脏标记事件名
local function getDirtyName(key)
  return "net_state" .. key .. "_dirty"
end

local function sanitizeName(name)
  return string.gsub(name, "[^%w_]", "_")
end

local function getForceFieldName(def_name)
  return "__ns_force_tick_" .. sanitizeName(def_name)
end

local function getForceNetName(def_name)
  return "net_state." .. def_name .. ".__force_tick"
end

local function getForceDirtyName(def_name)
  return "net_state" .. sanitizeName(def_name) .. "__force_dirty"
end

-- 模块级通用绑定函数（使用 inner）
local function bindNetVars(inner, owner, schemas)
  if not schemas or next(schemas) == nil then
    return nil
  end
  local var_kind = inner.inst == owner and "normal" or "classified"
  local vars = {}
  for key, def in pairs(schemas) do
    inner.log("Bind", var_kind, "var", key, "type", def.type)
    -- 已存在则绑定, 不存在则创建
    local netvar = owner[key]
    if netvar == nil then
      local constructor = TYPE_MAP[def.type]
      assert(constructor,
        string.format("[NetState] Unknown netvar type '%s' for key '%s'", tostring(def.type), tostring(key)))
      local dirty_event = getDirtyName(key)
      vars[key] = constructor(owner.GUID, "net_state." .. key, dirty_event)
    else
      vars[key] = netvar
    end
  end
  return vars
end

local function DoListenForKey(inst, key, fn)
  local dirty_event = getDirtyName(key)
  inst:ListenForEvent(dirty_event, fn)
end

local function PushDirtyForNonDefaultClassified(inner)
  if not TheWorld.ismastersim then
    return
  end
  local classified_vars = inner._classified_vars
  local classified_schemas = inner.classified_schemas
  local classified_inst = inner.net_state_classified
  if classified_vars == nil or classified_schemas == nil or classified_inst == nil then
    return
  end

  for key, def in pairs(classified_schemas) do
    local netvar = classified_vars[key]
    if netvar ~= nil then
      local value = netvar:value()
      local default_value = TYPE_DEFAULT_VALUE[def.type]
      if value ~= default_value then
        local dirty_event = getDirtyName(key)
        inner.log("Attach", "re-pushing dirty for non-default key", key, value)
        classified_inst:PushEvent(dirty_event)
      end
    end
  end
end

local function RegisterClassifiedPrefab(prefab_name, def_name, schemas)
  ArkLogger:Trace('[net_state_classified]', 'RegisterClassifiedPrefab', prefab_name, def_name)
  RegisterSinglePrefab(Prefab(prefab_name, function()
    ArkLogger:Trace('[net_state_classified]', 'Prefab', prefab_name, 'create')
    local inst = CreateEntity()
    if TheWorld.ismastersim then
      inst.entity:AddTransform()
    end
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst.entity:SetCanSleep(false)
    inst:AddTag("CLASSIFIED")
    inst._index = net_uint(inst.GUID, "net_state._index", "indexdirty")
    local force_field = getForceFieldName(def_name)
    local force_dirty_event = getForceDirtyName(def_name)
    inst[force_field] = net_uint(inst.GUID, getForceNetName(def_name), force_dirty_event)
    for key, def in pairs(schemas) do
      local constructor = TYPE_MAP[def.type]
      local dirty_event = getDirtyName(key)
      inst[key] = constructor(inst.GUID, "net_state." .. key, dirty_event)
    end
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
      -- 立即监听所有 classified 变量的 dirty，记录到 _pending_dirty_keys
      -- 用于补偿 AttachClassified 之前触发的 dirty 事件
      inst._pending_dirty_keys = {}
      for key, def in pairs(schemas) do
        local dirty_event = getDirtyName(key)
        inst:ListenForEvent(dirty_event, function()
          if inst._state == nil then
            -- 还没 AttachClassified，记录下来
            inst._pending_dirty_keys[key] = true
            ArkLogger:Trace('[net_state_classified]', 'pending dirty key', key)
          end
        end)
      end
      inst:ListenForEvent(force_dirty_event, function()
        if inst._state == nil then
          inst._pending_force_dirty = true
          ArkLogger:Trace('[net_state_classified]', 'pending force dirty')
        end
      end)

      inst:ListenForEvent("indexdirty", function()
      -- inst.OnEntityReplicated = function(inst)
        local index = inst._index:value()
        local parent = inst.entity:GetParent()
        if parent == nil then
          ArkLogger:Warn('[net_state_classified]', 'OnEntityReplicated parent == nil', inst)
          inst:Remove()
          return
        end
        local state = parent._ns_state_by_name and parent._ns_state_by_name[prefab_name] and parent._ns_state_by_name[prefab_name][index] or nil
        if state == nil then
          -- 没找到, 等待
          ArkLogger:Trace('[net_state_classified]', 'OnEntityReplicated state == nil, push pending', prefab_name)
          parent._ns_pending_classified = parent._ns_pending_classified or {}
          parent._ns_pending_classified[prefab_name] = parent._ns_pending_classified[prefab_name] or {}
          parent._ns_pending_classified[prefab_name][index] = inst
          return
        else
          state:AttachClassified(inst)
        end
      -- end
      end)
      inst.OnRemoveEntity = function(inst)
        local parent = inst.entity:GetParent()
        if parent ~= nil then
          -- 解除_ns_pending_classified
          local pending = parent._ns_pending_classified
          if pending ~= nil then
            pending[prefab_name] = nil
          end
        end
        if inst._state ~= nil then
          inst._state:DetachClassified()
        end
      end
      return inst
    end
    inst.persists = false
    return inst
  end))
end

-------------------------------------------------------------------------------
-- NetState 定义注册表
-------------------------------------------------------------------------------
local _NS_DEFINITIONS = {}

--- 定义一个 NetState schema（必须在 modmain.lua 中调用，早于任何 NetState 实例化）
-- @param name string 唯一标识符
-- @param schema_def table 字段定义表，如 { health = "float:classified", name = "string" }
local function DefineNetState(name, schema_def)
  assert(type(name) == "string", "[DefineNetState] name must be a string")
  assert(_NS_DEFINITIONS[name] == nil,
    string.format("[DefineNetState] Duplicate definition for '%s'", name))

  local parsed = ParseSchema(schema_def)
  local classified = filterSchema(parsed, function(def) return def.classified end)
  local normal = filterSchema(parsed, function(def) return not def.classified end)

  _NS_DEFINITIONS[name] = {
    full = parsed,
    classified = classified,
    normal = normal
  }

  -- 立即注册 classified prefab（在 mod 加载阶段）
  local prefab_name = "net_state_" .. name
  if next(classified) then
    RegisterClassifiedPrefab(prefab_name, name, classified)
  end

  ArkLogger:Trace('[DefineNetState]', 'Defined', name, 'prefab:', prefab_name)
end

-------------------------------------------------------------------------------
-- NetState 类定义
-------------------------------------------------------------------------------
local stateId = 1
local NetState = {}
-- 记录netState对象与内部变量表的映射
local NetStateMap = setmetatable({}, {
  __mode = "k"
})
-- 实例初始化逻辑
local function NetStateInit(self, inst, name)
  assert(type(name) == "string",
    "[NetState] name must be a string. Use DefineNetState to define schema first.")
  local definition = _NS_DEFINITIONS[name]
  assert(definition,
    string.format("[NetState] Definition '%s' not found. Did you call DefineNetState?", name))

  local inner = {}
  NetStateMap[self] = inner
  inner.inst = inst
  inner._owner_removed = false
  inner._classified_detached = false
  inner._id = stateId
  stateId = stateId + 1
  inner._def_name = name
  inner._force_field = getForceFieldName(name)
  inner._force_dirty_event = getForceDirtyName(name)
  inner._force_dirty_handler = function()
    inner.log("ForceSync", "force dirty received, replay all keys")
    if inner.normal_schemas then
      for key, _ in pairs(inner.normal_schemas) do
        inner.inst:PushEvent(getDirtyName(key))
      end
    end
    if inner.classified_schemas and inner.net_state_classified then
      for key, _ in pairs(inner.classified_schemas) do
        inner.net_state_classified:PushEvent(getDirtyName(key))
      end
    end
  end

  local state_name = "net_state_" .. name
  if not inst._ns_state_by_name then
    inst._ns_state_by_name = {}
  end
  if not inst._ns_state_by_name[state_name] then
    inst._ns_state_by_name[state_name] = {}
  end
  table.insert(inst._ns_state_by_name[state_name], self)
  inner._index = #inst._ns_state_by_name[state_name]
  -- 记录下自己是第几个, 客户端需要对应上正确的索引

  -- 实例专属日志方法：自动携带 GUID 和分类标签
  inner.log = function(category, ...)
    local template = type(category) == "string" and "[NetState:%s][%s]" or "[NetState:%s]"
    ArkLogger:Trace(string.format(template, inner._id, category), ...)
  end

  -- 使用预解析的 schema
  inner.classified_schemas = definition.classified
  inner.normal_schemas = definition.normal
  inner.log("Init", "binding normal netvars", "def_name", name)
  inner._vars = bindNetVars(inner, inner.inst, inner.normal_schemas)
  inner._pending_classified_listeners = {}
  inner.inst:ListenForEvent("onremove", function()
    if inner._owner_removed then
      return
    end
    inner._owner_removed = true
    inner.log("Detach", "owner removed")
    if inner.net_state_classified ~= nil then
      self:DetachClassified()
    elseif inner._on_detached then
      inner._on_detached(ThePlayer)
    end
  end)

  if not next(inner.classified_schemas) then
    if inner.inst[inner._force_field] == nil then
      inner.inst[inner._force_field] = net_uint(inner.inst.GUID, getForceNetName(name), inner._force_dirty_event)
    end
    inner._force_var = inner.inst[inner._force_field]
    inner.inst:ListenForEvent(inner._force_dirty_event, inner._force_dirty_handler)
  end
  -- 若存在 classified 字段，则在主机上生成 classified，在客机上尝试消费 pending
  if next(inner.classified_schemas) then
    -- prefab 已在 DefineNetState 时注册，可以同步执行
    if TheWorld.ismastersim then
      inner.net_state_classified = SpawnPrefab(state_name)
      inner.net_state_classified.entity:SetParent(inner.inst.entity)
      inner.net_state_classified._index:set(inner._index)
      self:AttachClassified(inner.net_state_classified, true)
      inner.net_state_classified.Network:SetClassifiedTarget(inner.inst)
      self:Attach(inner.inst)
    else
      -- 客机：如果 classified 先于 NetStateInit 到达，则 OnEntityReplicated 会把
      -- net_state_classified 放到 inst._ns_pending_classified[state_name] 里。
      -- 这里在初始化完成后主动检查并尝试完成绑定。
      inner.inst:DoTaskInTime(0, function()
        local pending_classified = inner.inst._ns_pending_classified and inner.inst._ns_pending_classified[state_name] and inner.inst._ns_pending_classified[state_name][inner._index] or nil
        if pending_classified ~= nil and pending_classified:IsValid() then
          inner.log("AttachClassified", "attach from pending (classified) ", state_name)
          self:AttachClassified(pending_classified)
        end
      end)
    end
  end
end

-- 支持 NetState(inst, name) 语法创建实例
setmetatable(NetState, {
  __call = function(cls, inst, name)
    local self = setmetatable({}, cls)
    NetStateInit(self, inst, name)
    return self
  end
})


-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- 注册 Attach 成功回调（若已 Attach 则立即执行）
function NetState:OnAttached(fn)
  local inner = NetStateMap[self]
  inner._on_attached = fn
end

--- 注册 Detach 回调
function NetState:OnDetached(fn)
  local inner = NetStateMap[self]
  inner._on_detached = fn
end

function NetState:AttachClassified(net_state_classified, skip_attach)
  local inner = NetStateMap[self]
  inner._classified_detached = false
  inner.net_state_classified = net_state_classified
  net_state_classified._state = self
  inner._force_var = net_state_classified[inner._force_field]
  if inner._force_var ~= nil then
    net_state_classified:ListenForEvent(inner._force_dirty_event, inner._force_dirty_handler)
  else
    inner.log("AttachClassified", "force var bind failed", inner._force_field, inner._def_name)
  end
  inner.log("AttachClassified", "attaching classified", net_state_classified)
  -- 注册所有 pending 的 classified 监听
  if inner._pending_classified_listeners and #inner._pending_classified_listeners > 0 then
    for _, item in ipairs(inner._pending_classified_listeners) do
      DoListenForKey(inner.net_state_classified, item.key, item.fn)
      inner.log("Watch", "attached classified listener for", item.key)
    end
  end
  inner._classified_vars = bindNetVars(inner, inner.net_state_classified, inner.classified_schemas)

  -- 补发 AttachClassified 之前丢失的 dirty 事件
  if net_state_classified._pending_dirty_keys then
    for key, _ in pairs(net_state_classified._pending_dirty_keys) do
      local dirty_event = getDirtyName(key)
      inner.log("AttachClassified", "re-pushing pending dirty for", key)
      net_state_classified:PushEvent(dirty_event)
    end
    net_state_classified._pending_dirty_keys = nil
  end
  if net_state_classified._pending_force_dirty then
    inner.log("AttachClassified", "re-pushing pending force dirty")
    net_state_classified:PushEvent(inner._force_dirty_event)
    net_state_classified._pending_force_dirty = nil
  end

  -- 恢复缓存值
  if inner._classified_cache then
    inner.log("AttachClassified", "restoring cached values")
    if inner._classified_vars then
      for key, value in pairs(inner._classified_cache) do
        local netvar = inner._classified_vars[key]
        if netvar then
          if TheWorld.ismastersim then
            netvar:set(value)
          else
            netvar:set_local(value)
          end
        end
      end
    end
    inner._classified_cache = nil
  end
  inner.log("AttachClassified", "complete")
  if inner._on_attached and not skip_attach then
    inner._on_attached(ThePlayer)
  end
end

--- 客户端：当 classified 实体被销毁时调用
function NetState:DetachClassified()
  local inner = NetStateMap[self]
  if inner._classified_detached then
    return
  end
  inner._classified_detached = true
  inner.log("DetachClassified")
  inner._force_var = nil
  inner.net_state_classified = nil
  inner._classified_vars = nil
  if inner._on_detached then
    inner._on_detached(ThePlayer)
  end
end

--- 强制同步：即使字段值未变化，也让监听端触发一次该 state 的字段更新事件。
function NetState:ForceSync()
  local inner = NetStateMap[self]
  if not TheWorld.ismastersim then
    inner.log("ForceSync", "ignored on non-master")
    return
  end
  local force_var = inner._force_var
  if force_var == nil then
    inner.log("ForceSync", "force var unavailable")
    return
  end
  local next_value = force_var:value() + 1
  if next_value > 4294967295 then
    next_value = 0
  end
  inner.log("ForceSync", "tick", next_value)
  force_var:set(next_value)
end

--- 主机端：手动控制 classified 的目标玩家
--- 可见性规则（与客机一致）：
--- - SetClassifiedTarget(nil) = 开放给所有人可见
--- - SetClassifiedTarget(player) = 只有该 player 可见
--- - SetClassifiedTarget(self.inst) = 所有玩家不可见（假设 self.inst 不是玩家）
--- 事件触发规则（与客机一致）：
--- - 只有主机玩家（ThePlayer）的可见权限变更才会触发 attach/detached
--- - nil -> player 不会对主机玩家触发 attach（除非 player == ThePlayer）
function NetState:Attach(target)
  local inner = NetStateMap[self]
  if not TheWorld.ismastersim then
    inner.log("Attach", "not master sim")
    return
  end
  local old_target = inner.attach_target
  if target == old_target then
    inner.log("Attach", "target not changed", target)
    return
  end
  if not inner.net_state_classified then
    inner.log("Attach", "classified not initialized")
    return
  end
  -- 设置 classified 的目标玩家（客户端会收到该实体）
  inner.log("Attach", "attaching classified to target", target, inner._def_name)
  if inner.attach_task then
    inner.attach_task:Cancel()
    inner.attach_task = nil
  end
  inner.attach_task = inner.inst:DoTaskInTime(0, function()
    inner.attach_task = nil
    if target ~= nil and not target:IsValid() then
      return
    end
    inner.log("Attach", "attaching classified to target task", target, inner._def_name)
    inner.net_state_classified.Network:SetClassifiedTarget(target)
    PushDirtyForNonDefaultClassified(inner)
  end)

  -- 计算主机玩家（ThePlayer）的可见性变更
  -- old_visible: 主机玩家之前是否可见
  -- new_visible: 主机玩家现在是否可见
  local function is_visible_to_host(t)
    -- nil = 所有人可见，包括主机玩家
    -- ThePlayer = 只有主机玩家可见
    -- 其他玩家 = 主机玩家不可见
    -- self.inst（假设不是玩家）= 所有人不可见
    return t == nil or t == ThePlayer
  end

  local old_visible = is_visible_to_host(old_target)
  local new_visible = is_visible_to_host(target)

  -- 只有可见性发生变更时才触发事件（与客机逻辑一致）
  if old_visible and not new_visible then
    -- 从可见变为不可见 -> detached
    if inner._on_detached then
      inner._on_detached(ThePlayer)
    end
  elseif not old_visible and new_visible then
    -- 从不可见变为可见 -> attached
    if inner._on_attached then
      inner._on_attached(ThePlayer)
    end
  end
  -- 可见性未变（如 nil -> nil 或 player1 -> player2 其中都不是 ThePlayer）不触发任何事件

  inner.attach_target = target
end

--- 注册字段变化监听
-- @param keys string 或 string[]
-- @param fn function(NetState)
function NetState:Watch(keys, fn)
  local inner = NetStateMap[self]
  if type(keys) == "string" then
    keys = {keys}
  end
  local seen = {}
  local unique_keys = {}
  for _, k in ipairs(keys) do
    if not seen[k] then
      seen[k] = true
      table.insert(unique_keys, k)
    end
  end
  keys = unique_keys
  -- 包装共享回调
  local update_task = nil
  local wrapped_fn = function()
    if update_task then
      return
    end
    update_task = inner.inst:DoTaskInTime(0, function()
      update_task = nil
      if inner.inst:IsValid() then
        fn(self)
      end
    end)
  end
  inner.log("Watch", "packaged wrapped_fn for keys:", keys)
  for _, key in ipairs(keys) do
    if inner.normal_schemas[key] then
      DoListenForKey(inner.inst, key, wrapped_fn)
      inner.log("Watch", "attached normal listener for", key)
    elseif inner.classified_schemas[key] then
      if inner.net_state_classified then
        DoListenForKey(inner.net_state_classified, key, wrapped_fn)
        inner.log("Watch", "attached classified listener (immediate) for", key)
      end
      table.insert(inner._pending_classified_listeners, {
        key = key,
        fn = wrapped_fn
      })
      inner.log("Watch", "pending classified listener for", key)
    else
      inner.log("Watch", "unknown key", key)
    end
  end
end

-------------------------------------------------------------------------------
-- 元方法：支持 state.key / state.key = value 语法
-------------------------------------------------------------------------------

local function __index(t, k)
  local inner = NetStateMap[t]
  if inner == nil then
    -- 未初始化，返回类方法
    return getmetatable(t)[k]
  end

  -- 1. 普通字段（normal）
  local normal = inner.normal_schemas
  if normal ~= nil and normal[k] ~= nil then
    local vars = inner._vars
    if vars ~= nil and vars[k] ~= nil then
      return vars[k]:value()
    end
    return TYPE_DEFAULT_VALUE[normal[k].type]
  end

  -- 2. Classified 字段
  local classified_schemas = inner.classified_schemas
  if classified_schemas ~= nil and classified_schemas[k] ~= nil then
    -- 优先从已绑定的 netvar 读取
    local cvars = inner._classified_vars
    if cvars ~= nil and cvars[k] ~= nil then
      return cvars[k]:value()
    end
    -- 其次从本地缓存读取（Attach 前的写入）
    local cache = inner._classified_cache
    if cache ~= nil and cache[k] ~= nil then
      return cache[k]
    end
    -- 最后返回默认值
    return TYPE_DEFAULT_VALUE[classified_schemas[k].type]
  end

  -- 3. 非 schema 字段：访问类方法
  return getmetatable(t)[k]
end

local function __newindex(t, k, v)
  local inner = NetStateMap[t]
  if inner == nil then
    -- 未初始化，直接写入实例（不应发生）
    rawset(t, k, v)
    return
  end

  -- 1. 普通字段写入
  local normal = inner.normal_schemas
  if normal ~= nil and normal[k] ~= nil then
    local vars = inner._vars
    if vars ~= nil and vars[k] ~= nil then
      -- 只有服务器才真正修改 net 变量；set 自带 dirty 事件
      if TheWorld.ismastersim then
        vars[k]:set(v)
      else
        vars[k]:set_local(v)
      end
      return
    end
    return
  end

  -- 2. Classified 字段写入
  local classified_schemas = inner.classified_schemas
  if classified_schemas ~= nil and classified_schemas[k] ~= nil then
    local cvars = inner._classified_vars
    local netvar = (cvars ~= nil) and cvars[k] or nil
    if netvar ~= nil then
      if TheWorld.ismastersim then
        netvar:set(v)
      else
        netvar:set_local(v)
      end
      return
    else
      -- 尚未 AttachClassified，缓存起来待用
      local cache = inner._classified_cache
      if cache == nil then
        cache = {}
        inner._classified_cache = cache
      end
      cache[k] = v
      return
    end
  end

  -- 3. 非 schema 字段：直接写入实例
  rawset(t, k, v)
end

NetState.__index = __index
NetState.__newindex = __newindex

-- 暴露到全局
GLOBAL.DefineNetState = DefineNetState
GLOBAL.NetState = NetState
return NetState
