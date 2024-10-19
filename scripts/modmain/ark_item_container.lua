local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local ark_items = require("ark_item_prefabs")
local common = require("ark_common")

local itemSlotRealIndexMap = {}
local function itemtestfn(container, item, slot)
  -- 只有指定物品能放在指定位置
  if not slot then
    return item:HasTag("ark_item")
  end
  return itemSlotRealIndexMap[item.prefab] == slot
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

local groups = {
  noGroup = {},
  base1 = {},
  base2 = {}
}
-- 重新分组
for i, v in ipairs(ark_items) do
  if v.group and groups[v.group] then
    table.insert(groups[v.group], v)
  else
    table.insert(groups.noGroup, v)
  end
end

local itemSlotReal = {}
-- 根据分组重新调整位置
for k, group in pairs(groups) do
  local numColumns = containers.params.ark_item_pack.widget.musha_scroll.num_columns
  local groupTotalNum = math.ceil(#group / numColumns) * numColumns
  for i = 1, groupTotalNum do
    if group[i] then
      table.insert(containers.params.ark_item_pack.widget.slotpos, Vector3(0, 0, 0))
      local assets = common.getPrefabAssetsCode(group[i].prefab)
      table.insert(containers.params.ark_item_pack.widget.slotbg, {
        atlas = assets.slotbgatlas,
        image = assets.slotbgimage
      })
      itemSlotRealIndexMap[group[i].prefab] = #containers.params.ark_item_pack.widget.slotpos
      table.insert(Assets, Asset("ATLAS", assets.slotbgatlas))
      table.insert(itemSlotReal, true)
    else
      table.insert(itemSlotReal, false)
    end
  end
end

-- 重新计算最大值
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end

local function GroupInv(inv)
  local result = {}
  local idx = 1
  for i, v in ipairs(itemSlotReal) do
    if v then
      table.insert(result, inv[idx])
      idx = idx + 1
    else
      -- 返回一个空widget
      table.insert(result, Widget("empty"))
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
    local groupInv = GroupInv(self.inv)
    self.options_scroll_list = self:AddChild(TEMPLATES.ScrollingGrid(groupInv, {
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
    slotInv:ScaleTo(1, 1.25, .125, function()
      slotInv:ScaleTo(1.25, 1, .125)
    end)
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
end)

AddComponentPostInit("inventory", function(self)
  local _GiveItem = self.GiveItem
  self.GiveItem = function(self, item, slot, src_pos)
    -- 只能保留一个背包, 另一个丢下
    if item.prefab == 'ark_item_pack' then
      for k, v in pairs(self.itemslots) do
        if v and v.prefab == 'ark_item_pack' then
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
  self.MoveItemFromAllOfSlot = function(self, slot, container, opener)
    if not isArkItemPack(container) then
      return _MoveItemFromAllOfSlot(self, slot, container, opener)
    end
    local item = self:GetItemInSlot(slot)
    if item ~= nil and container ~= nil then
      container = container.components.container
      if container ~= nil then

        container.currentuser = self.inst

        local targetslot = self.inst.components.constructionbuilderuidata ~= nil
                             and self.inst.components.constructionbuilderuidata:GetContainer() == container.inst
                             and self.inst.components.constructionbuilderuidata:GetSlotForIngredient(item.prefab) or nil

        if container:CanTakeItemInSlot(item, targetslot) then
          item = self:RemoveItemBySlot(slot)
          item.prevcontainer = nil
          item.prevslot = nil
          if not container:GiveItem(item, targetslot, nil, false) then
            self.ignoresound = true
            self:GiveItem(item, slot)
            self.ignoresound = false
          end
        end

        container.currentuser = nil
      end
    end
  end
  local _GetOverflowContainer = self.GetOverflowContainer
  self.GetOverflowContainer = function(self)
    if self._opened_ark_item_pack_overflow then
      return self._opened_ark_item_pack_overflow.components.container
    end
    return _GetOverflowContainer(self)
  end

  local _GetNextAvailableSlot = self.GetNextAvailableSlot
  self.GetNextAvailableSlot = function(self, item)
    -- 如果物品没有ark_item标签, 直接调用原函数
    if self._opened_ark_item_pack_overflow then
      for k, v in pairs(self._opened_ark_item_pack_overflow.components.container.slots) do
        if v.prefab == item.prefab and v.skinname == item.skinname and v.components.stackable ~= nil
          and not v.components.stackable:IsFull() then
          return k, self._opened_ark_item_pack_overflow.components.container
        end
      end
      -- return nil, self._opened_ark_item_pack_overflow.components.container
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
  local _CanAcceptCount = self.CanAcceptCount
  self.CanAcceptCount = function(self, item, count)
    return _CanAcceptCount(self, item, count)
  end
end)
