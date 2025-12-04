local Widget = require "widgets/widget"
local ArkSkill = require "widgets/ark_skill"
local ArkCharacterLevel = require "widgets/ark_character_level"
local ArkSkills = require "widgets/ark_skills"
local ArkExpBar = require "widgets/ark_exp_bar"

local ArkSkillUi = Class(Widget, function(self, owner, skillsConfig)
  Widget._ctor(self, "ArkSkillUi")
  self.owner = owner

  local skills = self:AddChild(ArkSkills(self.owner, skillsConfig))
  self.skills = skills
  self.skills:SetPosition(140, 20, 0)

  local characterLevel = self:AddChild(ArkCharacterLevel(self.owner))
  characterLevel:SetPosition(0, -25, 0)
  self.characterLevel = characterLevel

  local expBar = self:AddChild(ArkExpBar(self.owner))
  expBar:SetPosition(80, -110, 0)
  local skillsSizeX = skills:GetSize()
  expBar:SetSize(skillsSizeX)
  self.expBar = expBar
end)

return ArkSkillUi
