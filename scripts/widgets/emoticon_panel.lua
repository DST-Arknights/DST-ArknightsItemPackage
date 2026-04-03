local Widget = require "widgets/widget"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local BorderWidget = require "widgets/border_widget"

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

local EmoticonPanel = Class(Widget, function(self, parent)
	Widget._ctor(self, "EmoticonPanel")
	self.parent = parent
	self.groups = {}
	self.groupPages = {}
	self.groupDots = {}
	self.currentGroupIndex = 1
	self.isAnimating = false
	self.panelWidth = GetPanelWidth()
	self.panelHeight = PANEL_PADDING_TOP + GetContentHeightForRows(1) + DOT_SECTION_HEIGHT + PANEL_PADDING_BOTTOM

	self:SetScale(0.25, 0.25, 1)
	self:Hide()

	self.panelBg = self:AddChild(BorderWidget(self.panelWidth, self.panelHeight, {
		borderWidth = 2,
		borderColor = { 0.45, 0.45, 0.45, 0.9 },
		backgroundColor = { 0.23, 0.23, 0.23, 0.7 },
	}))

	self.contentRoot = self:AddChild(Widget("contentRoot"))
	self.slideContainer = self.contentRoot:AddChild(Widget("slideContainer"))
	self.dotsRoot = self:AddChild(Widget("dotsRoot"))

	self:RefreshGroups()
	self:RefreshPanelMetrics()
	self:RefreshPage()
end)

function EmoticonPanel:GetPanelHeight()
	return self.panelHeight
end

function EmoticonPanel:GetPanelWidth()
	return self.panelWidth
end

function EmoticonPanel:RefreshGroups()
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
		local page = self.slideContainer:AddChild(Widget("emoticonGroupPage"..groupIndex))
		page:Hide()
		self.groupPages[groupIndex] = page

		for iconIndex, icon in ipairs(group.icons or {}) do
			local iconButton = page:AddChild(ImageButton(icon.atlas, icon.tex, icon.tex, icon.tex, icon.tex))
			local width, height = iconButton.image:GetSize()
			iconButton:SetScale(ICON_SIZE / width, ICON_SIZE / height, 1)
			iconButton:SetFocusScale(1.1, 1.1, 1.1)
			iconButton:SetOnClick(function()
				if type(icon.emoticon_code) == "string" then
					TheNet:Say(icon.emoticon_code, false)
					if self.parent and self.parent.ClosePanel then
						self.parent:ClosePanel()
					end
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

function EmoticonPanel:RefreshPanelMetrics()
	local maxRows = 1
	for _, group in ipairs(self.groups) do
		maxRows = math.max(maxRows, GetPageRowCount(group))
	end

	self.panelWidth = GetPanelWidth()
	self.panelHeight = PANEL_PADDING_TOP + GetContentHeightForRows(maxRows) + DOT_SECTION_HEIGHT + PANEL_PADDING_BOTTOM
	self.panelBg:SetSize(self.panelWidth, self.panelHeight)

	local contentHeight = GetContentHeightForRows(maxRows)
	local contentY = PANEL_PADDING_BOTTOM + DOT_SECTION_HEIGHT + contentHeight * 0.5 - self.panelHeight * 0.5
	self.contentRoot:SetPosition(0, contentY, 0)
	self.contentRoot:SetScissor(-self.panelWidth * 0.5, -contentHeight * 0.5, self.panelWidth, contentHeight)

	self.slideContainer:SetPosition(0, 0, 0)

	local dotsCount = math.max(#self.groupDots, 1)
	local dotsWidth = dotsCount * DOT_SIZE + math.max(0, dotsCount - 1) * DOT_GAP
	local dotStartX = -dotsWidth * 0.5 + DOT_SIZE * 0.5
	local dotY = -self.panelHeight * 0.5 + PANEL_PADDING_BOTTOM + DOT_SIZE * 0.5
	self.dotsRoot:SetPosition(0, 0, 0)
	for index, dot in ipairs(self.groupDots) do
		dot:SetPosition(dotStartX + (index - 1) * (DOT_SIZE + DOT_GAP), dotY, 0)
	end
end

function EmoticonPanel:RefreshPage()
	if #self.groups == 0 then
		self.currentGroupIndex = 1
	else
		self.currentGroupIndex = math.max(1, math.min(self.currentGroupIndex, #self.groups))
	end

	for index, page in ipairs(self.groupPages) do
		local offsetX = (index - self.currentGroupIndex) * self.panelWidth
		page:SetPosition(offsetX, 0, 0)
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

function EmoticonPanel:CycleGroup(step)
	if #self.groups <= 1 or self.isAnimating then
		return false
	end

	local nextIndex = self.currentGroupIndex + step
	if nextIndex < 1 then
		nextIndex = #self.groups
	elseif nextIndex > #self.groups then
		nextIndex = 1
	end

	if nextIndex == self.currentGroupIndex then
		return false
	end

	self.isAnimating = true
	local oldIndex = self.currentGroupIndex
	self.currentGroupIndex = nextIndex

	local currentPage = self.groupPages[oldIndex]
	local nextPage = self.groupPages[nextIndex]

	local slideDistance = self.panelWidth
	local currentToX = step > 0 and -slideDistance or slideDistance
	local nextFromX = step > 0 and slideDistance or -slideDistance

	currentPage:SetPosition(0, 0, 0)
	currentPage:Show()
	nextPage:SetPosition(nextFromX, 0, 0)
	nextPage:Show()

	local animTime = 0.3
	currentPage:MoveTo(Vector3(0, 0, 0), Vector3(currentToX, 0, 0), animTime)
	nextPage:MoveTo(Vector3(nextFromX, 0, 0), Vector3(0, 0, 0), animTime, function()
		currentPage:Hide()
		currentPage:SetPosition(0, 0, 0)
		nextPage:SetPosition(0, 0, 0)
		self.isAnimating = false
	end)

	for index, dot in ipairs(self.groupDots) do
		if index == self.currentGroupIndex then
			dot:SetTint(1, 1, 1, 1)
		else
			dot:SetTint(0.45, 0.45, 0.45, 1)
		end
	end

	return true
end

function EmoticonPanel:OnControl(control, down)
	if EmoticonPanel._base.OnControl(self, control, down) then
		return true
	end

	if down and self.focus and self:IsVisible() then
		if control == TheInput:ResolveVirtualControls(CONTROL_SCROLLBACK) then
			if self:CycleGroup(-1) then
				TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
			end
			PreventScrollZoom()
			return true
		elseif control == TheInput:ResolveVirtualControls(CONTROL_SCROLLFWD) then
			if self:CycleGroup(1) then
				TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover", nil, ClickMouseoverSoundReduction())
			end
			PreventScrollZoom()
			return true
		end
	end

	return false
end

return EmoticonPanel
