-- ════════════════════════════════════════════════════════
-- AOE 选择器运行实体（由 modmain/target_selector.lua 管理）
-- 网络同步：只传 selector id（net_string），客户端查注册表装配 reticule/aoetargeting
-- 取消检测：确认 CASTAOE 由 reticule ping 标记；只有真正取消瞄准才向服务端发送取消 RPC
-- ════════════════════════════════════════════════════════

local function TransformTargetPos(inst, pos)
  local id = inst._selector_id:value()
  local selector = id ~= "" and GetTargetSelector(id) or nil
  return selector ~= nil and selector.TransformTargetPos ~= nil
    and selector:TransformTargetPos(inst, pos) or pos
end

local function ReticuleTargetFn(inst)
  local player = ThePlayer
  local ground = TheWorld.Map
  local pos = Vector3()
  -- 朝向前方找可通行的瞄准点（手柄/自动瞄准），范围与当前选择器配置一致。
  -- 先做 selector 的坐标规范化，再验证最终落点，保证视觉与实际 CASTAOE 使用同一位置。
  local range = inst.components.aoetargeting:GetRange()
  for r = range, 0, -0.25 do
    pos.x, pos.y, pos.z = player.entity:LocalToWorldSpace(r, 0, 0)
    local target = TransformTargetPos(inst, pos)
    if ground:IsPassableAtPoint(target.x, 0, target.z, true) and not ground:IsGroundTargetBlocked(target) then
      return target
    end
  end
  return TransformTargetPos(inst, pos)
end

-- 客户端：收到 selector id 后装配 + 开始瞄准
local function OnSelectorIdReady(inst)
  -- 覆写 IsGrandOwner：选择器实体通过 SetParent 挂在玩家上（不占 inventory），
  -- 让 aoetargeting 系统认为它属于该玩家
  if inst.replica and inst.replica.inventoryitem then
    function inst.replica.inventoryitem:IsGrandOwner(guy)
      return guy and inst.entity:GetParent() == guy
    end
  end

  local id = inst._selector_id:value()
  if id ~= "" then
    local selector = GetTargetSelector(id)
    if selector ~= nil then
      selector:ApplyToEntity(inst)
    end
    if ThePlayer and ThePlayer.components.playercontroller then
      ThePlayer.components.playercontroller:StartAOETargetingUsing(inst)
    end
  end
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddNetwork()

  inst:AddTag("FX")
  inst:AddTag("NOCLICK")
  inst.entity:SetCanSleep(false)

  -- 网络变量：selector id（主客机各自查注册表）+ 确认标记
  inst._selector_id = net_string(inst.GUID, "area_target_selector._id", "selector_id_dirty")
  inst._confirmed   = net_bool(inst.GUID, "area_target_selector._confirmed", "confirmed_dirty")

  inst:AddComponent("spellbook")
  -- 欺骗系统：让选择器实体被 DST 识别为"可用法术书"
  -- （AOE 确认时 playercontroller:GetActiveSpellBook 取它，经 spellbook 路径生成 CASTAOE 动作）
  -- SelectSpell/GetSelectedSpell 固定返回值仅为了让动作系统通过
  inst.components.spellbook.SelectSpell = function(self, id)
    return true
  end
  inst.components.spellbook.GetSelectedSpell = function(self)
    return 1
  end
  function inst.components.spellbook:CanBeUsedBy(doer)
    return self.inst.entity:GetParent() == doer
  end

  inst:AddComponent("aoetargeting")
  inst.components.aoetargeting.reticule.targetfn = ReticuleTargetFn
  inst.components.aoetargeting:SetShouldRepeatCastFn(nil)

  -- 覆写 Start/StopTargeting：绕过 replica.inventoryitem:IsGrandOwner 检查，
  -- 直接装配 reticule（选择器实体挂在玩家上，不占 inventory 槽）
  function inst.components.aoetargeting:StartTargeting()
    if self.inst.components.reticule == nil then
      self.inst:AddComponent("reticule")
      for k, v in pairs(self.reticule) do
        self.inst.components.reticule[k] = v
      end
      -- 原版确认 CASTAOE 时会先 PingReticuleAt，再立刻 StopTargeting。
      -- 用 ping 区分“确认”与 ESC/右键等真正取消，避免取消 RPC 抢在确认动作前到服务端。
      ArkHookFunction(self.inst.components.reticule, "PingReticuleAt", function(next, reticule, ...)
        inst._ark_target_confirming = true
        return next(reticule, ...)
      end)
      if ThePlayer and ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RefreshReticule(self.inst)
      end
    end
  end
  function inst.components.aoetargeting:StopTargeting()
    if self.inst.components.reticule ~= nil then
      self.inst:RemoveComponent("reticule")
      if ThePlayer and ThePlayer.components.playercontroller then
        ThePlayer.components.playercontroller:RefreshReticule()
      end
    end
  end

  inst:AddComponent("aoespell")
  inst:ListenForEvent("onremove", function()
    if ThePlayer and ThePlayer.components.playercontroller then
      ThePlayer.components.playercontroller:RefreshReticule()
    end
  end)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    inst:ListenForEvent("selector_id_dirty", function()
      OnSelectorIdReady(inst)
    end)
    inst.OnEntityReplicated = OnSelectorIdReady

    -- 确认 CASTAOE 已由 PingReticuleAt 标记；真正取消才发 Cancel RPC。
    ArkHookFunction(inst.components.aoetargeting, "StopTargeting", function(next, self, ...)
      local confirming = inst._ark_target_confirming == true
      inst._ark_target_confirming = nil
      local res = next(self, ...)
      if not confirming then
        inst:DoTaskInTime(2 * FRAMES, function()
          if inst:IsValid() then
            SendModRPCToServer(GetModRPC("arkTargetSelector", "Cancel"), inst.GUID)
          end
        end)
      end
      return res
    end)

    return inst
  end

  -- 服务端：让 action 能正常走下去
  inst:AddComponent("inventoryitem")
  -- 欺骗系统：aoespell:CanCast 检查 GetGrandOwner()==doer，返回父实体（SetParent 的玩家）即通过
  function inst.components.inventoryitem:GetGrandOwner()
    return self.inst.entity:GetParent()
  end

  -- 服务端也装配（OnSelectorIdReady）：确认时 aoespell:CanCast 读 aoetargeting.deployradius
  -- 进 CanCastAtPoint，故服务端需 ApplyToEntity 提供的字段；
  -- StartAOETargetingUsing 在服务端因 ThePlayer=nil 自动跳过，仅客户端真正瞄准
  inst:DoTaskInTime(0, OnSelectorIdReady)
  inst.persists = false

  return inst
end

return Prefab("area_target_selector", fn, nil)
