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
  self.validfn       = config.validfn             -- 范围有效性判定（返回 false 显示非法）
  self.targetposfn   = config.targetposfn         -- 候选坐标规范化（网格吸附等），主客机都应用
  self.reticulescale = config.reticulescale       -- 指示器视觉缩放倍率；不影响 ping 与实际落点
end)

function AreaTargetSelector:TransformTargetPos(runtime, pos)
  if pos == nil or self.targetposfn == nil then
    return pos
  end
  return self.targetposfn(runtime, pos) or pos
end

-- ────────────────────────────────────────────────────────
-- 地图子类：打开原版地图，通过 map_only action 选择世界坐标
-- validfn(doer, pos, runtime) 在客户端用于地图反馈，服务端再次权威校验。
-- 未提供 validfn 时，可用 targetprefab/targettags + mapiconprefab/mapicontag
-- 直接实现“点击地图代理选择实体”；确认回调收到 (doer, pos, target)。
-- ────────────────────────────────────────────────────────
local MapTargetSelector = Class(TargetSelector, function(self, config)
  TargetSelector._ctor(self, config)
  config = config or {}
  self.validfn = config.validfn
  self.actionstring = config.actionstring
  -- 地图实体选择：客户端用全局地图图标代理，服务端用真实实体解析。
  self.targetfn = config.targetfn
  self.targetprefab = config.targetprefab
  self.targettags = config.targettags
  self.targetrange = config.targetrange or 1.5
  self.mapiconprefab = config.mapiconprefab
  self.mapicontag = config.mapicontag
  self.mapfocus = config.mapfocus
  if self.mapfocus ~= nil then
    -- 原版地图焦点装饰的通用默认动画；配置通常只需提供 bank/build。
    self.mapfocus.anim = self.mapfocus.anim or "idle"
    self.mapfocus.gainfocus = self.mapfocus.gainfocus or { "proximity_pre", "proximity_loop" }
    self.mapfocus.losefocus = self.mapfocus.losefocus or { "proximity_pst", "idle" }
    self.mapfocus.zoomradius = self.mapfocus.zoomradius or self.targetrange
    self.mapfocus.scale = self.mapfocus.scale or 1
  end
end)

function MapTargetSelector:FindTarget(doer, pos, runtime)
  if self.targetfn ~= nil then
    return self.targetfn(doer, pos, runtime)
  end

  local range = self.targetrange
  local x, _, z = pos:Get()
  if TheWorld.ismastersim then
    local ents = TheSim:FindEntities(x, 0, z, range, self.targettags, nil)
    local closest, closestdsq
    for _, ent in ipairs(ents) do
      if (self.targetprefab == nil or ent.prefab == self.targetprefab) and ent:IsValid() then
        local ex, _, ez = ent.Transform:GetWorldPosition()
        local dx, dz = ex - x, ez - z
        local dsq = dx * dx + dz * dz
        if closestdsq == nil or dsq < closestdsq then
          closest, closestdsq = ent, dsq
        end
      end
    end
    return closest
  end

  -- 客户端通常只有 globalmapicon 代理，没有远处的真实目标实体。
  if self.mapiconprefab == nil or GlobalMapIconsDB == nil then
    return nil
  end
  local icons = GlobalMapIconsDB.prefabs[self.mapiconprefab]
  if icons == nil then
    return nil
  end
  local closest, closestdsq
  for icon in pairs(icons) do
    if icon:IsValid() and (self.mapicontag == nil or icon:HasTag(self.mapicontag)) then
      local ix, _, iz = icon.Transform:GetWorldPosition()
      local dx, dz = ix - x, iz - z
      local dsq = dx * dx + dz * dz
      if dsq <= range * range and (closestdsq == nil or dsq < closestdsq) then
        closest, closestdsq = icon, dsq
      end
    end
  end
  return closest
end

function MapTargetSelector:IsValidPosition(doer, pos, runtime)
  if self.validfn ~= nil then
    return self.validfn(doer, pos, runtime)
  end
  local target = self:FindTarget(doer, pos, runtime)
  if target == nil then
    return false, "NOTARGET"
  end
  local x, _, z = target.Transform:GetWorldPosition()
  return true, nil, x, z, target
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
  aoe.reticule.mousetargetfn  = self.targetposfn ~= nil and function(runtime, pos)
    return self:TransformTargetPos(runtime, pos)
  end or nil
  if self.reticulescale ~= nil then
    local scale = self.reticulescale
    aoe.reticule.updatepositionfn = function(_, pos, fx, ease)
      fx.Transform:SetPosition(pos.x, 0, pos.z)
      -- Reticule:UpdatePosition 会传 ease；PingReticuleAt 只传前三个参数，故不缩放 ping。
      if ease ~= nil then
        fx.Transform:SetScale(scale, scale, scale)
      end
    end
  end
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
  local valid, reason, x, z, target = selector:IsValidPosition(act.doer, pos, runtime)
  if not valid then
    return false, reason
  end
  return true, reason, x or pos.x, z or pos.z, target
end

local MAP_SELECT_ACTION = AddAction("ARK_TARGET_SELECT_MAP", "Select", function(act)
  local valid, reason, x, z, target = ValidateMapSelection(act)
  if not valid then
    return false, reason
  end

  local selector, runtime = GetMapSelectorFromAction(act)
  runtime._confirmed:set(true)
  if runtime._okfn ~= nil then
    runtime._okfn(act.doer, Vector3(x, 0, z), target)
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

-- 可选地图焦点动画：只有 selector 配置了 mapfocus 才给候选地图图标增加 UIAnim。
-- 这里扩展原版 MapScreen 的通用生命周期，不为任何角色写分支。
local MAP_SELECTOR_DECORATION_PREFIX = "_ark_map_selector_"

local function PlayMapSelectorAnim(decoration, animations)
  if type(animations) == "string" then
    animations = { animations }
  end
  if type(animations) ~= "table" or #animations == 0 then
    return
  end
  local animstate = decoration:GetAnimState()
  animstate:PlayAnimation(animations[1], true)
  for i = 2, #animations do
    animstate:PushAnimation(animations[i])
  end
end

local function RemoveMapSelectorDecorations(mapscreen)
  local staticdecorations = mapscreen.decorationdata and mapscreen.decorationdata.staticdecorations
  if staticdecorations == nil then
    return
  end
  for id, decorationdata in pairs(staticdecorations) do
    if string.sub(id, 1, #MAP_SELECTOR_DECORATION_PREFIX) == MAP_SELECTOR_DECORATION_PREFIX then
      if decorationdata.decoration ~= nil then
        decorationdata.decoration:Kill()
      end
      staticdecorations[id] = nil
    end
  end
end

local function GetMapSelectorForScreen(mapscreen)
  local runtime = mapscreen.maptarget
  if runtime == nil or not runtime:IsValid() or runtime.prefab ~= "map_target_selector" then
    return nil
  end
  local id = runtime._selector_id:value()
  local selector = id ~= "" and GetTargetSelector(id) or nil
  return selector ~= nil and MapTargetSelector.is_instance(selector) and selector or nil
end

local function ApplyMapSelectorDecorationScale(decorationdata, zoomscale)
  local zoomscale_clamped = math.clamp(zoomscale, decorationdata.minzoomscale, decorationdata.maxzoomscale)
  local scale = decorationdata.scale or 1
  decorationdata.decoration:SetScale(
    zoomscale_clamped * decorationdata.overallzoomscaler * scale,
    zoomscale_clamped * decorationdata.overallzoomscaler * scale,
    1)
end

local function ProcessMapSelectorStaticDecorations(mapscreen, staticdecorations, zoomscale, w, h)
  local selector = GetMapSelectorForScreen(mapscreen)
  local focus = selector ~= nil and selector.mapfocus or nil
  local prefab = focus ~= nil and (focus.mapiconprefab or selector.mapiconprefab) or nil
  if focus == nil or prefab == nil or focus.bank == nil or focus.build == nil
      or GlobalMapIconsDB == nil or GlobalMapIconsDB.prefabs[prefab] == nil then
    return
  end

  local icons = GlobalMapIconsDB.prefabs[prefab]
  local tag = focus.mapicontag or selector.mapicontag
  mapscreen.decorationdata.alwaysdirty = true
  for ent in pairs(icons) do
    if ent:IsValid() and (tag == nil or ent:HasTag(tag)) then
      local id = MAP_SELECTOR_DECORATION_PREFIX .. tostring(ent.GUID)
      if staticdecorations[id] == nil then
        local x, y, z = ent.Transform:GetWorldPosition()
        local decoration = mapscreen.decorationrootstatic:AddChild(require("widgets/uianim")())
        local data = {
          ent = ent,
          decoration = decoration,
          minzoomscale = focus.minzoomscale or 0.18,
          maxzoomscale = focus.maxzoomscale or 0.55,
          overallzoomscaler = focus.overallzoomscaler or 3.6,
          scale = focus.scale or 1,
          zoomradius = focus.zoomradius,
          animgainfocus = focus.gainfocus,
          animlosefocus = focus.losefocus,
        }
        staticdecorations[id] = data
        local animstate = decoration:GetAnimState()
        animstate:SetBank(focus.bank)
        animstate:SetBuild(focus.build)
        PlayMapSelectorAnim(decoration, focus.anim)
        if mapscreen.owner ~= nil and mapscreen.owner.CanSeePointOnMiniMap ~= nil
            and not mapscreen.owner:CanSeePointOnMiniMap(x, y, z) then
          decoration:Hide()
          data.mapicon_hidden = true
        end
        local mapx, mapy = mapscreen.minimap:WorldPosToMapPos(x, z, 0)
        decoration:SetPosition(mapx * w, mapy * h)
        ApplyMapSelectorDecorationScale(data, zoomscale)
      else
        local data = staticdecorations[id]
        local x, y, z = ent.Transform:GetWorldPosition()
        local hidden = mapscreen.owner ~= nil and mapscreen.owner.CanSeePointOnMiniMap ~= nil
          and not mapscreen.owner:CanSeePointOnMiniMap(x, y, z)
        if hidden and not data.mapicon_hidden then
          data.decoration:Hide()
          data.mapicon_hidden = true
        elseif not hidden and data.mapicon_hidden then
          data.decoration:Show()
          data.mapicon_hidden = nil
        end
      end
    end
  end
end

local function FocusMapSelectorDecoration(mapscreen, x, y, z)
  local selector = GetMapSelectorForScreen(mapscreen)
  local focus = selector ~= nil and selector.mapfocus or nil
  if focus == nil or x == nil or z == nil then
    return
  end
  local staticdecorations = mapscreen.decorationdata.staticdecorations
  local nearest, nearestdsq
  local maxdsq = focus.zoomradius ^ 2
  for id, decorationdata in pairs(staticdecorations) do
    if string.sub(id, 1, #MAP_SELECTOR_DECORATION_PREFIX) == MAP_SELECTOR_DECORATION_PREFIX
        and not decorationdata.mapicon_hidden and decorationdata.ent:IsValid() then
      local dsq = decorationdata.ent:GetDistanceSqToPoint(x, y or 0, z)
      if dsq < maxdsq and (nearestdsq == nil or dsq < nearestdsq) then
        nearest, nearestdsq = decorationdata, dsq
      end
    end
  end
  if nearest ~= nil then
    if not nearest.mapfocus then
      PlayMapSelectorAnim(nearest.decoration, nearest.animgainfocus)
    end
    nearest.mapfocus = TheSim:GetStep()
  end
end

AddClassPostConstruct("screens/mapscreen", function(self)
  local _SetNewMapTarget = self.SetNewMapTarget
  self.SetNewMapTarget = function(screen, maptarget, forced_actiondef, ...)
    RemoveMapSelectorDecorations(screen)
    local result = _SetNewMapTarget(screen, maptarget, forced_actiondef, ...)
    -- OpenMapForLocalPlayer 可能在已经打开的地图上切换选择器；确保装饰立即创建。
    if screen.ProcessStaticDecorations ~= nil then
      screen:ProcessStaticDecorations()
    end
    return result
  end

  local _ProcessStaticDecorations_Internal = self.ProcessStaticDecorations_Internal
  self.ProcessStaticDecorations_Internal = function(screen, staticdecorations, zoomscale, w, h, ...)
    _ProcessStaticDecorations_Internal(screen, staticdecorations, zoomscale, w, h, ...)
    ProcessMapSelectorStaticDecorations(screen, staticdecorations, zoomscale, w, h)
  end

  local _UpdateMapActionsDecorations = self.UpdateMapActionsDecorations
  self.UpdateMapActionsDecorations = function(screen, x, y, z, lmb, rmb, ...)
    -- 使用原始鼠标坐标，不能使用已被 selector 吸附到目标中心的 action point。
    -- 必须在原版 UpdateStaticDecorations 前写入 mapfocus，和原版焦点处理保持同一时序。
    FocusMapSelectorDecoration(screen, x, y, z)
    _UpdateMapActionsDecorations(screen, x, y, z, lmb, rmb, ...)
  end

  local _UpdateStaticDecorations = self.UpdateStaticDecorations
  self.UpdateStaticDecorations = function(screen, ...)
    _UpdateStaticDecorations(screen, ...)
    -- 原版每帧会重设 UIAnim 缩放；在其之后恢复 selector 自己的整体倍率。
    local zoomscale = 0.75 / screen.minimap:GetZoom()
    for id, decorationdata in pairs(screen.decorationdata.staticdecorations) do
      if string.sub(id, 1, #MAP_SELECTOR_DECORATION_PREFIX) == MAP_SELECTOR_DECORATION_PREFIX
          and not decorationdata.mapicon_hidden and decorationdata.decoration ~= nil then
        ApplyMapSelectorDecorationScale(decorationdata, zoomscale)
      end
    end
  end
end)

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
    local runtime = act.doer._now_target_selector
    local selector = act.doer._now_target_selector_obj
    local act_post = act:GetActionPoint()
    if selector ~= nil and AreaTargetSelector.is_instance(selector) then
      act_post = selector:TransformTargetPos(runtime, act_post)
    end
    if runtime.components.aoespell:CanCast(act.doer, act_post) then
      return runtime.components.aoespell:CastSpell(act.doer, act_post)
    end
    -- 客户端确认时不会再发送 Cancel RPC；若权威端判定落点无效，在这里主动结束选择，避免残留运行实体。
    if selector ~= nil and AreaTargetSelector.is_instance(selector) then
      selector:StopSelecting(act.doer)
    else
      if runtime:IsValid() then
        runtime:Remove()
      end
      act.doer._now_target_selector = nil
      act.doer._now_target_selector_obj = nil
    end
    return false
  end
  return next(act, ...)
end)

GLOBAL.TargetSelector = TargetSelector
GLOBAL.AreaTargetSelector = AreaTargetSelector
GLOBAL.MapTargetSelector = MapTargetSelector
