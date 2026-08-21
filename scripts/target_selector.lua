-- ════════════════════════════════════════════════════════
-- 目标选择器框架（替代 ark_aoe_selector）
-- 类体系：TargetSelector(父，纯类型基类) → AreaTargetSelector(子，aoe 实现)
-- 注册：RegisterTargetSelector(id, AreaTargetSelector {...}) —— 声明式，主客机共享段执行
-- 使用：GetTargetSelector(id):BeginSelecting(doer, okfn, cancelfn)
-- 同步：只同步 selector id（net_string），两端各自查注册表拿到实例（含函数字段）
-- 父类不实现任何行为：开始/停止/装配由各子类单独实现（本例为 aoe）
-- GLOBAL 导出：TargetSelector / AreaTargetSelector / RegisterTargetSelector / GetTargetSelector / StopTargetSelecting
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
  -- 公共视觉（默认值对齐原 ark_aoe_selector）
  self.reticuleprefab = config.reticuleprefab or "reticule"     -- 瞄准圈外观
  self.pingprefab     = config.pingprefab     or "reticuleping" -- 落点确认特效
  self.validcolour    = config.validcolour    or { 1, 0.75, 0, 1 }  -- 合法时颜色
  self.invalidcolour  = config.invalidcolour  or { 0.5, 0, 0, 1 }    -- 非法时颜色
  self.mouseenabled   = config.mouseenabled ~= false -- 默认 true：RefreshReticule 依此创建瞄准圈
  self.ease           = config.ease ~= false          -- 默认 true
  self.twinstickmode  = config.twinstickmode or 1
  self.twinstickrange = config.twinstickrange or 8
  -- aoe 专属
  self.range        = config.range        or 8   -- 范围半径
  self.deployradius = config.deployradius or 1   -- 部署间距
  self.validfn      = config.validfn             -- 范围有效性判定（返回 false 显示非法）
end)

-- 开始选择（aoe 专属）：创建运行实体，同步 id，装配确认/取消回调
-- okfn(doer, pos) / cancelfn(doer) 均可缺省（nil 时不回调）
function AreaTargetSelector:BeginSelecting(doer, okfn, cancelfn)
  self:StopSelecting(doer) -- 清理上次残留

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
  aoe.range        = self.range
  aoe.deployradius = self.deployradius
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

-- 全局便捷：结束当前选择（aoe 通过 doer 上存的实例转发；其他选择器实现各自接入）
function GLOBAL.StopTargetSelecting(doer)
  local obj = doer._now_target_selector_obj
  if obj and obj.StopSelecting then
    obj:StopSelecting(doer)
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
    if inst._cancelfn then
      inst._cancelfn(player)
    end
    StopTargetSelecting(player)
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
      return "ark_aoe_select"
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
