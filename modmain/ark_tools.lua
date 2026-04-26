
local function Chronological(a, b)
	return a.time < b.time
end
-- PatchTimeEvent(time, fn)
-- 描述一个对 timeline 的补丁事件。
-- time: 时间（秒，与 TimeEvent 一致，通常用 N * FRAMES）
-- fn: function(next, inst)，next 为该时间点原有函数（默认 noop），调用方决定是否/何时调用
GLOBAL.PatchTimeEvent = Class(function(self, time, fn)
  print("PatchTimeEvent", time, fn)
  assert(type(time) == "number")
  assert(type(fn) == "function")
  self.time = time
  self.fn = fn
end)

-- PatchSgTimeline(timeline, patches)
-- 将一组 PatchTimeEvent 合并进 timeline。
-- 若该时间点已有事件，则包装其 fn（next 指向原函数）；否则插入新 TimeEvent（next 为 noop）。
function GLOBAL.PatchSgTimeline(timeline, patches)
  local noop = function() end
  for _, patch in ipairs(patches) do
    local existing = nil
    for _, ev in ipairs(timeline) do
      if ev.time == patch.time then
        existing = ev
        break
      end
    end

    local fn = patch.fn
    if existing ~= nil then
      local prev = existing.fn or noop
      existing.fn = function(inst)
        return fn(prev, inst)
      end
    else
      table.insert(timeline, TimeEvent(patch.time, function(inst)
        return fn(noop, inst)
      end))
    end
  end

  table.sort(timeline, Chronological)
end

function GLOBAL.IsSGPunchAttack(inst)
    -- 骑乘判断（优先服务端 components，回退客户端 replica）
    local rider = inst.components.rider or inst.replica.rider
    if rider ~= nil and rider:IsRiding() then
        return false
    end
    -- 海狸/巨鹿形态走各自分支
    if inst:HasTag("beaver") or inst:HasTag("weremoose") then
        return false
    end
    -- 获取手持装备（优先服务端 components，回退客户端 replica）
    local inventory = inst.components.inventory or inst.replica.inventory
    local equip = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    -- 空手直接走 punch
    if equip == nil then
        return true
    end
    -- 武器判断（优先服务端 components.weapon，回退客户端 replica.inventoryitem:IsWeapon()）
    local isweapon = (equip.components.weapon ~= nil)
        or (equip.replica.inventoryitem ~= nil and equip.replica.inventoryitem:IsWeapon())
    -- 以下任意条件命中，走对应武器分支，不是 punch
    if equip:HasTag("toolpunch")
        or equip:HasTag("whip")
        or equip:HasTag("pocketwatch")
        or equip:HasTag("book")
        or (equip:HasTag("chop_attack") and inst:HasTag("woodcutter"))
        or equip:HasTag("jab")
        or equip:HasTag("lancejab")
        or (isweapon and not equip:HasTag("punch"))
        or equip:HasTag("light")
        or equip:HasTag("nopunch")
    then
        return false
    end
    return true
end

function GLOBAL.IsUnarmed(inst)
    local inventory = inst.components.inventory or inst.replica.inventory
    if inventory == nil then return true end
    local equip = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    return equip == nil
end