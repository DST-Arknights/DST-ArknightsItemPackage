local Widget = require "widgets/widget"

local ArkBadgeManager = Class(Widget, function(self, owner, controls)
  Widget._ctor(self, "ArkBadgeManager")
  self.owner = owner
  self.controls = controls
  self.badgeIds = {}
  self.badgesById = {}
  self.ghostMode = owner ~= nil and owner:HasTag("playerghost") or false
  self.layoutTask = nil
  self.refreshTask = nil

  RegisterArkBadgeManager(self)

  self:RefreshBadges()
end)

function ArkBadgeManager:Kill()
  if self.layoutTask ~= nil then
    self.layoutTask:Cancel()
    self.layoutTask = nil
  end
  if self.refreshTask ~= nil then
    self.refreshTask:Cancel()
    self.refreshTask = nil
  end
  UnregisterArkBadgeManager(self)
  ArkBadgeManager._base.Kill(self)
end

function ArkBadgeManager:GetOwner()
  return self.owner
end

function ArkBadgeManager:GetControls()
  return self.controls
end

function ArkBadgeManager:GetAnchor()
  return self.controls ~= nil and self.controls.status or nil
end

function ArkBadgeManager:GetBadge(id)
  return self.badgesById[id]
end

function ArkBadgeManager:SetGhostMode(ghost_mode)
  self.ghostMode = ghost_mode and true or false
  for _, id in ipairs(self.badgeIds) do
    local badge = self.badgesById[id]
    if badge ~= nil then
      if self.ghostMode then
        badge:Hide()
      else
        badge:Show()
      end
    end
  end
end

function ArkBadgeManager:RequestRefresh()
  if self.refreshTask ~= nil then
    return
  end
  self.refreshTask = self.inst:DoTaskInTime(0, function()
    self.refreshTask = nil
    self:RefreshBadges()
  end)
end

function ArkBadgeManager:RequestLayout()
  if self.layoutTask ~= nil then
    return
  end
  local taskHost = self.owner or self.inst
  self.layoutTask = taskHost:DoTaskInTime(0.5, function()
    self.layoutTask = nil
    self:UpdateLayout()
  end)
end

function ArkBadgeManager:RefreshBadges()
  local defs = GetArkBadgeDefinitions()
  local anchor = self:GetAnchor()
  if not anchor then
    return
  end
  for _, def in ipairs(defs) do
    if self.badgesById[def.id] == nil then
      local ok, badge = pcall(def.ctor, self, self.owner)
      if not ok then
        ArkLogger:Error("RegisterArkBadge ctor failed for", def.id, ":", badge)
      elseif badge ~= nil then
        self.badgeIds[#self.badgeIds + 1] = def.id
        self.badgesById[def.id] = anchor:AddChild(badge)
        if self.ghostMode then
          badge:Hide()
        end
      end
    end
  end

  self:RequestLayout()
end

function ArkBadgeManager:WithCombinedStatus()
  local anchor = self:GetAnchor()
  if anchor == nil then
    return false
  end
  return anchor.brain:GetPosition().y == anchor.stomach:GetPosition().y
end

function ArkBadgeManager:GetBadgeOffsetX()
  if self:WithCombinedStatus() then
    return 62
  else
    return 80
  end
end

function ArkBadgeManager:UpdateLayout()
  local anchor = self:GetAnchor()
  if anchor == nil then
    return
  end
  -- 放到胃的左边
  local stomachPos = anchor.stomach:GetPosition()
  local offsetX = self:GetBadgeOffsetX()
  for i, id in ipairs(self.badgeIds) do
    local badge = self.badgesById[id]
    if badge ~= nil and badge:IsVisible() then
      badge:SetPosition(stomachPos.x - offsetX * i, stomachPos.y, 0)
    end
  end
end

return ArkBadgeManager
