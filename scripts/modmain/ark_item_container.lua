local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local common = require("ark_common")

RegisterInventoryItemAtlas('images/ark_backpack.xml', 'ark_backpack.tex')

local itemSlotRealIndexMap = {}

local function canPutItemInArkItemPack(item) return item and item:HasTag("ark_backpack_item") end

local function itemtestfn(container, item, slot)
  -- 只有指定物品能放在指定位置
  if not slot then
    return canPutItemInArkItemPack(item)
  end
  local res = itemSlotRealIndexMap[item.prefab] == slot
  return res
end
containers.params.ark_backpack = {
  widget = {
    slotpos = {},
    slotbg = {},
    bgatlas = nil,
    bgimage = nil,
    musha_scroll = {
      num_columns = 6,
      num_visible_rows = 8,
      widget_width = 80,
      widget_height = 86
    },
    pos = Vector3(340, -60, 0),
    animbuild_upgraded = 'ark_backpack_bg',
    animbuild = 'ark_backpack_bg',
    animbank_upgraded = 'ark_backpack_bg',
    animbank = 'ark_backpack_bg',
    animloop = true,
  },
  usespecificslotsforitems = true,
  itemtestfn = itemtestfn,
  issidewidget = false,
  type = "ark_backpack",
  openlimit = 1
}

local numColumns = containers.params.ark_backpack.widget.musha_scroll.num_columns
local slotPos = containers.params.ark_backpack.widget.slotpos
local slotBg = containers.params.ark_backpack.widget.slotbg

local allItemsInPack = {}
for _, item in ipairs(require('ark_item_declare')) do
  if not item.disablePutInPack then
    table.insert(allItemsInPack, item)
  end
end

for i, item in ipairs(allItemsInPack) do
  table.insert(slotPos, Vector3(0, 0, 0))
  local assets = common.getPrefabAssetsCode(item.prefab)
  table.insert(slotBg, {
    atlas = assets.slotbgatlas,
    image = assets.slotbgimage
  })
  table.insert(Assets, Asset("ATLAS", assets.slotbgatlas))
  itemSlotRealIndexMap[item.prefab] = i
end

local function GroupInv(inv)
  for i, v in ipairs(inv) do
    inv[i] = inv[i] or Widget("option" .. i)
    inv[i]:SetLabel(STRINGS.NAMES[string.upper(allItemsInPack[i].prefab)])
  end
  return inv
end

local function isArkItemPack(inst) return inst.replica.container and inst.replica.container.type == "ark_backpack" end

AddClassPostConstruct("widgets/containerwidget", function(self)
  local _Open = self.Open
  self.Open = function(self, container, doer)
    local res = {_Open(self, container, doer)}
    local widget = container.replica.container:GetWidget()
    if not isArkItemPack(container) or not widget.musha_scroll or self.options_scroll_list then
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
      local item = context.items[idx]
      local widget = Widget("option" .. idx)
      if item then
        widget.item = widget:AddChild(item)
        item:Show()
      end
      return widget
    end
    local function ApplyDataToWidget(context, widget, data, idx)
      local children = widget:GetChildren()
      for k, v in pairs(children) do
        v:ClearFocus()
        widget:RemoveChild(v)
        v:Hide()
      end
      local item = context.items[idx]
      if item then
        widget.item = widget:AddChild(item)
        item:ClearFocus()
        item:Show()
      end
    end
    local items = GroupInv(self.inv)
    self.options_scroll_list = self:AddChild(TEMPLATES.ScrollingGrid(items, {
      scroll_context = {
        items = items,
        widget = self,
        container = container,
      },
      peek_height = 26,
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

  local _Close = self.Close
  self.Close = function(self, doer)
    if self.container and isArkItemPack(self.container) and self.isopen then
      if self.musha_scroll_onitemgetfn then
        self.inst:RemoveEventCallback("itemget", self.musha_scroll_onitemgetfn, self.container)
        self.musha_scroll_onitemgetfn = nil
      end
      if self.options_scroll_list then
        self.options_scroll_list:Kill()
        self.options_scroll_list = nil
      end
    end
    return _Close(self)
  end
end)

-- AddClassPostConstruct('widgets/inventorybar', function (self)
--   local _Rebuild = self.Rebuild
--   self.Rebuild = function(self)
--     self.owner.replica.inventory._disableOverflowArkItemPack = true
--     local res = {_Rebuild(self)}
--     self.owner.replica.inventory._disableOverflowArkItemPack = nil
--     return unpack(res)
--   end
-- end)

AddClientModRPCHandler('ark_item', 'inventoryBounce', function(slot)
  if not ThePlayer then
    return
  end
  local slotInv = ThePlayer.HUD.controls.inv.inv[slot]
  if slotInv then
    slotInv:ScaleTo(1, 1.25, .125, function() slotInv:ScaleTo(1.25, 1, .125) end)
    local slotItem = ThePlayer.replica.inventory:GetItemInSlot(slot)
    local isOpen = slotItem and slotItem.replica.container and slotItem.replica.container._isopen
    if not isOpen then
      TheFocalPoint.SoundEmitter:PlaySound(PICKUPSOUNDS["DEFAULT_FALLBACK"])
    end
  end
end)

AddComponentPostInit("inventory", function(self)
  local _GiveItem = self.GiveItem
  self.GiveItem = function(self, item, slot, src_pos)
    -- 只能保留一个背包, 另一个丢下
    if isArkItemPack(item) then
      local arkItemPack, index = self:findArkItemPack()
      if arkItemPack then
        self:DropItem(arkItemPack)
        arkItemPack.components.container:Close()
        return self:GiveItem(item, index, src_pos)
      end
      self.opencontainers[item] = true
    end
    if slot then
      return _GiveItem(self, item, slot, src_pos)
    end
    if self._tempNotGiveArkPack then
      return _GiveItem(self, item, slot, src_pos)
    end
    if canPutItemInArkItemPack(item) then
      local arkItemPack, index = self:findArkItemPack()
      if arkItemPack then
        if arkItemPack.components.container._tempNotGiveArkPack then
          return _GiveItem(self, item, slot, src_pos)
        end
        SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), self.inst.userid, index)
        return arkItemPack.components.container:GiveItem(item, nil, src_pos)
      end
    end
    return _GiveItem(self, item, slot, src_pos)
  end

  local _RemoveItem = self.RemoveItem
  self.RemoveItem = function(self, item, ...)
    local res = {_RemoveItem(self, item, ...)}
    if isArkItemPack(item) then
      local isOpen = item.components.container:IsOpen()
      if not isOpen and self.opencontainers[item] then
        self.opencontainers[item] = nil
      end
      self._ark_backpack = nil
      self._ark_backpack_index = nil
    end
    return unpack(res)
  end

  self.findArkItemPack = function(self)
    if self._ark_backpack then
      return self._ark_backpack, self._ark_backpack_index
    end
    for k, v in pairs(self.itemslots) do
      if isArkItemPack(v) then
        self._ark_backpack = v
        self._ark_backpack_index = k
        return v, k
      end
    end
  end

end)

-- AddComponentPostInit('stackable', function(self)
--   local _Put = self.Put
--   function self:Put(item, source_pos)
--     if not canPutItemInArkItemPack(item) then
--       return _Put(self, item, source_pos)
--     end
--     local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
--     if owner then
--       if isArkItemPack(owner) then
--         if owner.components.container._indexInInventory then
--           SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), owner.userid, owner.components.container._indexInInventory)
--         end
--       end
--     end
--     return _Put(self, item, source_pos)
--   end
-- end)

AddComponentPostInit("container", function(self)
  -- local _GiveItem = self.GiveItem
  -- function self:GiveItem(item, slot, ...)
  --   local res = _GiveItem(self, item, slot, ...)
  --   if not isArkItemPack(self.inst) then
  --     return res
  --   end
  --   local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
  --   if not self:IsOpen() and owner and self._indexInInventory then
  --     SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), owner.userid, self._indexInInventory)
  --   end
  --   return res
  -- end

  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  function self:MoveItemFromAllOfSlot(slot, container, opener)
    opener.components.inventory._tempNotGiveArkPack = true
    _MoveItemFromAllOfSlot(self, slot, container, opener)
    opener.components.inventory._tempNotGiveArkPack = nil
  end

  local _MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container, opener)
    opener.components.inventory._tempNotGiveArkPack = true
    _MoveItemFromHalfOfSlot(self, slot, container, opener)
    opener.components.inventory._tempNotGiveArkPack = nil
  end
end)

-- AddClassPostConstruct("screens/playerhud", function(self)
--   local OpenContainer = self.OpenContainer
--   function self:OpenContainer(container, side)
--     if isArkItemPack(container) then
--       side = nil
--     end
--     return OpenContainer(self, container, side)
--   end
-- end)

local truescrolllist = require "widgets/truescrolllist"

local _BuildScrollBar = truescrolllist.BuildScrollBar
function truescrolllist:BuildScrollBar()
  _BuildScrollBar(self)
  self.up_button:Hide()
  self.down_button:Hide()
  self.scroll_bar_line:Hide()
  self.position_marker:Hide()
end

-- 重新计算最大值
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
