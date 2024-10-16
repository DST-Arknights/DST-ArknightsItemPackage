local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"

containers.params.ark_item_pack = {
  widget = {
    slotpos = {},
    animbank = nil,
    animbuild = nil,
    bgatlas = nil,
    bgimage = nil,
    musha_scroll = {
      num_columns = 6,
      num_visible_rows = 8,
      widget_width = 75,
      widget_height = 75
    },
    pos = Vector3(-340, -60, 0)
  },
  itemtestfn = function(container, item, slot) return item:HasTag("ark_item") end,
  issidewidget = true,
  type = "ark_item_pack"
}

for _ = 1, 640 do
  table.insert(containers.params.ark_item_pack.widget.slotpos, Vector3(0, 0, 0))
end
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
local function newcontainerwidgetbutton(self)

  local oldOpen = self.Open
  self.Open = function(self, container, doer)
    local res = {oldOpen(self, container, doer)}
    local widget = container.replica.container:GetWidget()
    if widget ~= containers.params.ark_item_pack.widget or not widget.musha_scroll or self.options_scroll_list then
      return unpack(res)
    end

    local num_visible_rows = widget.musha_scroll.num_visible_rows or 5
    local num_columns = widget.musha_scroll.num_columns or 5
    local widget_width = widget.musha_scroll.widget_width or 75
    local widget_height = widget.musha_scroll.widget_height or 75

    for k, v in pairs(self.inv) do
      v:SetPosition(Vector3(0, 0, 0))
      v:Hide()
    end

    local function ScrollWidgetsCtor(context, idx)
      local widget = Widget("option" .. idx)
      if self.inv[idx] then
        widget:AddChild(self.inv[idx])
        widget.inv = self.inv[idx]
        widget.inv:Show()
      end

      return widget
    end
    local function ApplyDataToWidget(context, widget, data, idx)
      if data then
        local inv = widget.inv
        if inv then
          inv:ClearFocus()
        end

        widget:AddChild(data)
        widget.inv = data
        widget.inv:Show()
      end
    end
    self.options_scroll_list = self:AddChild(TEMPLATES.ScrollingGrid(self.inv, {
      scroll_context = {},
      peek_height = 0,
      peek_percent = nil,
      widget_width = widget_width,
      widget_height = widget_height,
      num_visible_rows = num_visible_rows,
      num_columns = num_columns,
      end_offset = 3,
      allow_bottom_empty_row = true,
      item_ctor_fn = ScrollWidgetsCtor,
      apply_fn = ApplyDataToWidget,
      scrollbar_offset = 20,
      scrollbar_height_offset = -60,
      scissor_pad = 7
    }))

    local old_OnFocusMove = self.options_scroll_list.OnFocusMove
    function self.options_scroll_list:OnFocusMove(dir, down)
      if dir == MOVE_UP or dir == MOVE_DOWN then
        return false
      end
      return old_OnFocusMove(self, dir, down)
    end

    local old_OnControl = self.options_scroll_list.OnControl
    function self.options_scroll_list:OnControl(control, down)
      local time = GetStaticTime()
      local result = old_OnControl(self, control, down)
      if down and (self.focus or FunctionOrValue(self.custom_focus_check)) and self.scroll_bar:IsVisible() then
        if control == self.control_up or control == self.control_down then
          if ThePlayer and ThePlayer.components.playercontroller then
            ThePlayer.components.playercontroller.lastzoomtime = time
          end
        end
      end
      return result
    end

    if widget.musha_pos then
      self.options_scroll_list:SetPosition(widget.musha_pos)
    end

    self.musha_scroll_onitemgetfn = function(inst, data)
      if self.options_scroll_list then
        self.options_scroll_list:RefreshView()
      end
    end
    self.inst:ListenForEvent("itemget", self.musha_scroll_onitemgetfn, container)
  end

  local oldClose = self.Close
  self.Close = function(self)
    local widget = self.container and self.container.replica.container:GetWidget()
    if not widget or widget ~= containers.params.ark_item_pack.widget or not self.isopen then
      return oldClose(self)
    end
    if self.musha_scroll_onitemgetfn then
      self.inst:RemoveEventCallback("itemget", self.musha_scroll_onitemgetfn, self.container)
      self.musha_scroll_onitemgetfn = nil
    end
    if self.options_scroll_list then
      self.options_scroll_list:Kill()
      self.options_scroll_list = nil
    end
    return oldClose(self)
  end
end
AddClassPostConstruct("widgets/containerwidget", newcontainerwidgetbutton)
