local function IsEnableIcon(cfg)
  return cfg.icon_atlas and cfg.icon_image
end

local function GenTimerKey(cfg)
  if not cfg.duration then
    return nil
  end
  return "ark_buff_timer_" .. cfg.name
end

local function OnUpdateBuffInfo(inst)
  local cfg = inst.buffConfig
  if not cfg or not IsEnableIcon(cfg) or not inst.components.ark_buff_icon then
    return
  end
  local data = inst.buffData
  if cfg.title then
    inst.components.ark_buff_icon:SetTitle(FunctionOrValue(cfg.title, inst, data, cfg))
  end
  if cfg.description then
    inst.components.ark_buff_icon:SetDesc(FunctionOrValue(cfg.description, inst, data, cfg))
  end
  if cfg.icon_atlas and cfg.icon_image then
    local icon_atlas = FunctionOrValue(cfg.icon_atlas, inst, data, cfg)
    local icon_image = FunctionOrValue(cfg.icon_image, inst, data, cfg)
    inst.components.ark_buff_icon:SetTexture(icon_atlas, icon_image)
  end
  if cfg.duration then
    local timer_key = GenTimerKey(cfg)
    local remain_time = inst.components.timer:GetTimeLeft(timer_key) or cfg.duration
    inst.components.ark_buff_icon:SetRemainingTime(remain_time)
    inst.components.ark_buff_icon:SetTotalTime(cfg.duration)
  end
end

local function OnAttached(inst, target, followsymbol, followoffset, data, buffer)
  -- 合并 data.buffConfig 到 inst.buffConfig，允许调用方在 attach 时动态覆盖配置
  if data and data.buffConfig then
    inst.buffConfig = MergeMaps(inst.buffConfig, data.buffConfig)
  end
  if data then
    inst.buffData = data
  end

  local cfg = inst.buffConfig

  inst.entity:SetParent(target.entity)
  inst.Transform:SetPosition(0, 0, 0)
  inst:ListenForEvent("death", function()
    inst.components.debuff:Stop()
  end, target)

  if cfg.duration then
    local timer_key = GenTimerKey(cfg)
    if not inst.components.timer:TimerExists(timer_key) then
      inst.components.timer:StartTimer(timer_key, cfg.duration)
    end
  end

  if cfg.OnAttached then
    cfg.OnAttached(inst, target, followsymbol, followoffset, inst.buffData, buffer)
  end

  if IsEnableIcon(cfg) then
    inst:PushEvent("update_buff_info")
    inst.components.ark_buff_icon:AttachTo(target)
  end
end

local function OnDetached(inst, target)
  local cfg = inst.buffConfig
  if cfg and cfg.OnDetached then
    cfg.OnDetached(inst, target)
  end
  inst:Remove()
end

local function OnTimerDone(inst, data)
  local cfg = inst.buffConfig
  if cfg and cfg.duration then
    local timer_key = GenTimerKey(cfg)
    if data and data.name == timer_key then
      inst.components.debuff:Stop()
    end
  end
end

local function OnExtended(inst, target, followsymbol, followoffset, data, buffer)
  -- 合并 data.buffConfig 到 inst.buffConfig
  if data and data.buffConfig then
    inst.buffConfig = MergeMaps(inst.buffConfig, data.buffConfig)
  end
  if data then
    inst.buffData = data
  end

  local cfg = inst.buffConfig

  if cfg.duration then
    local timer_key = GenTimerKey(cfg)
    inst.components.timer:StopTimer(timer_key)
    inst.components.timer:StartTimer(timer_key, cfg.duration)
  end

  if cfg.OnExtended then
    cfg.OnExtended(inst, target, followsymbol, followoffset, inst.buffData, buffer)
  end

  if IsEnableIcon(cfg) then
    inst:PushEvent("update_buff_info")
  end
end

local function OnSave(inst, data)
  if inst.buffData then
    data.buffData = inst.buffData
  end
end

local function OnLoad(inst, data)
  if data and data.buffData then
    inst.buffData = data.buffData
  end
  inst:PushEvent("update_buff_info")
end

local function ArkMakeBuff(def)
  local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")

    if not TheWorld.ismastersim then
      return inst
    end
    inst.persists = false
    inst.buffData = nil
    inst.buffConfig = def
    inst.entity:SetCanSleep(false)

    inst:ListenForEvent("update_buff_info", OnUpdateBuffInfo)

    if def.duration then
      inst:AddComponent("timer")
      inst:ListenForEvent("timerdone", OnTimerDone)
    end

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetached)
    inst.components.debuff:SetExtendedFn(OnExtended)
    if def.keepondespawn then
      inst.components.debuff.keepondespawn = true
    end
    if IsEnableIcon(def) then
      inst:AddComponent("ark_buff_icon")
      -- inst:PushEvent("update_buff_info")
    end

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad
    return inst
  end
  return Prefab(def.name, fn, def.assets, def.prefabs)
end

GLOBAL.ArkMakeBuff = ArkMakeBuff
