local assets = {
  Asset("ATLAS", "images/ui_sympathetic_pendants.xml")
}

-- 疑惑
local CONFUSED_WORK_INCREASE_MULT = 2
local CONFUSED_SPEED_INCREASE_MULT = 0.2

local ANGRY_ATTACK_INCREASE_MULT = 0.4
local ANGRY_SPEED_INCREASE_MULT = 0.3

local HAPPY_WORK_INCREASE_MULT = 1
local HAPPY_SPEED_INCREASE_MULT = 0.3
local HAPPY_HUNGER_DECREASE_MULT = 0.2
local HAPPY_SANITY_RECOVER = 30 / 480
local HAPPY_TEMPERATURE_INSULATION = 6 * 30

local SAD_DEFENSE_INCREASE_MULT = 0.5
local SAD_SPEED_DECREASE_MULT = 0.02

local SourceModifierList = require("util/sourcemodifierlist")

local PENDANT_SOURCE = "sympathetic_pendant"
local WORK_ACTIONS = { ACTIONS.CHOP, ACTIONS.MINE, ACTIONS.HAMMER }

-- Symbol keys for additive bonus lists on target
local SYM_SPEED       = Symbol("sym_pendant_speed_bonus")
local SYM_WORK        = Symbol("sym_pendant_work_bonus")
local SYM_ATTACK      = Symbol("sym_pendant_attack_bonus")
local SYM_DEFENSE     = Symbol("sym_pendant_defense_bonus")
local SYM_HUNGER      = Symbol("sym_pendant_hunger_bonus")
local SYM_SANITY      = Symbol("sym_pendant_sanity_bonus")
local SYM_TEMPERATURE = Symbol("sym_pendant_temperature_bonus")

-- Dirty callbacks: sum bonuses → single DST modifier entry
local function ApplySpeed(target, total)
  if target.components.playerspeedmult then
    target.components.playerspeedmult:SetSpeedMult(PENDANT_SOURCE, 1 + total)
  end
end

local function ApplyWork(target, total)
  if target.components.workmultiplier then
    local mult = 1 + total
    for _, action in ipairs(WORK_ACTIONS) do
      target.components.workmultiplier:AddMultiplier(action, mult, PENDANT_SOURCE)
    end
  end
end

local function ApplyAttack(target, total)
  if target.components.combat then
    target.components.combat.externaldamagemultipliers:SetModifier(PENDANT_SOURCE, 1 + total)
  end
end

local function ApplyDefense(target, total)
  if target.components.combat then
    target.components.combat.externaldamagetakenmultipliers:SetModifier(PENDANT_SOURCE, 1 + total)
  end
end

local function ApplyHunger(target, total)
  if target.components.hunger then
    target.components.hunger.burnratemodifiers:SetModifier(PENDANT_SOURCE, math.max(0, 1 + total))
  end
end

local function ApplySanity(target, total)
  if target.components.sanity then
    target.components.sanity.externalmodifiers:SetModifier(PENDANT_SOURCE, total)
  end
end

local function ApplyTemperature(target, total)
  if target.components.temperature then
    target.components.temperature.inherentinsulation = total
  end
end

local SYM_APPLY = {
  [SYM_SPEED]       = ApplySpeed,
  [SYM_WORK]        = ApplyWork,
  [SYM_ATTACK]      = ApplyAttack,
  [SYM_DEFENSE]     = ApplyDefense,
  [SYM_HUNGER]      = ApplyHunger,
  [SYM_SANITY]      = ApplySanity,
  [SYM_TEMPERATURE] = ApplyTemperature,
}

local function GetBonusList(target, sym)
  local list = target[sym]
  if not list then
    list = SourceModifierList(target, 0, SourceModifierList.additive, SYM_APPLY[sym])
    target[sym] = list
  end
  return list
end

local BUFF_KEY_BY_EMOTION = {
  sad = "SAD",
  angry = "ANGRY",
  confused = "CONFUSED",
  happy = "HAPPY",
  normal = "NORMAL",
}

local function GetEmotionName(emotion)
  if emotion == "sad" then
    return STRINGS.SYMPATHETIC_PENDANT.EMOTION.SAD
  elseif emotion == "angry" then
    return STRINGS.SYMPATHETIC_PENDANT.EMOTION.ANGRY
  elseif emotion == "confused" then
    return STRINGS.SYMPATHETIC_PENDANT.EMOTION.CONFUSED
  elseif emotion == "happy" then
    return STRINGS.SYMPATHETIC_PENDANT.EMOTION.HAPPY
  elseif emotion == "normal" then
    return STRINGS.SYMPATHETIC_PENDANT.EMOTION.NORMAL
  end

  return emotion
end

local function FormatPercent(value)
  local formatted = string.format("%.1f", value * 100)
  formatted = formatted:gsub("%.0$", "")
  return formatted .. "%"
end

local function FormatNumber(value)
  local formatted = string.format("%.1f", value)
  formatted = formatted:gsub("%.0$", "")
  return formatted
end

local function GetGenericBuffStrings()
  return STRINGS.SYMPATHETIC_PENDANT.BUFF.GENERIC
end

local function GetSharedBufferName(data)
  return data and data.buffer_name or GetGenericBuffStrings().SHARED.UNKNOWN_BUFFER_NAME
end

local function GetSharedBuffMult(data)
  return data and data.mult or 0
end

local function GetBuffStrings(emotion)
  local key = BUFF_KEY_BY_EMOTION[emotion]
  return key ~= nil and STRINGS.SYMPATHETIC_PENDANT.BUFF[key] or nil
end

local function GetBuffDescription(emotion, is_shared, mult)
  local buff_strings = GetBuffStrings(emotion)
  if buff_strings == nil then
    return ""
  end

  local buff_scope = nil
  if is_shared then
    buff_scope = buff_strings.SHARED
  else
    buff_scope = buff_strings.OWNER
  end

  if buff_scope == nil then
    return ""
  end

  if emotion == "confused" then
    return string.format(buff_scope.DESC,
      FormatPercent(CONFUSED_WORK_INCREASE_MULT * mult),
      FormatPercent(CONFUSED_SPEED_INCREASE_MULT * mult))
  elseif emotion == "angry" then
    return string.format(buff_scope.DESC,
      FormatPercent(ANGRY_ATTACK_INCREASE_MULT * mult),
      FormatPercent(ANGRY_SPEED_INCREASE_MULT * mult))
  elseif emotion == "happy" then
    return string.format(buff_scope.DESC,
      FormatPercent(HAPPY_WORK_INCREASE_MULT * mult),
      FormatPercent(HAPPY_SPEED_INCREASE_MULT * mult),
      FormatPercent(HAPPY_HUNGER_DECREASE_MULT * mult),
      FormatNumber(HAPPY_SANITY_RECOVER * 480 * mult),
      FormatNumber(HAPPY_TEMPERATURE_INSULATION * mult))
  elseif emotion == "sad" then
    return string.format(buff_scope.DESC,
      FormatPercent(SAD_DEFENSE_INCREASE_MULT * mult),
      FormatPercent(SAD_SPEED_DECREASE_MULT * mult))
  elseif emotion == "normal" then
    return buff_scope.DESC
  end

  return ""
end

local function MakeOwnerBuffTitle(emotion)
  return function(inst, data, cfg)
    return string.format(GetGenericBuffStrings().OWNER.TITLE, GetEmotionName(emotion))
  end
end

local function MakeSharedBuffTitle(emotion)
  return function(inst, data, cfg)
    return string.format(GetGenericBuffStrings().SHARED.TITLE,
      GetEmotionName(emotion), GetSharedBufferName(data))
  end
end

local function MakeOwnerBuffDescription(emotion)
  return function(inst, data, cfg)
    return GetBuffDescription(emotion, false, 1)
  end
end

local function MakeSharedBuffDescription(emotion)
  return function(inst, data, cfg)
    return GetBuffDescription(emotion, true, GetSharedBuffMult(data))
  end
end

local function OnConfusedAttached(inst, target, followsymbol, followoffset, data, buffer)
  local mult = data and data.mult or 1
  GetBonusList(target, SYM_SPEED):SetModifier(inst, CONFUSED_SPEED_INCREASE_MULT * mult)
  GetBonusList(target, SYM_WORK):SetModifier(inst, CONFUSED_WORK_INCREASE_MULT * mult)
end

local function OnConfusedDetached(inst, target)
  local list = target[SYM_SPEED]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_WORK]
  if list then list:RemoveModifier(inst) end
end

local function OnAngryAttached(inst, target, followsymbol, followoffset, data, buffer)
  local mult = data and data.mult or 1
  GetBonusList(target, SYM_ATTACK):SetModifier(inst, ANGRY_ATTACK_INCREASE_MULT * mult)
  GetBonusList(target, SYM_SPEED):SetModifier(inst, ANGRY_SPEED_INCREASE_MULT * mult)
end

local function OnAngryDetached(inst, target)
  local list = target[SYM_ATTACK]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_SPEED]
  if list then list:RemoveModifier(inst) end
end

local function OnHappyAttached(inst, target, followsymbol, followoffset, data, buffer)
  local mult = data and data.mult or 1
  GetBonusList(target, SYM_WORK):SetModifier(inst, HAPPY_WORK_INCREASE_MULT * mult)
  GetBonusList(target, SYM_SPEED):SetModifier(inst, HAPPY_SPEED_INCREASE_MULT * mult)
  GetBonusList(target, SYM_HUNGER):SetModifier(inst, -HAPPY_HUNGER_DECREASE_MULT * mult)
  GetBonusList(target, SYM_SANITY):SetModifier(inst, HAPPY_SANITY_RECOVER * mult)
  GetBonusList(target, SYM_TEMPERATURE):SetModifier(inst, HAPPY_TEMPERATURE_INSULATION * mult)
end

local function OnHappyDetached(inst, target)
  local list
  list = target[SYM_WORK]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_SPEED]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_HUNGER]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_SANITY]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_TEMPERATURE]
  if list then list:RemoveModifier(inst) end
end

local function OnSadAttached(inst, target, followsymbol, followoffset, data, buffer)
  local mult = data and data.mult or 1
  GetBonusList(target, SYM_DEFENSE):SetModifier(inst, SAD_DEFENSE_INCREASE_MULT * mult)
  GetBonusList(target, SYM_SPEED):SetModifier(inst, -SAD_SPEED_DECREASE_MULT * mult)
end

local function OnSadDetached(inst, target)
  local list = target[SYM_DEFENSE]
  if list then list:RemoveModifier(inst) end
  list = target[SYM_SPEED]
  if list then list:RemoveModifier(inst) end
end


local buffs = { {
  assets = assets,
  name = "sympathetic_pendant_confused_owner_buff",
  title = MakeOwnerBuffTitle("confused"),
  description = MakeOwnerBuffDescription("confused"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "confused.tex",
  OnAttached = OnConfusedAttached,
  OnDetached = OnConfusedDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_confused_shared_buff",
  title = MakeSharedBuffTitle("confused"),
  description = MakeSharedBuffDescription("confused"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "confused.tex",
  OnAttached = OnConfusedAttached,
  OnDetached = OnConfusedDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_angry_owner_buff",
  title = MakeOwnerBuffTitle("angry"),
  description = MakeOwnerBuffDescription("angry"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "angry.tex",
  OnAttached = OnAngryAttached,
  OnDetached = OnAngryDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_angry_shared_buff",
  title = MakeSharedBuffTitle("angry"),
  description = MakeSharedBuffDescription("angry"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "angry.tex",
  OnAttached = OnAngryAttached,
  OnDetached = OnAngryDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_happy_owner_buff",
  title = MakeOwnerBuffTitle("happy"),
  description = MakeOwnerBuffDescription("happy"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "happy.tex",
  OnAttached = OnHappyAttached,
  OnDetached = OnHappyDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_happy_shared_buff",
  title = MakeSharedBuffTitle("happy"),
  description = MakeSharedBuffDescription("happy"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "happy.tex",
  OnAttached = OnHappyAttached,
  OnDetached = OnHappyDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_sad_owner_buff",
  title = MakeOwnerBuffTitle("sad"),
  description = MakeOwnerBuffDescription("sad"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "sad.tex",
  OnAttached = OnSadAttached,
  OnDetached = OnSadDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_sad_shared_buff",
  title = MakeSharedBuffTitle("sad"),
  description = MakeSharedBuffDescription("sad"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "sad.tex",
  OnAttached = OnSadAttached,
  OnDetached = OnSadDetached,
}, {
  assets = assets,
  name = "sympathetic_pendant_normal_owner_buff",
  title = MakeOwnerBuffTitle("normal"),
  description = MakeOwnerBuffDescription("normal"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "normal.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_normal_shared_buff",
  title = MakeSharedBuffTitle("normal"),
  description = MakeSharedBuffDescription("normal"),
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "normal.tex",
}, }

local results = {}
for _, v in ipairs(buffs) do
  table.insert(results, ArkMakeBuff(v))
end

return unpack(results)
