-- 护甲组件
local function WouldEnterFinalElse(inst, data)
  data = data or {}

  if inst.components.health == nil or inst.components.health:IsDead() then
    return false
  end
  if inst.sg:HasAnyStateTag("drowning", "falling") then
    return false
  end

  if data.weapon ~= nil and data.weapon:HasTag("tranquilizer")
      and (inst.sg:HasStateTag("bedroll") or inst.sg:HasStateTag("knockout")) then
    return false
  end

  if inst.sg:HasStateTag("transform") or inst.sg:HasStateTag("dismounting") then
    return false
  end

  if inst.sg:HasStateTag("sleeping") then
    return false
  end

  if inst.sg:HasStateTag("parrying") and data.redirected then
    return false
  end

  if inst.sg:HasAnyStateTag("devoured", "suspended") then
    return false
  end

  if inst.sg:HasStateTag("nointerrupt") then
    return false
  end

  if data.attacker ~= nil
      and data.attacker:HasTag("groundspike")
      and not inst.components.rider:IsRiding()
      and not inst:HasTag("wereplayer") then
    return false
  end

  if data.attacker ~= nil
      and data.attacker.sg ~= nil
      and data.attacker.sg:HasStateTag("pushing") then
    return false
  end

  if inst.sg:HasStateTag("shell") then
    return false
  end

  if inst.components.pinnable ~= nil and inst.components.pinnable:IsStuck() then
    return false
  end

  if data.stimuli == "darkness" then
    return false
  end

  if data.stimuli == "electric"
      and inst.sg:HasStateTag("electrocute")
      and inst.sg:GetTimeInState() < 3 * FRAMES then
    return false
  end

  if data.stimuli == "electric"
      and not (inst.components.inventory:IsInsulated() or inst.sg:HasStateTag("noelectrocute")) then
    return false
  end

  return true
end

local function DoHurtSound(inst)
  if inst.hurtsoundoverride ~= nil then
    inst.SoundEmitter:PlaySound(inst.hurtsoundoverride, nil, inst.hurtsoundvolume)
  elseif not inst:HasTag("mime") then
    inst.SoundEmitter:PlaySound(
    (inst.talker_path_override or "dontstarve/characters/") .. (inst.soundsname or inst.prefab) .. "/hurt", nil,
      inst.hurtsoundvolume)
  end
end

AddStategraphPostInit("wilson", function(sg)
  local OldEventAttackedFn = sg.events.attacked.fn
  sg.events.attacked.fn = function(inst, data)
    -- 获取装备的防具, 检查是否有免疫受击僵直的属性
    local immune_stun = false
    if inst.components.inventory ~= nil then
      for k, v in pairs(inst.components.inventory.equipslots) do
        if v ~= nil and v.components.armor ~= nil and v.components.armor:IsImmuneStun() and v.components.armor:GetPercent() > 0 then
          immune_stun = true
          break
        end
      end
    end
    if WouldEnterFinalElse(inst, data) and (immune_stun or inst:HasTag("immune_stun")) then
      ArkLogger:Debug("immune_stun")
      -- inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
      -- DoHurtSound(inst)
      return
    end
    return OldEventAttackedFn(inst, data)
  end
end)

AddComponentPostInit("armor", function(self)
  -- 设置免疫受击僵直
  self.immune_stun = false
  function self:SetImmuneStun(immune)
    self.immune_stun = immune
  end

  function self:IsImmuneStun()
    return self.immune_stun
  end
end)
