local Widget = require "widgets/widget"
local ArkSkill = require "widgets/ark_skill"
-- 技能间隔
local SKILL_GAP = 20

local ArkSkills = Class(Widget, function(self, owner, skillsConfig)
  Widget._ctor(self, "ArkSkills")
  self.owner = owner
  self.skillSlots = {} -- 按index排序的技能槽位数组
  self.skillsById = {} -- 按id索引的技能表
  self.width = 0
  self.height = 0
  self.singleSkillWidth = 0
  if skillsConfig then
    for _, skill in pairs(skillsConfig) do
      self:AddSkill(skill)
    end
  end
  self.owner:DoTaskInTime(0, function()
    if owner.replica.ark_skill then
      owner.replica.ark_skill:RequestSkillsConfig()
    end
  end)
end)

-- 按index排序的比较函数
local function sortByIndex(a, b)
  return (a.cfg.index or 0) < (b.cfg.index or 0)
end

-- 重新计算布局和尺寸
-- 布局规则: 第一个技能左边缘贴近原点(x=0), 每个技能间隔为SKILL_GAP
function ArkSkills:UpdateLayout()
  if self.updateLayoutTask then
    return
  end
  self.updateLayoutTask = self.inst:DoTaskInTime(0, function()
    self.updateLayoutTask = nil
    table.sort(self.skillSlots, sortByIndex)

    local maxHeight = 0
    local skillWidth = self.skillSlots[1] and self.skillSlots[1].skill:GetSize() or 0

    for i, slot in ipairs(self.skillSlots) do
      local skillSizeW, skillSizeH = slot.skill:GetSize()
      self.singleSkillWidth = skillSizeW
      maxHeight = math.max(maxHeight, skillSizeH)

      -- 第一个技能左边缘在x=0, 中心在x=width/2
      -- 后续技能: x = (i-1) * (width + gap) + width/2
      local x = (i - 1) * (skillSizeW + SKILL_GAP) + skillSizeW / 2
      slot.skill:SetPosition(x, 0, 0)
    end

    local count = #self.skillSlots
    if count > 0 then
      self.width = count * skillWidth + (count - 1) * SKILL_GAP
    else
      self.width = 0
    end
    self.height = maxHeight
    if self.updatedLayout then
      self.updatedLayout()
    end
  end)
end

-- 添加单个技能
function ArkSkills:AddSkill(cfg)
  ArkLogger:Debug("ArkSkills:AddSkill", cfg.id, cfg.index)
   -- 如果有id，先移除同id的技能
  -- 相同的id杀掉然后添加
  if cfg.id then
    self:RemoveSkill(cfg.id)
  end
  local skill = self:AddChild(ArkSkill(self.owner, cfg))

  table.insert(self.skillSlots, {
    skill = skill,
    cfg = cfg
  })

  if cfg.id then
    self.skillsById[cfg.id] = skill
  end

  self:UpdateLayout()
end

-- 移除单个技能
function ArkSkills:RemoveSkill(identifier)
  -- identifier可以是id或index
  local removeIndex

  if type(identifier) == "number" then
    -- 如果是数字，优先当作index处理
    for i, slot in ipairs(self.skillSlots) do
      if slot.cfg.index == identifier or i == identifier then
        removeIndex = i
        break
      end
    end
  else
    -- 否则当作id处理
    for i, slot in ipairs(self.skillSlots) do
      if slot.cfg.id == identifier then
        removeIndex = i
        break
      end
    end
  end

  if removeIndex then
    local slot = table.remove(self.skillSlots, removeIndex)
    if slot.cfg.id and self.skillsById[slot.cfg.id] then
      self.skillsById[slot.cfg.id] = nil
    end
    slot.skill:Kill()
    self:UpdateLayout()
    return true
  end

  return false
end

function ArkSkills:GetSize()
  return self.width, self.height
end

function ArkSkills:GetSkillById(id)
  return self.skillsById[id]
end

function ArkSkills:GetSkillByIndex(index)
  for _, slot in ipairs(self.skillSlots) do
    if slot.cfg.index == index then
      return slot.skill
    end
  end
  return nil
end

function ArkSkills:Kill()
  if self.updateLayoutTask then
    self.updateLayoutTask:Cancel()
    self.updateLayoutTask = nil
  end
  ArkSkills._base.Kill(self)
end

return ArkSkills
