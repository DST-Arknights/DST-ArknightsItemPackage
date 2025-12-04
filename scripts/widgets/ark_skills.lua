local Widget = require "widgets/widget"
local ArkSkill = require "widgets/ark_skill"
-- 技能间隔
local SKILL_GAP = 200

local ArkSkills = Class(Widget, function(self, owner, skillsConfig)
  Widget._ctor(self, "ArkSkills")
  self.owner = owner
  self.skills = {}
  self.skillsById = {}
  self.width = 0
  self.height = 0
  self.singleSkillWidth = 0
  for _, cfg in ipairs(skillsConfig) do
    local skill = self:AddChild(ArkSkill(self.owner, cfg))
    skill:SetPosition(SKILL_GAP * #self.skills, 0, 0)
    table.insert(self.skills, skill)
    local skillSizeW, skillSizeH = skill:GetSize()
    self.singleSkillWidth = skillSizeW
    self.height = skillSizeH
    if cfg.id then
      self.skillsById[cfg.id] = skill
    end
  end
  self.width = self.singleSkillWidth + SKILL_GAP * (math.max(#self.skills - 1, 0))
end)

function ArkSkills:GetSize()
  return self.width, self.height
end

function ArkSkills:GetSkillById(id)
  return self.skillsById and self.skillsById[id] or nil
end

return ArkSkills
