local GLOBAL = rawget(_G, "GLOBAL") or _G
local ArkBadgeManager = require "widgets/ark_badge_manager"

local badge_defs = {}
local badge_defs_by_id = {}
local active_managers = setmetatable({}, { __mode = "k" })

local function RequestRefreshForActiveManagers()
  for manager in pairs(active_managers) do
    if manager ~= nil then
      manager:RequestRefresh()
    end
  end
end

AddClassPostConstruct("widgets/controls", function(self)
  self.arkBadgeManager = self.topright_root:AddChild(ArkBadgeManager(self.owner, self))

  ArkHookFunction(self, "SetGhostMode", function(next, self, ghost_mode, ...)
    next(self, ghost_mode, ...)
    self.arkBadgeManager:SetGhostMode(ghost_mode)
  end)
end)

function GLOBAL.RegisterArkBadge(id, ctor)
  assert(type(id) == "string" and id ~= "", "Ark badge id must be a non-empty string.")
  assert(type(ctor) == "function", "Ark badge ctor must be a function.")
  assert(badge_defs_by_id[id] == nil, "Ark badge already registered: " .. tostring(id))

  local def = {
    id = id,
    ctor = ctor,
  }

  badge_defs[#badge_defs + 1] = def
  badge_defs_by_id[id] = def
  RequestRefreshForActiveManagers()

  local handle = {}

  function handle:Get(player)
    return GLOBAL.GetArkBadge(id, player)
  end

  function handle:GetManager(player)
    return GLOBAL.GetArkBadgeManager(player)
  end

  function handle:RequestLayout(player)
    local manager = GLOBAL.GetArkBadgeManager(player)
    if manager ~= nil then
      manager:RequestLayout()
    end
  end

  function handle:GetId()
    return id
  end

  return handle
end

function GLOBAL.GetArkBadgeDefinitions()
  return badge_defs
end

function GLOBAL.GetArkBadgeManager(player)
  return player
    and player.HUD
    and player.HUD.controls
    and player.HUD.controls.arkBadgeManager
    or nil
end

function GLOBAL.GetArkBadge(id, player)
  local manager = GLOBAL.GetArkBadgeManager(player)
  return manager ~= nil and manager:GetBadge(id) or nil
end

function GLOBAL.RegisterArkBadgeManager(manager)
  active_managers[manager] = true
end

function GLOBAL.UnregisterArkBadgeManager(manager)
  active_managers[manager] = nil
end