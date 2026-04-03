local Widget = require "widgets/widget"
local ImageButton = require "widgets/imagebutton"
local EmoticonPanel = require "widgets/emoticon_panel"

local PANEL_MIN_SCALE = 0.25
local PANEL_OPEN_TIME = 0.105

local EmoticonBtn = Class(Widget, function(self)
	Widget._ctor(self, "EmoticonBtn")
	self.currentGroupIndex = 1
	self.isPanelOpen = false
	self.buttonPosition = { x = 0, y = 0 }
	self.panelPosition = { x = 0, y = 0 }

	self.button = self:AddChild(ImageButton("images/emoticon_btn.xml", "emoticon_btn.tex"))
	self.button:SetPosition(0, 0, 0)
	self.button:SetOnClick(function()
		self:TogglePanel()
	end)

	self.panel = self:AddChild(EmoticonPanel(self))
	self.panel:Hide()
	self.panel:SetScale(PANEL_MIN_SCALE, PANEL_MIN_SCALE, 1)

	self:ApplyAnchors()
end)

function EmoticonBtn:GetPanelOpenHeight()
	return self.isPanelOpen and self.panel:GetPanelHeight() or 0
end

function EmoticonBtn:GetPanelWidth()
	return self.panel:GetPanelWidth()
end

function EmoticonBtn:GetPanelHeight()
	return self.panel:GetPanelHeight()
end

function EmoticonBtn:GetButtonHeight()
	local _, height = self.button.image:GetSize()
	return height
end

function EmoticonBtn:GetButtonWidth()
	local width = self.button.image:GetSize()
	return width
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
		self.panel:SetPosition(self.panelPosition.x, self.panelPosition.y, 0)
	else
		local closedX, closedY = self:GetClosedPanelPosition()
		self.panel:SetPosition(closedX, closedY, 0)
	end
end

function EmoticonBtn:GetClosedPanelPosition()
	local panelWidth = self.panel:GetPanelWidth()
	local panelHeight = self.panel:GetPanelHeight()
	local offsetX = panelWidth * (1 - PANEL_MIN_SCALE) * 0.5
	local offsetY = panelHeight * (1 - PANEL_MIN_SCALE) * 0.5
	return self.panelPosition.x - offsetX, self.panelPosition.y - offsetY
end

function EmoticonBtn:OpenPanel()
	if self.isPanelOpen then
		return
	end

	self.panel:RefreshGroups()
	self.panel:RefreshPanelMetrics()
	self.panel:RefreshPage()

	self.isPanelOpen = true
	local closedX, closedY = self:GetClosedPanelPosition()
	self.panel:Show()
	self.panel:MoveTo(Vector3(closedX, closedY, 0), Vector3(self.panelPosition.x, self.panelPosition.y, 0), PANEL_OPEN_TIME)
	self.panel:ScaleTo(PANEL_MIN_SCALE, 1, PANEL_OPEN_TIME)
end

function EmoticonBtn:ClosePanel()
	if not self.isPanelOpen then
		return
	end

	self.isPanelOpen = false
	local closedX, closedY = self:GetClosedPanelPosition()
	self.panel:MoveTo(Vector3(self.panelPosition.x, self.panelPosition.y, 0), Vector3(closedX, closedY, 0), PANEL_OPEN_TIME, function()
		if self.panel ~= nil and self.panel.Hide ~= nil then
			self.panel:Hide()
		end
	end)
	self.panel:ScaleTo(1, PANEL_MIN_SCALE, PANEL_OPEN_TIME)
end

function EmoticonBtn:TogglePanel()
	if self.isPanelOpen then
		self:ClosePanel()
	else
		self:OpenPanel()
	end
end

return EmoticonBtn
