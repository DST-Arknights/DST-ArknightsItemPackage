local function NormalizePositiveInteger(value, defaultValue, fieldName)
  if value == nil then
    value = defaultValue
  end
  assert(type(value) == "number", "Builtin profile field " .. fieldName .. " must be a number.")
  return math.max(1, math.floor(value))
end

local function NormalizeEliteLevelMap(eliteLevelMap)
  if type(eliteLevelMap) ~= "table" then
    return nil
  end

  local normalized = {}
  for eliteLevel, targetLevel in pairs(eliteLevelMap) do
    local normalizedEliteLevel = NormalizePositiveInteger(eliteLevel, nil, "eliteLevelMap key")
    local normalizedTargetLevel = NormalizePositiveInteger(targetLevel, nil, "eliteLevelMap value")
    normalized[normalizedEliteLevel] = normalizedTargetLevel
  end

  return next(normalized) and normalized or nil
end

local builtinProfile = {}

function builtinProfile.NormalizeProfile(profile, opts)
  profile = profile or {}
  opts = opts or {}

  local normalized = {
    requiredElite = NormalizePositiveInteger(profile.requiredElite, 1, "requiredElite"),
  }

  local eliteLevelMap = NormalizeEliteLevelMap(profile.eliteLevelMap)
  if eliteLevelMap ~= nil then
    normalized.eliteLevelMap = eliteLevelMap
  end

  if opts.keepSlot and profile.slot ~= nil then
    normalized.slot = NormalizePositiveInteger(profile.slot, nil, "slot")
  end

  return normalized
end

function builtinProfile.GetTargetLevelByElite(profile, currentElite)
  if profile == nil or profile.eliteLevelMap == nil or currentElite == nil then
    return nil
  end

  local matchedEliteLevel = nil
  local targetLevel = nil
  for eliteLevel, level in pairs(profile.eliteLevelMap) do
    if eliteLevel <= currentElite and (matchedEliteLevel == nil or eliteLevel > matchedEliteLevel) then
      matchedEliteLevel = eliteLevel
      targetLevel = level
    end
  end

  return targetLevel
end

return builtinProfile