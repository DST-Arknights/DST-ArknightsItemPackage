local containers = require "containers"
local TrueScrollArea = require "widgets/truescrollarea"
local Text = require "widgets/text"
local Widget = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
local common = require("ark_common")

RegisterInventoryItemAtlas('images/ark_backpack.xml', 'ark_backpack.tex')

local itemSlotRealIndexMap = {}

local function canPutItemInArkItemPack(item)
  return item and item:HasTag("ark_backpack_item")
end

local function itemtestfn(container, item, slot)
  -- 只有指定物品能放在指定位置
  if not slot then
    return canPutItemInArkItemPack(item)
  end
  local res = itemSlotRealIndexMap[item.prefab] == slot
  return res
end
local function priorityfn(container, item)
  return canPutItemInArkItemPack(item)
end

containers.params.ark_backpack = {
  widget = {
    slotpos = {},
    slotbg = {},
    bgatlas = nil,
    bgimage = nil,
    scroll = {
      num_columns = 6,
      num_visible_rows = 8,
      widget_width = 80,
      widget_height = 86,
      pos = nil
    },
    pos = Vector3(340, -60, 0),
    animbuild_upgraded = 'ark_backpack_bg',
    animbuild = 'ark_backpack_bg',
    animbank_upgraded = 'ark_backpack_bg',
    animbank = 'ark_backpack_bg',
    animloop = true
  },
  usespecificslotsforitems = true,
  itemtestfn = itemtestfn,
  priorityfn = priorityfn,
  issidewidget = false,
  type = "ark_backpack",
  openlimit = 2
}

local allItemsInPack = {}
for _, item in ipairs(require('ark_item_declare')) do
  if not item.disablePutInPack then
    table.insert(allItemsInPack, item)
  end
end

for i, item in ipairs(allItemsInPack) do
  table.insert(containers.params.ark_backpack.widget.slotpos, Vector3(0, 0, 0))
  local assets = common.getPrefabAssetsCode(item.prefab)
  table.insert(containers.params.ark_backpack.widget.slotbg, {
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

local function isArkItemPack(inst)
  return inst and inst.replica.container and inst.replica.container.type == "ark_backpack"
end
local containerScrollWidgetSymbol = Symbol("container_scroll_widget")
local function OnContainerScrollItemGet(self, container, data)
  if self[containerScrollWidgetSymbol] then
    self[containerScrollWidgetSymbol]:RefreshView()
  end
end
-- 可滑动箱子
AddClassPostConstruct("widgets/containerwidget", function(self)
  local _Open = self.Open
  self.Open = function(self, container, doer)
    _Open(self, container, doer)
    local widget = container.replica.container:GetWidget()
    local scrollConfig = widget.scroll
    if not scrollConfig then
      return
    end
    local num_visible_rows = scrollConfig.num_visible_rows or 5
    local num_columns = scrollConfig.num_columns or 5
    local widget_width = scrollConfig.widget_width or 75
    local widget_height = scrollConfig.widget_height or 75

    -- 理论上不需要这段
    -- for k, v in pairs(self.inv) do
    --   v:SetPosition(Vector3(0, 0, 0))
    --   v:Hide()
    -- end

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
    local scrollWidget = self:AddChild(TEMPLATES.ScrollingGrid(items, {
      scroll_context = {
        items = items,
        widget = self,
        container = container
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
    local old_OnFocusMove = scrollWidget.OnFocusMove
    function scrollWidget:OnFocusMove(dir, down)
      if dir == MOVE_UP or dir == MOVE_DOWN then
        return false
      end
      return old_OnFocusMove(self, dir, down)
    end

    -- 禁止滚动游戏屏幕
    local old_OnControl = scrollWidget.OnControl
    function scrollWidget:OnControl(control, down)
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

    if scrollConfig.pos then
      scrollWidget:SetPosition(scrollConfig.pos)
    end
    self[containerScrollWidgetSymbol] = scrollWidget
    self.inst:ListenForEvent("itemget", OnContainerScrollItemGet, container)
  end

  local _Close = self.Close
  self.Close = function(self, doer)
    if self[containerScrollWidgetSymbol] then
      self[containerScrollWidgetSymbol]:Kill()
      self[containerScrollWidgetSymbol] = nil
      self.inst:RemoveEventCallback("itemget", OnContainerScrollItemGet, self.container)
    end
    return _Close(self)
  end
end)

-- overflow ark背包优先标志
local overflowArkPackFirstSymbol = Symbol("overflow_ark_pack_first")
-- 只允获得一个包
AddComponentPostInit("inventory", function(self)
  self.silent_open_containers = {}
  -- 利用overflow调整ark背包优先级. 总是优先, 除非被禁用
  local _GetOverflowContainer = self.GetOverflowContainer
  function self:GetOverflowContainer()
    if self[overflowArkPackFirstSymbol] then
      local arkItemPack, index = self:findArkItemPack()
      if arkItemPack then
        return arkItemPack.components.container
      end
    end
    return _GetOverflowContainer(self)
  end

  local _GetNextAvailableSlot = self.GetNextAvailableSlot
  function self:GetNextAvailableSlot(item)
    -- 检查是否命中了ark包. 若命中了直接返回, 未命中允许普通容器包重试
    local slot, container = _GetNextAvailableSlot(self, item)
    if container and isArkItemPack(container.inst) then
      return slot, container
    end
    -- 关掉标志, 允许普通容器包重试
    local old = self[overflowArkPackFirstSymbol]
    self[overflowArkPackFirstSymbol] = nil
    local res = {_GetNextAvailableSlot(self, item)}
    self[overflowArkPackFirstSymbol] = old
    return unpack(res)
  end

  local _GiveItem = self.GiveItem
  self.GiveItem = function(self, item, slot, src_pos)
    -- 只能保留一个背包, 另一个丢下
    if isArkItemPack(item) then
      local arkItemPack, index = self:findArkItemPack()
      if arkItemPack then
        self:DropItem(arkItemPack)
        arkItemPack.components.container:Close()
      end
    end
    local old = self[overflowArkPackFirstSymbol]
    if canPutItemInArkItemPack(item) and self[overflowArkPackFirstSymbol] == nil then
      self[overflowArkPackFirstSymbol] = true
    end
    local res = {_GiveItem(self, item, slot, src_pos)}
    self[overflowArkPackFirstSymbol] = old
    if isArkItemPack(item) then
      item.components.container:OpenSilently(self.inst)
    end
    return unpack(res)
  end

  local _RemoveItem = self.RemoveItem
  self.RemoveItem = function(self, item, wholestack, checkallcontainers, keepoverstacked)
    local overflow = self:GetOverflowContainer()
    if checkallcontainers then
      local silent_open_containers = self.silent_open_containers
      for container_inst, _ in pairs(silent_open_containers) do
        local container = container_inst.components.container or container_inst.components.inventory
        if container and container ~= overflow and not container.excludefromcrafting and not container.readonlycontainer then
          local container_item = container:RemoveItem(item, wholestack, nil, keepoverstacked)
          if container_item then
            return container_item
          end
        end
      end
    end

    local res = {_RemoveItem(self, item, wholestack, checkallcontainers, keepoverstacked)}
    if isArkItemPack(item) then
      item.components.container:CloseSilently(self.inst)
    end
    return unpack(res)
  end

  local _Has = self.Has
  function self:Has(item, amount, checkallcontainers)
    local enough, count = _Has(self, item, amount, checkallcontainers)
    if checkallcontainers then
      local overflow = self:GetOverflowContainer()
      for container_inst, _ in pairs(self.silent_open_containers) do
        -- 正常容器与静默容器需要去重, 防止统计二次
        if self.opencontainers[container_inst] == nil then
          local container = container_inst.components.container or container_inst.components.inventory
          if container and container ~= overflow and not container.excludefromcrafting
            and not container.readonlycontainer then
            local container_enough, container_found = container:Has(item, amount, checkallcontainers)
            count = count + container_found
          end
        end
      end
    end
    return count >= amount, count
  end

  -- 从静默容器中补齐合成材料
  local _GetCraftingIngredient = self.GetCraftingIngredient
  function self:GetCraftingIngredient(item, amount)
    -- 先用原逻辑从普通打开容器、背包、overflow、手持物里找
    local crafting_items = _GetCraftingIngredient(self, item, amount)

    local total_num_found = 0
    for _, v in pairs(crafting_items) do
      total_num_found = total_num_found + v
    end
    if total_num_found >= amount then
      return crafting_items
    end

    local overflow = self:GetOverflowContainer()
    -- 再从静默打开的容器里找剩余数量
    for container_inst, _ in pairs(self.silent_open_containers) do
      -- 避免与普通打开容器重复统计
      if self.opencontainers[container_inst] == nil then
        local container = container_inst.components.container or container_inst.components.inventory
        if container and container ~= overflow and not container.excludefromcrafting and not container.readonlycontainer then
          local remain = amount - total_num_found
          if remain <= 0 then
            break
          end
          local from_container = container:GetCraftingIngredient(item, remain, true)
          for k, v in pairs(from_container) do
            crafting_items[k] = (crafting_items[k] or 0) + v
            total_num_found = total_num_found + v
            if total_num_found >= amount then
              return crafting_items
            end
          end
        end
      end
    end

    return crafting_items
  end

  self.findArkItemPack = function(self)
    for k, v in pairs(self.itemslots) do
      if isArkItemPack(v) then
        return v, k
      end
    end
  end

end)

AddClassPostConstruct("components/inventory_replica", function(self)
  self.silent_open_containers = {}
  function self:GetSilentOpenContainers()
    if self.inst.components.inventory ~= nil then
      return self.inst.components.inventory.silent_open_containers
    else
      return self.silent_open_containers
    end
  end
end)

AddPrefabPostInit("inventory_classified", function(inst)
  local _Has = inst.Has
  function inst:Has(item, amount, checkallcontainers)
    local enough, count = _Has(self, item, amount, checkallcontainers)
    if checkallcontainers then
      local overflow = self:GetOverflowContainer()
      local inventory_replica = inst and inst._parent and inst._parent.replica.inventory
      local silent_containers = inventory_replica and inventory_replica:GetSilentOpenContainers()
      local open_containers = inventory_replica and inventory_replica:GetOpenContainers()
      if silent_containers then
        for container_inst in pairs(silent_containers) do
          if open_containers[container_inst] == nil then
            local container = container_inst.replica.container or container_inst.replica.inventory
            if container and container ~= overflow and not container.excludefromcrafting
              and (container.IsReadOnlyContainer == nil or not container:IsReadOnlyContainer()) then
              local container_enough, container_count = container:Has(item, amount, checkallcontainers)
              count = count + container_count
            end
          end
        end
      end
    end
    return count >= amount, count
  end
end)

AddComponentPostInit("container", function(self)
  self.silent_open_list = {}
  self.silent_open_count = 0
  local _MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
  function self:MoveItemFromAllOfSlot(slot, container, opener)
    -- 移出的时候不能提高自己优先级
    opener.components.inventory[overflowArkPackFirstSymbol] = false
    _MoveItemFromAllOfSlot(self, slot, container, opener)
    opener.components.inventory[overflowArkPackFirstSymbol] = nil
  end

  local _MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
  function self:MoveItemFromHalfOfSlot(slot, container, opener)
    opener.components.inventory[overflowArkPackFirstSymbol] = false
    _MoveItemFromHalfOfSlot(self, slot, container, opener)
    opener.components.inventory[overflowArkPackFirstSymbol] = nil
  end
  -- 静默打开：不改 normal 状态，调用原始 _Open 以避免被重写的逻辑干扰
  function self:OpenSilently(doer)
    if doer == nil then
      return
    end
    if self.silent_open_list[doer] then
      return
    end
    -- 静默的
    if doer.components.inventory then
      doer.components.inventory.silent_open_containers[self.inst] = true
    end
    self.silent_open_list[doer] = true
    self.silent_open_count = self.silent_open_count + 1
    self.inst.replica.container:AddSilentOpener(doer)
    if doer.components.inventory then
      doer.components.inventory.silent_open_containers[self.inst] = true
    end
  end

  -- 静默关闭：仅在没有普通打开请求时才真正关闭
  function self:CloseSilently(doer)
    self:ForEachItem(function(item, doer)
      if item.components.container then
        item.components.container:CloseSilently(doer)
      end
    end, doer)
    if doer == nil then
      for doer, _ in pairs(self.silent_open_list) do
        self:CloseSilently(doer)
      end
      return
    end
    if self.silent_open_list[doer] == nil then
      return
    end
    self.silent_open_list[doer] = nil
    self.silent_open_count = self.silent_open_count - 1
    self.inst.replica.container:RemoveSilentOpener(doer)
    if doer.components.inventory then
      doer.components.inventory.silent_open_containers[self.inst] = nil
    end
  end
end)

local function OnRefreshCrafting(inst)
  ArkLogger:Trace('container', 'OnRefreshCrafting', inst)
  if ThePlayer ~= nil and ThePlayer.HUD ~= nil then
    ThePlayer:PushEvent("refreshcrafting")
  end
end

local function DoBlink(slot)
  if slot.blink_task then
    return;
  end
  slot.blink_task = slot.inst:DoTaskInTime(0, function()
    slot.blink_task = nil
    slot:ScaleTo(1, 1.25, .125, function()
      slot:ScaleTo(1.25, 1, .125)
    end)
    -- TheFocalPoint.SoundEmitter:PlaySound(PICKUPSOUNDS["DEFAULT_FALLBACK"])
  end)
end

local function BlinkArkPackSlot(inst, data)
  -- 非ark包, 不闪
  if not isArkItemPack(inst) then
    return
  end
  -- 获取自己的owner
  local owner = nil
  local opened = false
  -- 主机从组件里取
  if inst.components.inventoryitemm then
    owner = inst.components.inventoryitem:GetOwner()
    opened = owner and inst.components.container.openlist[owner] or false
  else
    owner = ThePlayer
    opened = inst.replica.container and inst.replica.container.opener and true or false
  end
  if not opened and owner and owner.HUD and owner.HUD.controls and owner.HUD.controls.inv then
    -- 找到索引
    local items = owner.replica.inventory and owner.replica.inventory:GetItems() or {}
    for i, v in ipairs(items) do
      if v == inst then
        local slot = owner.HUD.controls.inv.inv[i]
        DoBlink(slot)
      end
    end
  end
  
end

AddClassPostConstruct("components/container_replica", function(self)
  self.silent_openers = {}
  if not TheWorld.ismastersim then
    if self.silent_opener == nil and self.inst.container_silent_opener ~= nil then
      self.silent_opener = self.inst.container_silent_opener
      self.inst.container_silent_opener.OnRemoveEntity = nil
      self.inst.container_silent_opener = nil
      self:AttachSilentOpener(self.inst.container_silent_opener)
    end
  end
  if not TheNet:IsDedicated() then
    self.inst:ListenForEvent("itemget", BlinkArkPackSlot)
  end
  -- 调整打开者
  function self:AdjustOpener(opener)
    -- 取静默打开与非静默打开的并集, 获取count
    local merged = MergeMaps(self.inst.components.container.openlist, self.inst.components.container.silent_open_list)
    local opencount = GetTableSize(merged)
    local target = nil
    if opencount == 0 then
      target = self.inst
    elseif opencount == 1 then
      target = opener or table.getkeys(merged)[1]
    end
    self.classified.Network:SetClassifiedTarget(target)
    if opencount >= 1 then
      if self.inst.components.container ~= nil then
        for _, v in pairs(self.inst.components.container.slots) do
          v.replica.inventoryitem:SetOwner(self.inst)
        end
      end
    end
  end
  function self:AddSilentOpener(opener)
    self:AdjustOpener(opener)
    self.silent_openers[opener] = self.inst:SpawnChild("container_silent_opener")
    self.silent_openers[opener].Network:SetClassifiedTarget(opener)
  end
  function self:RemoveSilentOpener(opener)
    if self.silent_openers[opener] ~= nil then
      self.silent_openers[opener]:Remove()
      self.silent_openers[opener] = nil
    end
    self:AdjustOpener(nil)
  end

  function self:AttachSilentOpener(opener)
    self.silent_opener = opener
    self.ondetachsilentopener = function()
      self:DetachSilentOpener()
    end
    self.inst:ListenForEvent("onremove", self.ondetachsilentopener, opener)
    self.inst:ListenForEvent("itemget", OnRefreshCrafting)
    self.inst:ListenForEvent("itemlose", OnRefreshCrafting)
    if ThePlayer ~= nil and ThePlayer.replica.inventory ~= nil then
      ThePlayer.replica.inventory.silent_open_containers[self.inst] = true
    end
  end

  function self:DetachSilentOpener()
    self.inst:RemoveEventCallback("onremove", self.ondetachsilentopener, self.silent_opener)
    self.inst:RemoveEventCallback("itemget", OnRefreshCrafting)
    self.inst:RemoveEventCallback("itemlose", OnRefreshCrafting)
    self.silent_opener = nil
    self.ondetachsilentopener = nil
    if ThePlayer ~= nil and ThePlayer.replica.inventory ~= nil then
      ThePlayer.replica.inventory.silent_open_containers[self.inst] = nil
    end
    OnRefreshCrafting(self.inst)
  end

  local _AddOpener = self.AddOpener
  function self:AddOpener(opener)
    _AddOpener(self, opener)
    self:AdjustOpener(opener)
  end

  local _RemoveOpener = self.RemoveOpener
  function self:RemoveOpener(opener)
    _RemoveOpener(self, opener)
    self:AdjustOpener(nil)
  end

  local _Has = self.Has
  function self:Has(prefab, amount, iscrafting)
    -- 原本的has没检查 silent_opener
    local enough, count = _Has(self, prefab, amount, iscrafting)
    if not enough then
      if self.inst.components.container ~= nil then
        return self.inst.components.container:Has(prefab, amount, iscrafting)
      elseif self.classified ~= nil and (self.opener ~= nil or self.silent_opener ~= nil) then
        return self.classified:Has(prefab, amount, iscrafting)
      else
          return amount <= 0, 0
      end
    end
    return enough, count
  end
end)

AddClassPostConstruct("components/inventoryitem_replica", function(self)
	-- 记录原始 SetOwner, 确保其它模组对 SetOwner 的 hook 仍然生效
	local _SetOwner = self.SetOwner
	function self:SetOwner(owner)
		-- 先调用原始实现(以及可能已被其它模组包裹过的一层实现)
		_SetOwner(self, owner)

		-- 只有当 "owner" 是一个拥有 container 组件的实体时, 才需要按容器逻辑处理
		if owner ~= nil and owner.components ~= nil and owner.components.container ~= nil then
			local container = owner.components.container
			-- 将普通打开(openlist)与静默打开(silent_open_list)合并来统计总打开者数量
			local merged = MergeMaps(container.openlist, container.silent_open_list)
			local opencount = GetTableSize(merged)

			if opencount > 1 then
				-- 多个打开者: 按源码逻辑, 强制离开 limbo, 并清空 item 的网络目标
				self.inst:ForceOutOfLimbo(true)
				if self.inst.Network ~= nil then
					self.inst.Network:SetClassifiedTarget(nil)
				end
				if self.classified ~= nil then
					self.classified.Network:SetClassifiedTarget(nil)
				end
			else
				-- 0 或 1 个打开者: 与源码一致, 只是把 openlist 换成合并后的 merged
				local target = (opencount == 0 and owner)
					or (opencount == 1 and table.getkeys(merged)[1])
					or nil
				self.inst:ForceOutOfLimbo(false)
				if self.inst.Network ~= nil then
					self.inst.Network:SetClassifiedTarget(target)
				end
				if self.classified ~= nil then
					self.classified.Network:SetClassifiedTarget(target or self.inst)
				end
			end
		end
	end
end)
AddClassPostConstruct("widgets/truescrolllist", function(self)
  local _BuildScrollBar = self.BuildScrollBar
  function self:BuildScrollBar()
    _BuildScrollBar(self)
    -- TODO:检查完特殊容器后才允许隐藏, 不能全部隐藏
    -- self.up_button:Hide()
    -- self.down_button:Hide()
    -- self.scroll_bar_line:Hide()
    -- self.position_marker:Hide()
  end
end)
-- 重新计算最大值
for k, v in pairs(containers.params) do
  containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
