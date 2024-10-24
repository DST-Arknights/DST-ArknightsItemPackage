local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local ark_item_declare = require("ark_item_declare")
local common = require("ark_common")

local itemSlotRealIndexMap = {}
local function itemtestfn(container, item, slot)
  -- 只有指定物品能放在指定位置
  if not slot then
    return item:HasTag("ark_item")
  end
  local res = itemSlotRealIndexMap[item.prefab] == slot
  return res
end
containers.params.ark_item_pack = {
  widget = {
    slotpos = {},
    slotbg = {},
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
  usespecificslotsforitems = true,
  itemtestfn = itemtestfn,
  issidewidget = true,
  type = "ark_item_pack"
}

local allItems = {}
local itemSlotReal = {}
local numColumns = containers.params.ark_item_pack.widget.musha_scroll.num_columns
local slotPos = containers.params.ark_item_pack.widget.slotpos
local slotBg = containers.params.ark_item_pack.widget.slotbg
for i, group in ipairs(ark_item_declare) do
  local groupTotalNum = math.ceil(#group.items / numColumns) * numColumns
  for j = 1, groupTotalNum do
    if group.items[j] then
      table.insert(slotPos, Vector3(0, 0, 0))
      local assets = common.getPrefabAssetsCode(group.items[j].prefab)
      table.insert(slotBg, {
        atlas = assets.slotbgatlas,
        image = assets.slotbgimage
      })
      itemSlotRealIndexMap[group.items[j].prefab] = #slotPos
      table.insert(allItems, group.items[j])
      table.insert(Assets, Asset("ATLAS", assets.slotbgatlas))
      table.insert(itemSlotReal, true)
    else
      table.insert(itemSlotReal, false)
    end
  end
end

local function GroupInv(inv)
  local result = {}
  local idx = 1
  for i, v in ipairs(itemSlotReal) do
    if v then
      if not inv[idx].tile then
        inv[idx]:SetHoverText(common.getCommonI18n('itemInvSlotDescriptionPrefix') .. ' '.. STRINGS.NAMES[string.upper(allItems[idx].prefab)])
      end
      inv[idx]:SetLabel(STRINGS.NAMES[string.upper(allItems[idx].prefab)])
      table.insert(result, inv[idx])
      idx = idx + 1
    else
      local widget = Widget("option" .. i)
      local img = Image("images/none.xml", "none.tex")
      -- img:SetSize(75, 75)
      widget:AddChild(img)
      -- 返回一个空widget
      table.insert(result, widget)
    end
  end
  return result
end

local function isArkItemPack(inst) return inst.replica.container and inst.replica.container.type == "ark_item_pack" end
local function newcontainerwidgetbutton(self)

  local oldOpen = self.Open
  self.Open = function(self, container, doer)
    local res = {oldOpen(self, container, doer)}
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
      scroll_context = { items = items, widget = self, container = container },
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
    return oldClose(self)
  end
end
AddClassPostConstruct("widgets/containerwidget", newcontainerwidgetbutton)

AddClientModRPCHandler('ark_item', 'inventoryBounce', function(slot)
  local slotInv = ThePlayer.HUD.controls.inv.inv[slot]
  if slotInv then
    slotInv:ScaleTo(1, 1.25, .125, function() slotInv:ScaleTo(1.25, 1, .125) end)
    local item = ThePlayer.replica.inventory:GetItemInSlot(slot)
    local sound = item and item.pickupsound or "DEFAULT_FALLBACK"
    sound = PICKUPSOUNDS[sound]
    if sound then
      TheFocalPoint.SoundEmitter:PlaySound(sound)
    end
  end
end)

AddComponentPostInit("container", function(self)
  local _GiveItem = self.GiveItem
  self.GiveItem = function(self, item, slot, ...)
    local res = _GiveItem(self, item, slot, ...)
    if isArkItemPack(self.inst) then
      local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
      if not self:IsOpen() and owner then
        -- 从inventory中找到自己的index
        local index = nil
        for k, v in pairs(owner.components.inventory.itemslots) do
          if v == self.inst then
            index = k
            break
          end
        end
        if index then
          SendModRPCToClient(GetClientModRPC("ark_item", "inventoryBounce"), owner.userid, index)
        end
      end
    end
    return res
  end
  local _Close = self.Close
  self.Close = function(self, doer)
    local res = {_Close(self, doer)}
    -- 关闭的时候, 如果有owner, 保持 opencontainers 中有它
    local owner = self.inst.components.inventoryitem and self.inst.components.inventoryitem.owner
    if isArkItemPack(self.inst) and doer and doer.components.inventory ~= nil and owner then
      doer.components.inventory.opencontainers[self.inst] = true
    end
    return unpack(res)
  end
  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  function self:MoveItemFromAllOfSlot(slot, container, opener)
    local item = self:GetItemInSlot(slot)
    self._moveOutItem = item
    _MoveItemFromAllOfSlot(self, slot, container, opener)
    self._moveOutItem = nil
  end
  local MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container, opener)
    local item = self:GetItemInSlot(slot)
    self._moveOutItem = item
    MoveItemFromHalfOfSlot(self, slot, container, opener)
    self._moveOutItem = nil
  end
  local _IsOpenedBy = self.IsOpenedBy
  function self:IsOpenedBy(doer)
    if self._tempOpenedBy then
      print('IsOpenedBy', self._tempOpenedBy)
      return true
    end
    return _IsOpenedBy(self, doer)
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
    if item:HasTag("ark_item") then
      local ark_item_pack = self:GetOpenedArkItemPack()
      if ark_item_pack then
        self._opened_ark_item_pack_overflow = ark_item_pack
      end
    end
    local res = {_GiveItem(self, item, slot, src_pos)}
    self._opened_ark_item_pack_overflow = nil
    if isArkItemPack(item) then
      if not self.opencontainers[item] then
        self.opencontainers[item] = true
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

-- 重新计算最大值
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end

local inventoryReplica = require "components/inventory_replica"

local _GetOverflowContainer = inventoryReplica.GetOverflowContainer
function inventoryReplica:GetOverflowContainer()
  local items = inventoryReplica.GetItems(self)
  for i, v in pairs(items) do
    if v:HasTag("ark_item_pack") then
      return v.replica.container
    end
  end
  return _GetOverflowContainer(self)
end

-- TODO: hook inventory_replica 的has函数, 使其支持ark_item
local _Has = inventoryReplica.Has
function inventoryReplica:Has(prefab, amount, checkallcontainers)
  print('inventory_replica:Has', prefab, amount, checkallcontainers)
  return _Has(self, prefab, amount, true)
end

local function IsBusy(inst) return inst._busy or inst._parent == nil end
AddPrefabPostInit("inventory_classified", function(self)
  local _MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container)
    if IsBusy(self) then
      return
    end
    local item = self:GetItemInSlot(slot)
    if item and item:HasTag('ark_item') then
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
    if IsBusy(self) then
      return
    end
    local item = self:GetItemInSlot(slot)
    if item and item:HasTag('ark_item') then
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
