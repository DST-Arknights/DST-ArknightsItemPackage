-- ════════════════════════════════════════════════════════
-- 目标选择器框架
-- 类体系：TargetSelector(父，纯类型基类) → AreaTargetSelector / MapTargetSelector
-- 注册：RegisterTargetSelector(id, XxxTargetSelector {...}) —— 声明式，主客机共享段执行
-- 使用：GetTargetSelector(id):BeginSelecting(doer, okfn, cancelfn)
-- 同步：只同步 selector id（net_string），两端各自查注册表拿到实例（含函数字段）
-- 父类不实现任何行为：开始/停止/装配由各子类单独实现
-- GLOBAL 导出：TargetSelector / AreaTargetSelector / MapTargetSelector /
--              RegisterTargetSelector / GetTargetSelector
-- ════════════════════════════════════════════════════════

local SELECTORS = {}

-- ────────────────────────────────────────────────────────
-- 父类：纯类型基类，不实现任何行为
-- ────────────────────────────────────────────────────────
local TargetSelector = Class(function(self, config)
end)

-- ────────────────────────────────────────────────────────
-- aoe 子类：持有全部配置字段 + 开始/停止/装配
-- ────────────────────────────────────────────────────────
local AreaTargetSelector = Class(TargetSelector, function(self, config)
  TargetSelector._ctor(self, config)
  config = config or {}
  -- 公共视觉（沿用旧 AOE 选择器默认值）
  self.reticuleprefab = config.reticuleprefab or "reticule"     -- 瞄准圈外观
  self.pingprefab     = config.pingprefab     or "reticuleping" -- 落点确认特效
  self.validcolour    = config.validcolour    or { 1, 0.75, 0, 1 }  -- 合法时颜色
  self.invalidcolour  = config.invalidcolour  or { 0.5, 0, 0, 1 }    -- 非法时颜色
  self.mouseenabled   = config.mouseenabled ~= false -- 默认 true：RefreshReticule 依此创建瞄准圈
  self.ease           = config.ease ~= false          -- 默认 true
  self.twinstickmode  = config.twinstickmode or 1
  self.twinstickrange = config.twinstickrange or config.range or 8
  -- aoe 专属
  self.range        = config.range        or 8   -- 范围半径
  self.deployradius = config.deployradius or 1   -- 部署间距
  self.validfn      = config.validfn             -- 范围有效性判定（返回 false 显示非法）
end)

-- ────────────────────────────────────────────────────────
-- 地图子类：打开原版地图，通过 map_only action 选择世界坐标
-- validfn(doer, pos, runtime) 在客户端用于地图反馈，服务端再次权威校验。
-- ────────────────────────────────────────────────────────
local MapTargetSelector = Class(TargetSelector, function(self, config)
  TargetSelector._ctor(self, config)
  config = config or {}
  self.validfn = config.validfn
  self.actionstring = config.actionstring
end)

function MapTargetSelector:IsValidPosition(doer, pos, runtime)
  if self.validfn ~= nil then
    return self.validfn(doer, pos, runtime)
  end
  return true
end

function MapTargetSelector:GetActionString(act)
  if type(self.actionstring) == "function" then
    return self.actionstring(act)
  end
  return self.actionstring
end

function MapTargetSelector:BeginSelecting(doer, okfn, cancelfn)
  local current = doer._now_target_selector_obj
  if current ~= nil then
    current:StopSelecting(doer)
  end

  local runtime = SpawnPrefab("map_target_selector")
  if runtime == nil then
    return false
  end

  runtime._owner = doer
  runtime._okfn = okfn
  runtime._cancelfn = cancelfn
  runtime._selector_obj = self
  runtime._selector_id:set(self.id)
  runtime.entity:SetParent(doer.entity)
  runtime.Network:SetClassifiedTarget(doer)

  runtime.CancelSelection = function(inst, player)
    if inst._owner ~= player or inst._confirmed:value() then
      return
    end
    if inst._cancelfn ~= nil then
      inst._cancelfn(player)
    end
    self:StopSelecting(player)
  end

  doer._now_target_selector = runtime
  doer._now_target_selector_obj = self

  -- 单机/主机没有客户端副本的 dirty 事件，直接打开本地地图。
  if doer.HUD ~= nil and runtime.OpenMapForLocalPlayer ~= nil then
    runtime:OpenMapForLocalPlayer()
  end
  return true
end

function MapTargetSelector:StopSelecting(doer)
  local runtime = doer._now_target_selector
  if runtime ~= nil and runtime:IsValid() then
    runtime:Remove()
  end
  doer._now_target_selector = nil
  doer._now_target_selector_obj = nil
end

-- 开始选择（aoe 专属）：创建运行实体，同步 id，装配确认/取消回调
-- okfn(doer, pos) / cancelfn(doer) 均可缺省（nil 时不回调）
function AreaTargetSelector:BeginSelecting(doer, okfn, cancelfn)
  local current = doer._now_target_selector_obj
  if current ~= nil then
    current:StopSelecting(doer)
  end

  local selector = SpawnPrefab("area_target_selector")
  if selector == nil then
    return false
  end

  selector._owner = doer       -- 服务端字段：确认取消时校验归属玩家
  selector._okfn = okfn
  selector._cancelfn = cancelfn
  selector._selector_id:set(self.id)

  -- 确认：玩家选定位置 → aoespell:CastSpell → 此处回调
  selector.components.aoespell:SetSpellFn(function(inst, owner, pos)
    selector._confirmed:set(true) -- 先标记确认，避免取消 RPC 误判
    if okfn then
      okfn(owner, pos)
    end
    self:StopSelecting(owner)
  end)

  doer._now_target_selector = selector
  doer._now_target_selector_obj = self
  selector.entity:SetParent(doer.entity)
  selector.Network:SetClassifiedTarget(doer)
  return true
end

-- 停止选择（aoe 专属）：移除运行实体并清空玩家引用
function AreaTargetSelector:StopSelecting(doer)
  local selector = doer._now_target_selector
  if selector then
    if selector:IsValid() then
      selector:Remove()
    end
    doer._now_target_selector = nil
  end
  doer._now_target_selector_obj = nil
  -- 若玩家还停留在选择状态，回到 idle
  if doer.sg and doer.sg.currentstate and doer.sg.currentstate.name == "target_selector_select" then
    doer.sg:GoToState("idle")
  end
end

-- 客户端：收到 id 后把实例字段装配到选择器实体（aoe 专属）
function AreaTargetSelector:ApplyToEntity(selector)
  local aoe = selector.components.aoetargeting
  aoe.reticule.reticuleprefab = self.reticuleprefab
  aoe.reticule.pingprefab     = self.pingprefab
  aoe.reticule.validcolour    = self.validcolour
  aoe.reticule.invalidcolour  = self.invalidcolour
  aoe.reticule.mouseenabled   = self.mouseenabled
  aoe.reticule.ease           = self.ease
  aoe.reticule.twinstickmode  = self.twinstickmode
  aoe.reticule.twinstickrange = self.twinstickrange
  aoe.reticule.validfn        = self.validfn
  aoe:SetRange(self.range)
  aoe:SetDeployRadius(self.deployradius)
end

-- ────────────────────────────────────────────────────────
-- 注册表
-- ────────────────────────────────────────────────────────
function GLOBAL.RegisterTargetSelector(id, selector)
  assert(id, "target selector id required")
  assert(selector, "target selector instance required for: " .. tostring(id))
  assert(SELECTORS[id] == nil, "target selector already registered: " .. tostring(id))
  selector.id = id
  SELECTORS[id] = selector
end

function GLOBAL.GetTargetSelector(id)
  return SELECTORS[id]
end

local function GetMapSelectorFromAction(act)
  local runtime = act ~= nil and act.target or nil
  if runtime == nil or not runtime:IsValid() or runtime.prefab ~= "map_target_selector" then
    return nil, nil
  end
  local doer = act.doer
  if doer == nil or (runtime._owner ~= doer and runtime.entity:GetParent() ~= doer) then
    return nil, nil
  end
  local id = runtime._selector_id:value()
  local selector = id ~= "" and GetTargetSelector(id) or nil
  if selector == nil or not MapTargetSelector.is_instance(selector) then
    return nil, nil
  end
  return selector, runtime
end

local function ValidateMapSelection(act)
  local selector, runtime = GetMapSelectorFromAction(act)
  if selector == nil then
    return false
  end
  local pos = act:GetActionPoint()
  if pos == nil then
    return false
  end
  local valid, reason, x, z = selector:IsValidPosition(act.doer, pos, runtime)
  if not valid then
    return false, reason
  end
  return true, reason, x or pos.x, z or pos.z
end

local MAP_SELECT_ACTION = AddAction("ARK_TARGET_SELECT_MAP", "Select", function(act)
  local valid, reason, x, z = ValidateMapSelection(act)
  if not valid then
    return false, reason
  end

  local selector, runtime = GetMapSelectorFromAction(act)
  runtime._confirmed:set(true)
  if runtime._okfn ~= nil then
    runtime._okfn(act.doer, Vector3(x, 0, z))
  end
  selector:StopSelecting(act.doer)
  return true
end)
MAP_SELECT_ACTION.priority = 10
MAP_SELECT_ACTION.instant = true
MAP_SELECT_ACTION.mount_valid = true
MAP_SELECT_ACTION.map_only = true

MAP_SELECT_ACTION.maponly_checkvalidpos_fn = ValidateMapSelection
MAP_SELECT_ACTION.stroverridefn = function(act)
  local selector = GetMapSelectorFromAction(act)
  return selector ~= nil and selector:GetActionString(act) or nil
end

-- closes_map 不能直接启用：MapScreen 会先对 maptarget 发 cancelmaptarget，
-- 再发送地图动作 RPC。这里先摘除 maptarget 后主动关闭，避免成功选择被当成取消。
MAP_SELECT_ACTION.pre_action_cb = function(act)
  local doer = act.doer
  if doer == nil or doer.HUD == nil or not doer.HUD:IsMapScreenOpen() then
    return
  end
  local mapscreen = TheFrontEnd:GetActiveScreen()
  if mapscreen ~= nil and mapscreen.maptarget == act.target then
    mapscreen.maptarget = nil
    mapscreen.forced_actiondef = nil
    mapscreen:SetHandleLmbUp(false)
  end
  TheFrontEnd:PopScreen()
  if doer.components.playercontroller ~= nil then
    doer.components.playercontroller._hack_ignore_held_controls = 0.1
    doer.components.playercontroller._hack_ignore_ups_for = {}
  end
end

-- 取消 RPC：客户端在玩家取消瞄准（ESC/右键）时通知服务端
AddModRPCHandler("arkTargetSelector", "Cancel", function(player, guid)
  local inst = Ents[guid]
  if inst == nil or not inst:IsValid() or inst._owner ~= player then
    return
  end
  -- 已确认（玩家选定后）则忽略；否则视为放弃
  if not inst._confirmed:value() then
    if inst.CancelSelection ~= nil then
      inst:CancelSelection(player)
    else
      if inst._cancelfn ~= nil then
        inst._cancelfn(player)
      end
      local selector = player._now_target_selector_obj
      if selector ~= nil then
        selector:StopSelecting(player)
      end
    end
  end
end)

-- ────────────────────────────────────────────────────────
-- 装配（aoe 专属）：SG 状态 + CASTAOE 动作钩子
-- 状态名 target_selector_select：确认选择时玩家进入该状态执行确认动作，
-- 结束后由 StopSelecting 回到 idle
-- ────────────────────────────────────────────────────────
AddStategraphState("wilson", State {
  name = "target_selector_select",
  onenter = function(inst)
    inst:PerformBufferedAction()
  end,
})

AddStategraphState("wilson_client", State {
  name = "target_selector_select",
  onenter = function(inst)
    inst.components.locomotor:Stop()
    inst:PerformPreviewBufferedAction()
  end,
})

local function HookWilsonSg(sg)
  local actionhandlers = sg.actionhandlers
  ArkHookFunction(actionhandlers[ACTIONS.CASTAOE], "deststate", function(next, inst, action, ...)
    if inst._now_target_selector then
      return "target_selector_select"
    end
    return next(inst, action, ...)
  end)
end

AddStategraphPostInit("wilson", HookWilsonSg)
AddStategraphPostInit("wilson_client", HookWilsonSg)

ArkHookFunction(ACTIONS.CASTAOE, "stroverridefn", function(next, act, ...)
  if act.doer._now_target_selector then
    return act.doer._now_target_selector.components.spellbook:GetSpellName()
  end
  return next(act, ...)
end)

ArkHookFunction(ACTIONS.CASTAOE, "fn", function(next, act, ...)
  if act.doer._now_target_selector then
    local act_post = act:GetActionPoint()
    local selector = act.doer._now_target_selector
    if selector.components.aoespell:CanCast(act.doer, act_post) then
      return selector.components.aoespell:CastSpell(act.doer, act_post)
    end
    return false
  end
  return next(act, ...)
end)

GLOBAL.TargetSelector = TargetSelector
GLOBAL.AreaTargetSelector = AreaTargetSelector
GLOBAL.MapTargetSelector = MapTargetSelector
