local ARMOR_CONSTRUCT = TUNING.ARMOR_CONSTRUCT

RegisterInventoryItemAtlas("images/inventoryimages/armor_construct.xml", "armor_construct.tex")
local assets =
{
  Asset("ANIM", "anim/armor_construct.zip"),
  Asset("ATLAS", "images/inventoryimages/armor_construct.xml"),
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
  if owner:HasTag("no_armor_construct_exchange") then
    return
  end

  if inst._exchange_pause_until ~= nil and GetTime() < inst._exchange_pause_until then
    return
  end

  local armor = inst.components.armor
  if armor == nil then
    return
  end

  local health = owner.components.health
  local current_health = health.currenthealth
  local target_health = math.min(ARMOR_CONSTRUCT.EXCHANGE_HEALTH_TARGET, health:GetMaxWithPenalty())
  local health_delta = current_health - target_health
  if math.abs(health_delta) <= ARMOR_CONSTRUCT.EXCHANGE_HEALTH_EPSILON then
    return
  end

  local max_exchange = math.min(
    ARMOR_CONSTRUCT.EXCHANGE_RATE_PER_SECOND * ARMOR_CONSTRUCT.EXCHANGE_TICK,
    math.abs(health_delta)
  )

  if health_delta < 0 then
    if armor.condition <= 0 then
      return
    end
    local heal = math.min(max_exchange, armor.condition)
    health:DoDelta(heal, nil, "armor_construct_heal", true, inst)
    armor:SetCondition(armor.condition - heal)
  else
    local missing = armor.maxcondition - armor.condition
    if missing <= 0 then
      return
    end
    local drain = math.min(max_exchange, missing)
    health:DoDelta(-drain, nil, "armor_construct_repair", true, inst)
    armor:Repair(drain)
  end
end

local function StartExchangeTask(inst)
  if inst._exchange_task == nil then
    inst._exchange_task = inst:DoPeriodicTask(ARMOR_CONSTRUCT.EXCHANGE_TICK, DoArmorHealthExchange)
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
    owner.AnimState:OverrideItemSkinSymbol("swap_body", skin_build, "swap_body", inst.GUID, "armor_construct")
  else
    owner.AnimState:OverrideSymbol("swap_body", "armor_construct", "swap_body")
  end
  -- 最低生命值保护
  if owner.components.health then
    owner.components.health.minhealthmodifiers:SetModifier(inst, ARMOR_CONSTRUCT.MIN_HEALTH)
  end
  inst:ListenForEvent("blocked", OnBlocked, owner)
  inst:PriorityListenForEvent("minhealth", inst._OnMinHealth, owner, { priority = 2 })
  inst:ListenForEvent("attacked", inst._OnOwnerAttacked, owner)
  StartExchangeTask(inst)
end

local function onunequip(inst, owner)
  owner.AnimState:ClearOverrideSymbol("swap_body")
  if owner.components.health then
    owner.components.health.minhealthmodifiers:RemoveModifier(inst)
  end
  inst:RemoveEventCallback("blocked", OnBlocked, owner)
  inst:PriorityRemoveEventCallback("minhealth", inst._OnMinHealth, owner)
  inst:RemoveEventCallback("attacked", inst._OnOwnerAttacked, owner)
  StopExchangeTask(inst)

  local skin_build = inst:GetSkinBuild()
  if skin_build ~= nil then
    owner:PushEvent("unequipskinneditem", inst:GetSkinName())
  end
end

local function OnTakeDamage(inst, damage_amount)
  inst._exchange_pause_until = GetTime() + ARMOR_CONSTRUCT.EXCHANGE_PAUSE_AFTER_DAMAGE
end

local function OnArmorConditionChange(inst, data)
  if data.percent <= 0 then
    inst.components.armor:SetAbsorption(0)
  else
    inst.components.armor:SetAbsorption(ARMOR_CONSTRUCT.ABSORB_PERCENT)
  end
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()

  MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("armor_construct")
  inst.AnimState:SetBuild("armor_construct")
  inst.AnimState:PlayAnimation("anim")

  inst:AddTag("heavyarmor")
  inst:AddTag("hardarmor")
  inst:AddTag("armor")

  inst.foleysound = "dontstarve/movement/foley/marblearmour"

  local swap_data = { bank = "armor_construct", anim = "anim" }
  MakeInventoryFloatable(inst, "small", 0.2, 0.80, nil, nil, swap_data)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")

  inst:AddComponent("inventoryitem")

  inst:AddComponent("armor")
  inst.components.armor:InitCondition(ARMOR_CONSTRUCT.MAX_CONDITION, ARMOR_CONSTRUCT.ABSORB_PERCENT)
  -- 耐久损失按比例打折: 吸收100伤害只扣 100 * CONDITION_LOSS_PERCENT 耐久
  inst.components.armor.conditionlossmultipliers:SetModifier(inst, ARMOR_CONSTRUCT.CONDITION_LOSS_PERCENT)
  inst.components.armor:SetKeepOnFinished(true)
  -- 设置免疫受击僵直
  inst.components.armor:SetImmuneStun(true)
  -- 初始0耐久
  inst.components.armor.condition = 0
  -- InitCondition 设置了满额吸收率；直接改 condition 不会触发耐久变化事件。
  inst.components.armor:SetAbsorption(0)
  -- 被击一段时间内暂停任务
  inst.components.armor.ontakedamage = OnTakeDamage
  -- 耐久为0时不吸收伤害
  inst:ListenForEvent("percentusedchange", OnArmorConditionChange)

  inst:AddComponent("equippable")
  inst.components.equippable.equipslot = EQUIPSLOTS.BODY

  inst._OnOwnerAttacked = function(owner, data)
    inst._exchange_pause_until = GetTime() + ARMOR_CONSTRUCT.EXCHANGE_PAUSE_AFTER_DAMAGE
  end
  inst._OnMinHealth = function(owner)
    local health = owner.components.health
    if health.currenthealth ~= ARMOR_CONSTRUCT.MIN_HEALTH then
      return false
    end

    -- 宿主血量回满, 自身销毁
    health:SetPercent(1)
    inst:Remove()
    return true
  end
  inst.components.equippable:SetOnEquip(onequip)
  inst.components.equippable:SetOnUnequip(onunequip)

  MakeHauntableLaunch(inst)

  return inst
end

return Prefab("armor_construct", fn, assets)
