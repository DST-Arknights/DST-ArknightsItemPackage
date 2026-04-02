local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local BorderWidget = require "widgets/border_widget"

local PANEL_MIN_SCALE = 0.25
local PANEL_OPEN_TIME = 0.105
local ICON_SIZE = 64
local ICON_COLUMNS = 3
local ICON_SPACING_X = 10
local ICON_SPACING_Y = 10
local PANEL_PADDING_X = 14
local PANEL_PADDING_TOP = 14
local PANEL_PADDING_BOTTOM = 12
local DOT_SIZE = 4
local DOT_GAP = 8
local DOT_SECTION_HEIGHT = 14

local function GetPageRowCount(group)
	local count = group and group.icons and #group.icons or 0
	if count <= 0 then
		return 1
	end
	return math.ceil(count / ICON_COLUMNS)
end

local function GetPanelWidth()
	return PANEL_PADDING_X * 2 + ICON_COLUMNS * ICON_SIZE + (ICON_COLUMNS - 1) * ICON_SPACING_X
end

local function GetContentHeightForRows(row_count)
	return row_count * ICON_SIZE + math.max(0, row_count - 1) * ICON_SPACING_Y
end

local EmoticonBtn = Class(Widget, function(self)
	Widget._ctor(self, "EmoticonBtn")
	self.groups = {}
	self.groupPages = {}
	self.groupDots = {}
	self.currentGroupIndex = 1
	self.isPanelOpen = false
	self.buttonPosition = { x = 0, y = 0 }
	self.panelPosition = { x = 0, y = 0 }
	self.panelWidth = GetPanelWidth()
	self.panelHeight = PANEL_PADDING_TOP + GetContentHeightForRows(1) + DOT_SECTION_HEIGHT + PANEL_PADDING_BOTTOM

	self.button = self:AddChild(ImageButton("images/emoticon_btn.xml", "emoticon_btn.tex"))
	self.button:SetPosition(0, 0, 0)
	self.button:SetOnClick(function()
		self:TogglePanel()
	end)

	self.panelRoot = self:AddChild(Widget("emoticonPanelRoot"))
	self.panelRoot:Hide()
	self.panelRoot:SetScale(PANEL_MIN_SCALE, PANEL_MIN_SCALE, 1)

	self.panelBg = self.panelRoot:AddChild(BorderWidget(self.panelWidth, self.panelHeight, {
    borderWidth = 2,
    borderColor = { 0.45, 0.45, 0.45, 0.9 },
    backgroundColor = { 0.23, 0.23, 0.23, 0.7 },
	}))

	self.contentRoot = self.panelRoot:AddChild(Widget("contentRoot"))
	self.dotsRoot = self.panelRoot:AddChild(Widget("dotsRoot"))

	self:RefreshGroups()
	self:RefreshPanelMetrics()
	self:RefreshPage()
	self:ApplyAnchors()
end)

function EmoticonBtn:GetPanelOpenHeight()
	return self.isPanelOpen and self.panelHeight or 0
end

function EmoticonBtn:GetButtonHeight()
	local _, height = self.button.image:GetSize()
	return height
end

function EmoticonBtn:GetButtonWidth()
	local width = self.button.image:GetSize()
	return width
end

function EmoticonBtn:RefreshGroups()
	self.groups = GetRegisteredChatEmoticons() or {}
	if self.currentGroupIndex > #self.groups then
		self.currentGroupIndex = math.max(1, #self.groups)
	end

	for _, page in ipairs(self.groupPages) do
		page:Kill()
	end
	self.groupPages = {}

	for _, dot in ipairs(self.groupDots) do
		dot:Kill()
	end
	self.groupDots = {}

	for groupIndex, group in ipairs(self.groups) do
		local page = self.contentRoot:AddChild(Widget("emoticonGroupPage"..groupIndex))
		page:Hide()
		self.groupPages[groupIndex] = page

		for iconIndex, icon in ipairs(group.icons or {}) do
			local iconButton = page:AddChild(ImageButton(icon.atlas, icon.tex, icon.tex, icon.tex, icon.tex))
			local width, height = iconButton.image:GetSize()
			iconButton:SetScale(ICON_SIZE / width, ICON_SIZE / height, 1)
			iconButton:SetFocusScale(1.05, 1.05, 1.05)
			iconButton:SetOnClick(function()
				if type(icon.emoticon_code) == "string" then
					TheNet:Say(icon.emoticon_code, false)
					self:ClosePanel()
				end
			end)

			local row = math.floor((iconIndex - 1) / ICON_COLUMNS)
			local column = (iconIndex - 1) % ICON_COLUMNS
			local pageRows = GetPageRowCount(group)
			local contentHeight = GetContentHeightForRows(pageRows)
			local startX = -self.panelWidth * 0.5 + PANEL_PADDING_X + ICON_SIZE * 0.5
			local startY = contentHeight * 0.5 - ICON_SIZE * 0.5
			local x = startX + column * (ICON_SIZE + ICON_SPACING_X)
			local y = startY - row * (ICON_SIZE + ICON_SPACING_Y)
			iconButton:SetPosition(x, y, 0)
		end

		local dot = self.dotsRoot:AddChild(Image("images/ui.xml", "white.tex"))
		dot:SetSize(DOT_SIZE, DOT_SIZE)
		self.groupDots[groupIndex] = dot
	end
end

function EmoticonBtn:RefreshPanelMetrics()
	local maxRows = 1
	for _, group in ipairs(self.groups) do
		maxRows = math.max(maxRows, GetPageRowCount(group))
	end

	self.panelWidth = GetPanelWidth()
	self.panelHeight = PANEL_PADDING_TOP + GetContentHeightForRows(maxRows) + DOT_SECTION_HEIGHT + PANEL_PADDING_BOTTOM
	self.panelBg:SetSize(self.panelWidth, self.panelHeight)

	local contentY = PANEL_PADDING_BOTTOM + DOT_SECTION_HEIGHT + GetContentHeightForRows(maxRows) * 0.5 - self.panelHeight * 0.5
	self.contentRoot:SetPosition(0, contentY, 0)

	local dotsCount = math.max(#self.groupDots, 1)
	local dotsWidth = dotsCount * DOT_SIZE + math.max(0, dotsCount - 1) * DOT_GAP
	local dotStartX = -dotsWidth * 0.5 + DOT_SIZE * 0.5
	local dotY = -self.panelHeight * 0.5 + PANEL_PADDING_BOTTOM + DOT_SIZE * 0.5
	self.dotsRoot:SetPosition(0, 0, 0)
	for index, dot in ipairs(self.groupDots) do
		dot:SetPosition(dotStartX + (index - 1) * (DOT_SIZE + DOT_GAP), dotY, 0)
	end
end

function EmoticonBtn:RefreshPage()
	if #self.groups == 0 then
		self.currentGroupIndex = 1
	else
		self.currentGroupIndex = math.max(1, math.min(self.currentGroupIndex, #self.groups))
	end

	for index, page in ipairs(self.groupPages) do
		if index == self.currentGroupIndex then
			page:Show()
		else
			page:Hide()
		end
	end

	for index, dot in ipairs(self.groupDots) do
		if index == self.currentGroupIndex then
			dot:SetTint(1, 1, 1, 1)
		else
			dot:SetTint(0.45, 0.45, 0.45, 1)
		end
	end
end

function EmoticonBtn:SetAnchors(buttonX, buttonY, panelX, panelY)
	self.buttonPosition.x = buttonX or 0
	self.buttonPosition.y = buttonY or 0
	self.panelPosition.x = panelX or 0
	self.panelPosition.y = panelY or 0
	self:ApplyAnchors()
end

function EmoticonBtn:ApplyAnchors()
	self.button:SetPosition(self.buttonPosition.x, self.buttonPosition.y, 0)
	if self.isPanelOpen then
		self.panelRoot:SetPosition(self.panelPosition.x, self.panelPosition.y, 0)
	else
		local closedX, closedY = self:GetClosedPanelPosition()
		self.panelRoot:SetPosition(closedX, closedY, 0)
	end
end

function EmoticonBtn:GetClosedPanelPosition()
	local offsetX = self.panelWidth * (1 - PANEL_MIN_SCALE) * 0.5
	local offsetY = self.panelHeight * (1 - PANEL_MIN_SCALE) * 0.5
	return self.panelPosition.x - offsetX, self.panelPosition.y - offsetY
end

function EmoticonBtn:OpenPanel()
	if self.isPanelOpen then
		return
	end

	self:RefreshGroups()
	self:RefreshPanelMetrics()
	self:RefreshPage()

	self.isPanelOpen = true
	local closedX, closedY = self:GetClosedPanelPosition()
	self.panelRoot:Show()
	self.panelRoot:MoveTo(Vector3(closedX, closedY, 0), Vector3(self.panelPosition.x, self.panelPosition.y, 0), PANEL_OPEN_TIME)
	self.panelRoot:ScaleTo(PANEL_MIN_SCALE, 1, PANEL_OPEN_TIME)
end

function EmoticonBtn:ClosePanel()
	if not self.isPanelOpen then
		return
	end

	self.isPanelOpen = false
	local closedX, closedY = self:GetClosedPanelPosition()
	self.panelRoot:MoveTo(Vector3(self.panelPosition.x, self.panelPosition.y, 0), Vector3(closedX, closedY, 0), PANEL_OPEN_TIME, function()
		if self.panelRoot ~= nil and self.panelRoot.Hide ~= nil then
			self.panelRoot:Hide()
		end
	end)
	self.panelRoot:ScaleTo(1, PANEL_MIN_SCALE, PANEL_OPEN_TIME)
end

function EmoticonBtn:TogglePanel()
	if self.isPanelOpen then
		self:ClosePanel()
	else
		self:OpenPanel()
	end
end

function EmoticonBtn:CycleGroup(step)
	if #self.groups <= 1 then
		return false
	end

	local nextIndex = self.currentGroupIndex + step
	if nextIndex < 1 then
		nextIndex = #self.groups
	elseif nextIndex > #self.groups then
		nextIndex = 1
	end

	if nextIndex ~= self.currentGroupIndex then
		self.currentGroupIndex = nextIndex
		self:RefreshPage()
	end

	return true
end

function EmoticonBtn:OnMouseWheel(up)
	if self.isPanelOpen then
		return self:CycleGroup(up > 0 and -1 or 1)
	end
end

return EmoticonBtn
