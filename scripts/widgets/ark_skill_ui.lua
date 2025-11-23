local Widget = require "widgets/widget"
local ArkSkill = require "widgets/ark_skill"

local SKILL_OFFSET_X = 220

local ArkSkillUi = Class(Widget, function(self, owner, config)
  Widget._ctor(self, "ArkSkillUi")
  self.owner = owner
  self.skills = {}
  self.skillsById = {}
  for _, cfg in ipairs(config.skills) do
    self:AddSkill(cfg)
  end
end)

function ArkSkillUi:AddSkill(config)
  local skill = self:AddChild(ArkSkill(self.owner, config))
  skill:SetPosition(SKILL_OFFSET_X * #self.skills, 0, 0)
  table.insert(self.skills, skill)
  if config.id then
    self.skillsById[config.id] = skill
  end
end

function ArkSkillUi:GetSkillById(id)
  return self.skillsById and self.skillsById[id] or nil
end

-- UI Kill
function ArkSkillUi:Kill()
  local mgr = ThePlayer and ThePlayer.GetArkHotKeyManager and ThePlayer:GetArkHotKeyManager() or nil
  if mgr and self.skillsById then
    for id, _ in pairs(self.skillsById) do
      mgr:Unregister('skill', id)
    end
  end
  ArkSkillUi._base.Kill(self)
end

return ArkSkillUi
