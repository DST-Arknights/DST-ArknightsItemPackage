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

-- 生成 NetState 实例的唯一标识 key
-- @param inst 实体实例
-- @param stack_level 调用栈层级，用于获取调用源文件路径
-- @return key 唯一标识字符串, source 源文件路径, idx 同一源文件中的索引
local function GenerateNetStateKey(inst, stack_level)
  local source
  do
    local ok, info = pcall(debug.getinfo, stack_level, "S")
    if ok and info and info.source then
      source = info.source
    else
      source = "UNKNOWN"
    end
  end
  source = source:gsub("\\", "/")

  -- 在 inst 上维护 per-path 递增 idx
  local path_index = inst._ns_path_index
  if path_index == nil then
    path_index = {}
    inst._ns_path_index = path_index
  end
  local idx = (path_index[source] or 0) + 1
  path_index[source] = idx

  local key = source .. "#" .. tostring(idx)
  return key
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
    local constructor = TYPE_MAP[def.type]
    assert(constructor,
      string.format("[NetState] Unknown netvar type '%s' for key '%s'", tostring(def.type), tostring(key)))
    local dirty_event = getDirtyName(key)
    vars[key] = constructor(owner.GUID, "net_state." .. key, dirty_event)
  end
  return vars
end

local function DoListenForKey(inst, key, fn)
  local dirty_event = getDirtyName(key)
  inst:ListenForEvent(dirty_event, fn)
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
local function NetStateInit(self, inst, schema_def)
  local inner = {}
  NetStateMap[self] = inner
  inner.inst = inst
  inner._id = stateId
  stateId = stateId + 1

  -------------------------------------------------------------------------------
  -- 基于“脚本路径 + 定义顺序”的 key：在每个 inst 上保持稳定
  -------------------------------------------------------------------------------
  -- stack_level 5: NetStateInit -> __call -> 调用 NetState(...) 的源文件
  local key = GenerateNetStateKey(inst, 5)
  ArkLogger:Trace('[net_state]', 'NetStateInit', key)
  inner._key = key

  -- 在 inst 上登记 key -> state 的映射（真正用于主客机匹配的 identity）
  local state_by_key = inst._ns_state_by_key
  if state_by_key == nil then
    state_by_key = {}
    inst._ns_state_by_key = state_by_key
  end
  state_by_key[inner._key] = self

  -- 实例专属日志方法：自动携带 GUID 和分类标签
  inner.log = function(category, ...)
    local template = type(category) == "string" and "[NetState:%s][%s]" or "[NetState:%s]"
    ArkLogger:Trace(string.format(template, inner._id, category), ...)
  end

  -- 解析并分离普通字段与 classified 字段
  local full_schema = ParseSchema(schema_def)
  inner.classified_schemas = filterSchema(full_schema, function(def)
    return def.classified
  end)
  inner.normal_schemas = filterSchema(full_schema, function(def)
    return not def.classified
  end)
  inner.log("Init", "binding normal netvars", "key", inner._key)
  inner._vars = bindNetVars(inner, inner.inst, inner.normal_schemas)
  inner._pending_classified_listeners = {}
  -- 若存在 classified 字段，则在主机上生成 classified，在客机上尝试消费 pending
  if next(inner.classified_schemas) then
    if TheWorld.ismastersim then
      -- 主机：立即生成并绑定对应的 classified 实体
      inner.log("Attach", "spawning net_state_classified prefab", inner._key)
      inner.net_state_classified = SpawnPrefab("net_state_classified")
      inner.net_state_classified.entity:SetParent(inner.inst.entity)
      inner.net_state_classified._net_state_key:set(inner._key)
      inner.inst:DoTaskInTime(0, function()
        self:AttachClassified(inner.net_state_classified, true)
        inner.net_state_classified.Network:SetClassifiedTarget(inner.inst)
      end)
    else
      -- 客机：如果 classified 先于 NetStateInit 到达，则 OnEntityReplicated 会把
      -- net_state_classified 放到 inst._ns_pending_classified[key] 里。
      -- 这里在初始化完成后主动检查并尝试完成绑定。
      local pending = inner.inst._ns_pending_classified
      if pending ~= nil then
        local classified = pending[inner._key]
        if classified ~= nil and classified:IsValid() then
          pending[inner._key] = nil
          classified._state = self
          inner.log("AttachClassified", "attach from pending", inner._key)
          self:AttachClassified(classified)
        end
      end
    end
  end
end

-- 支持 NetState(inst, schema) 语法创建实例
setmetatable(NetState, {
  __call = function(cls, inst, schema_def)
    local self = setmetatable({}, cls)
    NetStateInit(self, inst, schema_def)
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
  inner.log("AttachClassified", "begin")
  inner.net_state_classified = net_state_classified
  -- 注册所有 pending 的 classified 监听
  if inner._pending_classified_listeners and #inner._pending_classified_listeners > 0 then
    inner.log("AttachClassified", "registering", #inner._pending_classified_listeners, "classified listeners")
    for _, item in ipairs(inner._pending_classified_listeners) do
      DoListenForKey(inner.net_state_classified, item.key, item.fn)
      inner.log("Watch", "attached classified listener for", item.key)
    end
  end
  inner._classified_vars = bindNetVars(inner, inner.net_state_classified, inner.classified_schemas)
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
  if inner._on_attached and not skip_attach then
    inner._on_attached(ThePlayer)
  end
  inner.log("AttachClassified", "complete")
end

--- 客户端：当 classified 实体被销毁时调用
function NetState:DetachClassified()
  local inner = NetStateMap[self]
  inner.log("DetachClassified")
  inner.net_state_classified = nil
  inner._classified_vars = nil
  if inner._on_detached then
    inner._on_detached(ThePlayer)
  end
end

--- 主机端：手动控制 classified 的目标玩家
function NetState:Attach(target)
  if not TheWorld.ismastersim then
    return
  end
  local inner = NetStateMap[self]
  inner.attach_task = inner.inst:DoTaskInTime(0, function()
    -- 设置 classified 的目标玩家（客户端会收到该实体）
    inner.log("Attach", "attaching classified to player", target, inner._key)
    inner.net_state_classified.Network:SetClassifiedTarget(target)
    -- 主机没有AttachClassified，立即attach
    if not TheNet:IsDedicated() then
      if target == ThePlayer and inner._on_attached then
        inner._on_attached(target)
      end
      if target ~= nil and target ~= ThePlayer and inner._on_detached then
        inner._on_detached(target)
      end
    end
    inner.attach_task = nil
  end)
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
GLOBAL.NetState = NetState
return NetState
