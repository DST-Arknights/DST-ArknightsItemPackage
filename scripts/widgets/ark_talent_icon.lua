local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local BorderWidget = require "widgets/border_widget"
local CONSTANTS = require "ark_constants"

local ICON_SIZE = 40
local HOVER_WIDTH = 360
local HOVER_PADDING = 20
local HOVER_TITLE_FONT_SIZE = 36
local HOVER_DESC_FONT_SIZE = 30
local HOVER_DESC_MAX_LINES = 20

-- ── 悬浮描述文本 ────────────────────────────────────────────────────────────

local ArkTalentDescText = Class(Widget, function(self, text, maxWidth)
  Widget._ctor(self, "ArkTalentDescText")
  self.h = 0
  self.maxWidth = maxWidth or 320
  local fontSize   = HOVER_DESC_FONT_SIZE
  local maxLines   = HOVER_DESC_MAX_LINES
  local lineHeight = fontSize * 1.0

  local textWidget = self:AddChild(Text(FALLBACK_FONT_FULL, fontSize, ""))
  local numLines = textWidget:SetMultilineTruncatedString(
    text or "",
    maxLines,
    self.maxWidth,
    nil,
    true,
    true,
    fontSize
  )
  numLines  = math.max(1, numLines or 1)
  self.h    = numLines * lineHeight

  textWidget:SetRegionSize(self.maxWidth, self.h)
  textWidget:SetHAlign(ANCHOR_LEFT)
  textWidget:SetVAlign(ANCHOR_TOP)
  textWidget:SetPosition(0, -self.h / 2, 0)
end)

function ArkTalentDescText:GetSize()
  return self.maxWidth, self.h
end

-- ── ArkTalentIcon ────────────────────────────────────────────────────────────

local ArkTalentIcon = Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkTalentIcon")
  self.owner = owner

  -- 图标本体
  self.iconImage = self:AddChild(Image())
  self.iconImage:SetSize(ICON_SIZE, ICON_SIZE)

  -- 等级徽章（等级 > 1 时显示）
  self.levelBadge = self:AddChild(Image("images/ark_item_ui.xml", "circle.tex"))
  self.levelBadge:SetTint(0.1, 0.1, 0.1, 0.85)
  self.levelBadge:SetSize(16, 16)
  self.levelBadge:SetPosition(ICON_SIZE / 2, -ICON_SIZE / 2, 0)
  self.levelBadge:Hide()
  self.levelText = self.levelBadge:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 13))

  -- 悬浮框
  self.hoverRoot  = Widget("ark_talent_icon_hover_root")
  self.hoverBg    = self.hoverRoot:AddChild(BorderWidget(HOVER_WIDTH, 0, {
    borderWidth      = 2,
    borderColor      = { 0.45, 0.45, 0.45, 0.9 },
    backgroundColor  = { 0.23, 0.23, 0.23, 0.7 },
  }))
  self.hoverTitle  = self.hoverRoot:AddChild(Text(FALLBACK_FONT_FULL, HOVER_TITLE_FONT_SIZE, ""))
  self.hoverDesc   = nil
  self.currentHoverTitle = nil
  self.currentHoverDesc  = nil

  self:SetHoverWidget(self.hoverRoot, {
    attach_to_parent = self,
    offset_x         = 0,
    offset_y         = 0,
    show_delay       = 0.08,
    hide_delay       = 0.12,
  })
  self:SetHoverContent(nil, nil)
end)

function ArkTalentIcon:SetHoverContent(title, desc)
  local nextTitle = title or ""
  local nextDesc  = desc  or ""
  if self.currentHoverTitle == nextTitle and self.currentHoverDesc == nextDesc then
    return
  end
  self.currentHoverTitle = nextTitle
  self.currentHoverDesc  = nextDesc

  if nextTitle == "" and nextDesc == "" then
    self.hoverRoot:Hide()
    return
  end

  self.hoverRoot:Show()
  if self.hoverDesc then
    self.hoverDesc:Kill()
    self.hoverDesc = nil
  end

  local contentWidth = HOVER_WIDTH - HOVER_PADDING * 2
  local leftOffset   = -HOVER_WIDTH / 2 + HOVER_PADDING
  local topOffset    = -HOVER_PADDING

  self.hoverTitle:SetString(nextTitle)
  local titleW, titleH = self.hoverTitle:GetRegionSize()
  self.hoverTitle:SetRegionSize(contentWidth, titleH)
  self.hoverTitle:SetHAlign(ANCHOR_LEFT)
  self.hoverTitle:SetVAlign(ANCHOR_TOP)
  self.hoverTitle:SetPosition(leftOffset + contentWidth / 2, topOffset - titleH / 2, 0)
  topOffset = topOffset - titleH

  if nextDesc ~= "" then
    topOffset = topOffset - 10
    self.hoverDesc = self.hoverRoot:AddChild(ArkTalentDescText(nextDesc, contentWidth))
    local _, descH = self.hoverDesc:GetSize()
    self.hoverDesc:SetPosition(0, topOffset, 0)
    topOffset = topOffset - descH
  end

  local height = -topOffset + HOVER_PADDING
  self.hoverBg:SetSize(HOVER_WIDTH, height)
  self.hoverBg:SetPosition(0, -height / 2, 0)
  self.hoverRoot:SetPosition(-ICON_SIZE / 2 + HOVER_WIDTH / 2, ICON_SIZE / 2 + height + 10, 0)
end

function ArkTalentIcon:SetTexture(atlas, tex)
  self.iconImage:SetTexture(atlas, tex)
  self.iconImage:SetSize(ICON_SIZE, ICON_SIZE)
end

function ArkTalentIcon:SetLevel(level)
  if level and level > 1 then
    self.levelText:SetString(tostring(level))
    self.levelBadge:Show()
  else
    self.levelBadge:Hide()
  end
end

function ArkTalentIcon:GetSize()
  return ICON_SIZE, ICON_SIZE
end

-- 由 replica 或本地同步调用，根据 status/level 更新显示
function ArkTalentIcon:SyncTalentStatus(status, level)
  local isActive = status == CONSTANTS.TALENT_STATUS.ACTIVE
  if isActive then
    self:Show()
    self:SetLevel(level)
    -- 刷新悬浮描述，读取天赋当前等级的 desc
    if self.talentId then
      local ok, cfg = pcall(GetArkTalentConfigById, self.talentId)
      if ok and cfg then
        local lvlCfg = cfg.levels[level] or cfg.levels[1]
        self:SetHoverContent(cfg.name, lvlCfg and lvlCfg.desc or "")
      end
    end
  else
    -- 锁定的天赋不在 UI 中显示
    self:Hide()
  end
end

-- 由 ark_talents 容器在 AddTalent 时注入
function ArkTalentIcon:SetTalentId(id)
  self.talentId = id
end

return ArkTalentIcon
