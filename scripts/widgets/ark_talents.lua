local Widget = require "widgets/widget"
local ArkTalentIcon = require "widgets/ark_talent_icon"
local CONSTANTS = require "ark_constants"

local TALENT_GAP = 8

-- ArkTalents：管理玩家当前所有天赋图标的容器 Widget
-- 仅展示 ACTIVE 状态的天赋；LOCKED 天赋图标隐藏（但对象保留，方便状态切换后恢复）
local ArkTalents = Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkTalents")
  self.owner      = owner
  self.talentSlots = {}   -- 按 index 排序的槽位数组 { icon, id, index }
  self.talentsById = {}   -- id -> icon
  self.width       = 0
  self.height      = 0
end)

local function sortByIndex(a, b)
  return (a.index or 0) < (b.index or 0)
end

-- 重新计算布局：只有 visible 的图标才占位
function ArkTalents:UpdateLayout()
  if self.updateLayoutTask then return end
  self.updateLayoutTask = self.inst:DoTaskInTime(0, function()
    self.updateLayoutTask = nil
    table.sort(self.talentSlots, sortByIndex)

    local x = 0
    local maxH = 0
    local iconW, iconH = 0, 0

    for _, slot in ipairs(self.talentSlots) do
      iconW, iconH = slot.icon:GetSize()
      if slot.icon:IsVisible() then
        slot.icon:SetPosition(x + iconW / 2, 0, 0)
        x = x + iconW + TALENT_GAP
        maxH = math.max(maxH, iconH)
      end
    end

    -- 去掉最后多加的 GAP
    if x > 0 then x = x - TALENT_GAP end
    self.width  = x
    self.height = maxH

    if self.updatedLayout then
      self.updatedLayout()
    end
  end)
end

function ArkTalents:AddTalent(id, index)
  local cfg = GetArkTalentConfigById(id)
  local icon = self:AddChild(ArkTalentIcon(self.owner))
  icon:SetTalentId(id)
  icon:SetTexture(cfg.atlas, cfg.image)
  -- 初始隐藏（未同步状态前保持隐藏），等待 SyncTalentStatus 驱动显示
  icon:Hide()

  table.insert(self.talentSlots, { icon = icon, id = id, index = index })
  self.talentsById[id] = icon
  self:UpdateLayout()
end

function ArkTalents:RemoveTalent(id)
  local icon = self.talentsById[id]
  if not icon then return false end
  for i, slot in ipairs(self.talentSlots) do
    if slot.id == id then
      table.remove(self.talentSlots, i)
      break
    end
  end
  self.talentsById[id] = nil
  icon:Kill()
  self:UpdateLayout()
  return true
end

function ArkTalents:GetTalentById(id)
  return self.talentsById[id]
end

function ArkTalents:SyncTalentStatus(id, status, level)
  local icon = self.talentsById[id]
  if not icon then return end
  icon:SyncTalentStatus(status, level)
  self:UpdateLayout()
end

function ArkTalents:GetSize()
  return self.width, self.height
end

return ArkTalents
