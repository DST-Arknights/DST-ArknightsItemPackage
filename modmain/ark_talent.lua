local CONSTANTS = require "ark_constants"

local function checkAndDefaultTalent(talent)
  assert(talent, "Talent config is nil.")
  assert(talent.id, "Talent config missing id.")
  assert(type(talent.levels) == "table" and #talent.levels > 0,
    "Talent " .. talent.id .. " must have at least one level config.")

  local copyLevels = {}
  for _, lvl in ipairs(talent.levels) do
    table.insert(copyLevels, {
      desc   = lvl.desc   or "",
      params = lvl.params or {},
    })
  end

  local copy = {
    id      = talent.id,
    atlas   = talent.atlas  or "",
    image   = talent.image  or "",
    name    = talent.name   or talent.id,
    levels  = copyLevels,
  }

  -- 透传所有回调字段
  local callbackFields = {
    "OnLocked", "OnUnlocked", "OnLevelChange",
    "OnInstall", "OnAdd", "OnRemove", "OnSave", "OnLoad",
  }
  for _, field in ipairs(callbackFields) do
    if talent[field] ~= nil then
      copy[field] = talent[field]
    end
  end

  return copy
end

local TalentsSymbol = Symbol("ARK_TALENTS")
TUNING[TalentsSymbol] = {}

function GLOBAL.RegisterArkTalent(talent)
  assert(talent and talent.id, "Invalid talent config, missing id: " .. tostring(talent))
  if TUNING[TalentsSymbol][talent.id] then
    ArkLogger:Warn("Talent with id " .. talent.id .. " already exists, skipping registration.")
    return
  end
  talent = checkAndDefaultTalent(talent)
  TUNING[TalentsSymbol][talent.id] = talent
end

function GLOBAL.GetArkTalentConfigById(id)
  local cfg = TUNING[TalentsSymbol][id]
  assert(cfg, "No talent config found for id: " .. tostring(id))
  return cfg
end

-- 每个玩家自动挂载 ark_talent 组件
AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim and not inst.components.ark_talent then
    inst:AddComponent("ark_talent")
  end
end)
