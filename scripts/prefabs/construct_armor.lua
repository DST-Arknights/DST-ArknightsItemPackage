local CONSTRUCT_ARMOR = TUNING.CONSTRUCT_ARMOR

RegisterInventoryItemAtlas("images/inventoryimages/construct_armor.xml", "construct_armor.tex")
local assets =
{
  Asset("ANIM", "anim/construct_armor.zip"),
  Asset("ATLAS", "images/inventoryimages/construct_armor.xml"),
}

local function OnBlocked(owner)
  owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_marble")
end

local function DoArmorHealthExchange(inst)
  local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
  if owner == nil or owner.components.health == nil or owner.components.health:IsDead() or owner.components.health:IsInvincible() then
    return
  end

  -- owner 有标签时不执行该任务
  if owner:HasTag("no_construct_armor_exchange") then
    return
  end

  if inst._exchange_pause_until ~= nil and GetTime() < inst._exchange_pause_until then
    return
  end

  local armor = inst.components.armor
  if armor == nil then
    return
  end

  local max_health = owner.components.health:GetMaxWithPenalty()
  local current_health = owner.components.health.currenthealth
  local half_health = max_health * 0.5

  if current_health < half_health then
    if armor.condition <= 0 then
      return
    end
    local max_heal = half_health - current_health
    local heal = math.floor(math.min(CONSTRUCT_ARMOR.EXCHANGE_RATE_PER_SECOND * CONSTRUCT_ARMOR.EXCHANGE_TICK, armor.condition, max_heal))
    if heal <= 0 then
      return
    end
    owner.components.health:DoDelta(heal, nil, "construct_armor_heal", true, inst)
    armor:SetCondition(armor.condition - heal)
  elseif current_health > half_health then
    local missing = armor.maxcondition - armor.condition
    if missing <= 0 then
      return
    end
    local max_drain = current_health - half_health
    local drain = math.floor(math.min(CONSTRUCT_ARMOR.EXCHANGE_RATE_PER_SECOND * CONSTRUCT_ARMOR.EXCHANGE_TICK, missing, max_drain))
    if drain <= 0 then
      return
    end
    owner.components.health:DoDelta(-drain, nil, "construct_armor_repair", true, inst)
    armor:Repair(drain)
  end
end

local function StartExchangeTask(inst)
  if inst._exchange_task == nil then
    inst._exchange_task = inst:DoPeriodicTask(CONSTRUCT_ARMOR.EXCHANGE_TICK, DoArmorHealthExchange)
  end
end

local function StopExchangeTask(inst)
  if inst._exchange_task ~= nil then
    inst._exchange_task:Cancel()
    inst._exchange_task = nil
  end
end

local function onequip(inst, owner)
  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("equipskinneditem", inst:GetSkinName())
    owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "construct_armor")
  else
    owner.AnimState:OverrideSymbol("swap_body", "construct_armor", "swap_body")
  end
  -- 锁血: 1
  if owner.components.health then
    owner.components.health.minhealthmodifiers:SetModifier(inst, 1)
  end
  inst:ListenForEvent("blocked", OnBlocked, owner)
  inst:ListenForEvent("minhealth", inst._OnMinHealth, owner)
  inst:ListenForEvent("attacked", inst._OnOwnerAttacked, owner)
  StartExchangeTask(inst)
end

local function onunequip(inst, owner)
  owner.AnimState:ClearOverrideSymbol("swap_body")
  if owner.components.health then
    owner.components.health.minhealthmodifiers:RemoveModifier(inst)
  end
  inst:RemoveEventCallback("blocked", OnBlocked, owner)
  inst:RemoveEventCallback("minhealth", inst._OnMinHealth, owner)
  inst:RemoveEventCallback("attacked", inst._OnOwnerAttacked, owner)
  StopExchangeTask(inst)

  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("unequipskinneditem", inst:GetSkinName())
  end
end

local function OnTakeDamage(inst, damage_amount)
  inst._exchange_pause_until = GetTime() + CONSTRUCT_ARMOR.EXCHANGE_PAUSE_AFTER_DAMAGE
end

local function OnArmorConditionChange(inst, data)
  if data.percent <= 0 then
    inst.components.armor:SetAbsorption(0)
  else
    inst.components.armor:SetAbsorption(CONSTRUCT_ARMOR.ABSORB_PERCENT)
  end
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("armor_marble")
  inst.AnimState:SetBuild("armor_marble")
  inst.AnimState:PlayAnimation("anim")

  inst:AddTag("heavyarmor")
  inst:AddTag("hardarmor")
  inst:AddTag("armor")

  inst.foleysound = "dontstarve/movement/foley/marblearmour"

  local swap_data = { bank = "armor_marble", anim = "anim" }
  MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")

  inst:AddComponent("inventoryitem")

  inst:AddComponent("armor")
  inst.components.armor:InitCondition(CONSTRUCT_ARMOR.MAX_CONDITION, CONSTRUCT_ARMOR.ABSORB_PERCENT)
  -- 耐久损失按比例打折: 吸收100伤害只扣 100 * CONDITION_LOSS_PERCENT 耐久
  inst.components.armor.conditionlossmultipliers:SetModifier(inst, CONSTRUCT_ARMOR.CONDITION_LOSS_PERCENT)
  inst.components.armor:SetKeepOnFinished(true)
  -- 设置免疫受击僵直
  inst.components.armor:SetImmuneStun(true)
  -- 初始0耐久
  inst.components.armor.condition = 0
  -- 被击一段时间内暂停任务
  inst.components.armor.ontakedamage = OnTakeDamage
  -- 耐久为0时不吸收伤害
  inst:ListenForEvent("percentusedchange", OnArmorConditionChange)

  inst:AddComponent("equippable")
  inst.components.equippable.equipslot = EQUIPSLOTS.BODY

  inst._OnOwnerAttacked = function(owner, data)
    inst._exchange_pause_until = GetTime() + CONSTRUCT_ARMOR.EXCHANGE_PAUSE_AFTER_DAMAGE
  end
  inst._OnMinHealth = PriorityEventCallback(function(owner)
    -- 宿主血量回满, 自身销毁
    owner.components.health:SetPercent(1)
    inst:Remove()
  end, { priority = 2 })
  inst.components.equippable:SetOnEquip(onequip)
  inst.components.equippable:SetOnUnequip(onunequip)

  MakeHauntableLaunch(inst)

  return inst
end

return Prefab("construct_armor", fn, assets)
