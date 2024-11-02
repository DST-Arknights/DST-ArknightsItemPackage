local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local common = require("ark_common")

local itemSlotRealIndexMap = {}

local function canPutItemInArkItemPack(item) return item and item:HasTag("ark_item_pack_item") end

local function itemtestfn(container, item, slot)
  -- 只有指定物品能放在指定位置
  if not slot then
    return canPutItemInArkItemPack(item)
  end
  local res = itemSlotRealIndexMap[item.prefab] == slot
  return res
end
containers.params.ark_item_pack = {
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
    pos = Vector3(-340, -60, 0),
    animbuild_upgraded = 'ark_item_pack_bg',
    animbuild = 'ark_item_pack_bg',
    animbank_upgraded = 'ark_item_pack_bg',
    animbank = 'ark_item_pack_bg',
    animloop = true,
  },
  usespecificslotsforitems = true,
  itemtestfn = itemtestfn,
  issidewidget = true,
  type = "ark_item_pack",
  openlimit = 1
}

local numColumns = containers.params.ark_item_pack.widget.musha_scroll.num_columns
local slotPos = containers.params.ark_item_pack.widget.slotpos
local slotBg = containers.params.ark_item_pack.widget.slotbg

local allItemsInPack = {}
for _, item in ipairs(common.getAllArkItemDeclare()) do
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
    inv[i]:SetHoverText(common.getCommonI18n('itemInvSlotDescriptionPrefix') .. ' '
                          .. STRINGS.NAMES[string.upper(allItemsInPack[i].prefab)])
    inv[i]:SetLabel(STRINGS.NAMES[string.upper(allItemsInPack[i].prefab)])
  end
  return inv
end

local function isArkItemPack(inst) return inst.replica.container and inst.replica.container.type == "ark_item_pack" end

AddClassPostConstruct("widgets/containerwidget", function(self)
  local _Open = self.Open
  self.Open = function(self, container, doer)
    local res = {_Open(self, container, doer)}
    local widget = container.replica.container:GetWidget()
    local isinfinitestacksize = container.replica.container:IsInfiniteStackSize()
    print('背景动画设置', widget.animbank, widget.animbuild, widget.animbank_upgraded, widget.animbuild_upgraded, isinfinitestacksize)
    if widget.animbank ~= nil then
      local animbank = isinfinitestacksize and widget.animbank_upgraded or widget.animbank
      print('背景动画', animbank)
    end

    if widget.animbuild ~= nil then
        local animbuild = isinfinitestacksize and widget.animbuild_upgraded or widget.animbuild
        print('背景动画', animbuild)
      end
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
        scroll_bar_bar_atlas = "images/ark_pack_item_ui/scrollbar_bar.xml",
        scroll_bar_bar_image = "scrollbar_bar.tex",
        scroll_bar_handle_atlas = "images/ark_pack_item_ui/scrollbar_handle.xml",
        scroll_bar_handle_image = "scrollbar_handle.tex",
      },
      peek_height = 6,
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

AddClientModRPCHandler('ark_item', 'inventoryBounce', function(slot)
  if not ThePlayer then
    return
  end
  local slotInv = ThePlayer.HUD.controls.inv.inv[slot]
  if slotInv then
    slotInv:ScaleTo(1, 1.25, .125, function() slotInv:ScaleTo(1.25, 1, .125) end)
  end
end)

AddComponentPostInit("inventory", function(self)
  local _GiveItem = self.GiveItem
  self.GiveItem = function(self, item, slot, src_pos)
    -- 只能保留一个背包, 另一个丢下
    if isArkItemPack(item) then
      for k, v in pairs(self.itemslots) do
        if isArkItemPack(v) then
          self:DropItem(v)
          v.components.container:Close()
          return self:GiveItem(item, k, src_pos)
        end
      end
    end
    if canPutItemInArkItemPack(item) then
      local ark_item_pack = self:GetOpenedArkItemPack()
      if ark_item_pack then
        self._opened_ark_item_pack_overflow = ark_item_pack
      end
    end
    local res = {_GiveItem(self, item, slot, src_pos)}
    self._opened_ark_item_pack_overflow = nil
    if isArkItemPack(item) then
      -- 找到自己在inventory中的index, 标记上
      for k, v in pairs(self.itemslots) do
        if v == item then
          item.components.container._indexInInventory = k
          break
        end
      end
      if not self.opencontainers[item] then
        self.opencontainers[item] = true
        self.inst:DoTaskInTime(0, function()
          item.components.container:Open(self.inst)
          self.inst:DoTaskInTime(0, function()
            item.components.container:Close()
          end)
        end)
      end
    end
    return unpack(res)
  end

  local _RemoveItem = self.RemoveItem
  self.RemoveItem = function(self, item, ...)
    local res = {_RemoveItem(self, item, ...)}
    if isArkItemPack(item) then
      local isOpen = item.components.container:IsOpen()
      if not isOpen and self.opencontainers[item] then
        self.opencontainers[item] = nil
        -- 给replica打标机, 真正的卸载
        item.replica.container._allowRemoveOpener = true
        item.replica.container:RemoveOpener(self.inst)
        item.replica.container._allowRemoveOpener = nil
      end
    end
    return unpack(res)
  end

  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  self.MoveItemFromAllOfSlot = function(self, slot, container)
    if not isArkItemPack(container) then
      return _MoveItemFromAllOfSlot(self, slot, container)
    end
    container.components.container._tempOpenedBy = true
    _MoveItemFromAllOfSlot(self, slot, container)
    container.components.container._tempOpenedBy = nil
  end

  local _MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  self.MoveItemFromHalfOfSlot = function(self, slot, container)
    if not isArkItemPack(container) then
      return _MoveItemFromHalfOfSlot(self, slot, container)
    end
    container.components.container._tempOpenedBy = true
    _MoveItemFromHalfOfSlot(self, slot, container)
    container.components.container._tempOpenedBy = nil
  end

  local _GetOverflowContainer = self.GetOverflowContainer
  self.GetOverflowContainer = function(self)
    if self._opened_ark_item_pack_overflow and not self._opened_ark_item_pack_overflow.components.container._moveOutItem then
      return self._opened_ark_item_pack_overflow.components.container
    end
    return _GetOverflowContainer(self)
  end

  local _GetNextAvailableSlot = self.GetNextAvailableSlot
  self.GetNextAvailableSlot = function(self, item)
    -- 如果物品没有ark_item标签, 直接调用原函数
    if self._opened_ark_item_pack_overflow then
      if item and item == self._opened_ark_item_pack_overflow.components.container._moveOutItem then
        return _GetNextAvailableSlot(self, item)
      end
      local itemSlotRealIndex = itemSlotRealIndexMap[item.prefab]
      local existItem = self._opened_ark_item_pack_overflow.components.container:GetItemInSlot(itemSlotRealIndex)
      if not existItem or not existItem.components.stackable:IsFull() then
        return itemSlotRealIndex, self._opened_ark_item_pack_overflow.components.container
      end
    end
    -- 如果没有找到, 调用原函数
    return _GetNextAvailableSlot(self, item)
  end

  self.GetOpenedArkItemPack = function(self)
    for container, _ in pairs(self.opencontainers) do
      if isArkItemPack(container) then
        return container
      end
    end
    return nil
  end
end)
AddClassPostConstruct('components/inventory_replica', function(self)
  local _GetOverflowContainer = self.GetOverflowContainer
  function self:GetOverflowContainer()
    local items = self:GetItems()
    for i, v in pairs(items) do
      if isArkItemPack(v) then
        return v.replica.container
      end
    end
    return _GetOverflowContainer(self)
  end
  local _Has = self.Has
end)

AddComponentPostInit('stackable', function(self)
  local _Put = self.Put
  function self:Put(item, source_pos)
    if not canPutItemInArkItemPack(item) then
      return _Put(self, item, source_pos)
    end
    local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
    if owner then
      if isArkItemPack(owner) then
        if owner.components.container._indexInInventory then
          SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), owner.userid, owner.components.container._indexInInventory)
        end
        -- local inventory = owner.components.inventoryitem and owner.components.inventoryitem.owner.components.inventory
        -- if inventory then
        --   local index = nil
        --   for k, v in pairs(inventory.itemslots) do
        --     if v == owner then
        --       index = k
        --       break
        --     end
        --   end
        --   if index then
        --     SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"),
        --       owner.components.inventoryitem.owner.userid, index, self.owner)
        --   end
        -- end
      end
    end
    return _Put(self, item, source_pos)
  end
end)

AddComponentPostInit("container", function(self)
  local _GiveItem = self.GiveItem
  function self:GiveItem(item, slot, ...)
    local res = _GiveItem(self, item, slot, ...)
    if not isArkItemPack(self.inst) then
      return res
    end
    local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
    if not self:IsOpen() and owner and self._indexInInventory then
      SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), owner.userid, self._indexInInventory)
    end
    return res
  end

  local _Open = self.Open
  function self:Open(doer)
    self.inst.replica.container._allowRemoveOpener = true
    local res = {_Open(self, doer)}
    self.inst.replica.container._allowRemoveOpener = nil
    if not isArkItemPack(self.inst) then
      return unpack(res)
    end
    -- StackTraceToLog()
    self.inst.replica.container.__ArkIsOpen:set(true)
    return unpack(res)
  end

  local _Close = self.Close
  function self:Close(doer)
    -- 关闭的时候, 如果有owner, 保持 opencontainers 中有它
    if not isArkItemPack(self.inst) then
      return _Close(self, doer)
    end
    local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
    if not owner then
      self.inst.replica.container._allowRemoveOpener = true
    end
    local res = {_Close(self, doer)}
    self.inst.replica.container.__ArkIsOpen:set(false)
    if not owner then
      self.inst.replica.container._allowRemoveOpener = nil
    elseif owner and owner.components.inventory then
      owner.components.inventory.opencontainers[self.inst] = true
    end
    return unpack(res)
  end

  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  function self:MoveItemFromAllOfSlot(slot, container, opener)
    if not isArkItemPack(self.inst) then
      return _MoveItemFromAllOfSlot(self, slot, container, opener)
    end
    local item = self:GetItemInSlot(slot)
    self._moveOutItem = item
    _MoveItemFromAllOfSlot(self, slot, container, opener)
    self._moveOutItem = nil
  end

  local MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container, opener)
    if not isArkItemPack(self.inst) then
      return MoveItemFromHalfOfSlot(self, slot, container, opener)
    end
    local item = self:GetItemInSlot(slot)
    self._moveOutItem = item
    MoveItemFromHalfOfSlot(self, slot, container, opener)
    self._moveOutItem = nil
  end

  local _IsOpenedBy = self.IsOpenedBy
  function self:IsOpenedBy(doer)
    if not isArkItemPack(self.inst) then
      return _IsOpenedBy(self, doer)
    end
    if self._tempOpenedBy then
      return true
    end
    return _IsOpenedBy(self, doer)
  end
end)

AddClassPostConstruct('components/container_replica', function(self)
  self.__ArkIsOpen = net_bool(self.inst.GUID, "container_replica.__ArkIsOpen", "container_replica.__ArkIsOpen_dirty")
  if not TheWorld.ismastersim then
    self.inst:ListenForEvent("container_replica.__ArkIsOpen_dirty", function()
      if not self.__ArkIsOpen:value() then
        self:Close()
      end
    end)
  end

  local count = 0
  local _AttachOpener = self.AttachOpener
  function self:AttachOpener(opener)
    if not isArkItemPack(self.inst) then
      return _AttachOpener(self, opener)
    end
    print(debugstack())
    count = count + 1
    print("AttachOpener", count)
    return _AttachOpener(self, opener)
  end

  local detachCount = 0
  local _DetachOpener = self.DetachOpener
  function self:DetachOpener(opener)
    if not isArkItemPack(self.inst) then
      return _AttachOpener(self, opener)
    end
    if not self.ondetachopener then
      return
    end
    print(debugstack())
    detachCount = detachCount + 1
    print("DetachOpener", detachCount)
    return _DetachOpener(self, opener)
  end

  local _IsOpenedBy = self.IsOpenedBy
  function self:IsOpenedBy(doer)
    if isArkItemPack(self.inst) then
      return self._isopen
    end
    return _IsOpenedBy(self, doer)
  end

  local _RemoveOpener = self.RemoveOpener
  function self:RemoveOpener(opener)
    if not isArkItemPack(self.inst) then
      return _RemoveOpener(self, opener)
    end
    if self._allowRemoveOpener then
      return _RemoveOpener(self, opener)
    end
  end
end)

AddPrefabPostInit("inventory_classified", function(self)
  local _SetSlotItem = self.SetSlotItem

  local _GetOverflowContainer = self.GetOverflowContainer
  function self:GetOverflowContainer()
    local items = self:GetItems()
    for i, v in pairs(items) do
      if isArkItemPack(v) then
        return v.replica.container
      end
    end
    return _GetOverflowContainer(self)
  end

  local _MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container)
    if self._busy or self._parent == nil then
      return
    end
    local item = self:GetItemInSlot(slot)
    if canPutItemInArkItemPack(item) then
      local container_classified = container ~= nil and container.replica.container ~= nil
                                     and container.replica.container.classified or nil
      if not container_classified then
        SendRPCToServer(RPC.MoveInvItemFromHalfOfSlot, slot, container)
        return
      end
    end
    _MoveItemFromHalfOfSlot(self, slot, container)
  end

  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  function self:MoveItemFromAllOfSlot(slot, container)
    if self._busy or self._parent == nil then
      return
    end
    local item = self:GetItemInSlot(slot)
    if canPutItemInArkItemPack(item) then
      local container_classified = container ~= nil and container.replica.container ~= nil
                                     and container.replica.container.classified or nil
      if not container_classified then
        SendRPCToServer(RPC.MoveInvItemFromAllOfSlot, slot, container)
        return
      end
    end
    _MoveItemFromAllOfSlot(self, slot, container)
  end

end)

local truescrolllist = require "widgets/truescrolllist"

local _BuildScrollBar = truescrolllist.BuildScrollBar
function truescrolllist:BuildScrollBar()
  _BuildScrollBar(self)
  if self.context.scroll_bar_bar_atlas and self.context.scroll_bar_bar_image then
    self.scroll_bar_line:SetTexture(self.context.scroll_bar_bar_atlas, self.context.scroll_bar_bar_image)
  end
  if self.context.scroll_bar_handle_atlas and self.context.scroll_bar_handle_image then
    self.position_marker.image:SetTexture(self.context.scroll_bar_handle_atlas, self.context.scroll_bar_handle_image)
  end
end

-- 重新计算最大值
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
