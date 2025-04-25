local Widget = require "widgets/widget"
local ArkSkill = require "widgets/ark_skill"

local SKILL_OFFSET_X = 220

local ArkSkillUi = Class(Widget, function(self, owner, config)
  Widget._ctor(self, "ArkSkillUi")
  self.owner = owner
  self.skills = {}
  for i, config in ipairs(config.skills) do
    self:AddSkill(config, i)
  end
end)

function ArkSkillUi:AddSkill(config, idx)
  local skill = self:AddChild(ArkSkill(self.owner, config, idx))
  skill:SetPosition(SKILL_OFFSET_X * #self.skills, 0, 0)
  table.insert(self.skills, skill)
end

function ArkSkillUi:GetSkill(index)
  return self.skills[index]
end

function ArkSkillUi:GetSkillConfig(index)
  return self.skills[index].config
end

return ArkSkillUi
