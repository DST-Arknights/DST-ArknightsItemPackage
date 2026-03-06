local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local BorderWidget = require "widgets/border_widget"

local ICON_SIZE = 32
local HOVER_WIDTH = 360
local HOVER_PADDING = 20
local HOVER_TITLE_FONT_SIZE = 36
local HOVER_DESC_FONT_SIZE = 30
local HOVER_DESC_MAX_LINES = 20

-- Buff图标闪烁配置
local BLINK_THRESHOLD = 5  -- 剩余时间少于10秒时开始闪烁
local BLINK_CYCLE = 2  -- 闪烁周期（秒）

local ArkBuffDescText = Class(Widget, function(self, text, maxWidth)
  Widget._ctor(self, "ArkBuffDescText")
  self.h = 0
  self.maxWidth = maxWidth or 320
  local fontSize = HOVER_DESC_FONT_SIZE
  local maxLines = HOVER_DESC_MAX_LINES
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

  numLines = math.max(1, numLines or 1)
  self.h = numLines * lineHeight

  textWidget:SetRegionSize(self.maxWidth, self.h)
  textWidget:SetHAlign(ANCHOR_LEFT)
  textWidget:SetVAlign(ANCHOR_TOP)
  textWidget:SetPosition(0, -self.h / 2, 0)
end)

function ArkBuffDescText:GetSize()
  return self.maxWidth, self.h
end

local ArkBuffIcon = Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkBuffIcon")
  self.owner = owner
  self.size = {ICON_SIZE, ICON_SIZE}
  self.gap = 10
  self.iconImage = self:AddChild(Image())
  self.iconImage:SetSize(self.size)
  -- 倒计时遮罩
  self.maskImage = self:AddChild(Image("images/ui.xml", "white.tex"))
  self.maskImage:SetTint(0, 0, 0, 0.7)
  self.maskImage:SetSize(self.size)
  self.maskImage:SetVRegPoint(ANCHOR_TOP)
  self.maskImage:SetPosition(0, ICON_SIZE / 2, 0)
  
  -- 闪烁遮罩
  self.blinkMask = self:AddChild(Image("images/ui.xml", "white.tex"))
  self.blinkMask:SetSize(self.size)
  self.blinkMask:SetTint(0, 0, 0, 0.4)
  self.blinkMask:Hide()

  self.stacksBg = self:AddChild(Image("images/ark_item_ui.xml", "circle.tex"))
  self.stacksBg:SetTint(0, 0, 0, 0.8)
  self.stacksBg:SetSize(14, 14)
  self.stacksBg:SetPosition(-ICON_SIZE / 2, ICON_SIZE / 2, 0)
  self.stacksBg:Hide()  -- 初始隐藏，等待SetStacks判断
  -- 展示层数的文本
  self.stacksText = self.stacksBg:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT,12))

  self.hoverRoot = Widget("ark_buff_icon_hover_root")
  self.hoverBg = self.hoverRoot:AddChild(BorderWidget(HOVER_WIDTH, 0, {
    borderWidth = 2,
    borderColor = { 0.45, 0.45, 0.45, 0.9 },
    backgroundColor = { 0.23, 0.23, 0.23, 0.7 },
  }))
  self.hoverTitle = self.hoverRoot:AddChild(Text(FALLBACK_FONT_FULL, HOVER_TITLE_FONT_SIZE, ""))
  self.hoverDesc = nil
  self.currentHoverTitle = nil
  self.currentHoverDesc = nil
  self:SetHoverWidget(self.hoverRoot, {
    attach_to_parent = self,
    offset_x = 0,
    offset_y = 0,
    show_delay = 0.08,
    hide_delay = 0.12,
  })
  self:SetHoverContent(nil, nil)

  -- 闪烁状态
  self.isBlinking = false
  self.blinkTimer = 0
  self.currentStacks = 0  -- 记录当前stack，用于检测stack变化
end)

function ArkBuffIcon:SetHoverContent(title, desc)
  local nextTitle = title or ""
  local nextDesc = desc or ""
  if self.currentHoverTitle == nextTitle and self.currentHoverDesc == nextDesc then
    return
  end

  self.currentHoverTitle = nextTitle
  self.currentHoverDesc = nextDesc

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
  local leftOffset = -HOVER_WIDTH / 2 + HOVER_PADDING
  local topOffset = -HOVER_PADDING

  self.hoverTitle:SetString(nextTitle)
  local titleW, titleH = self.hoverTitle:GetRegionSize()
  self.hoverTitle:SetRegionSize(contentWidth, titleH)
  self.hoverTitle:SetHAlign(ANCHOR_LEFT)
  self.hoverTitle:SetVAlign(ANCHOR_TOP)
  self.hoverTitle:SetPosition(leftOffset + contentWidth / 2, topOffset - titleH / 2, 0)
  topOffset = topOffset - titleH

  if nextDesc ~= "" then
    topOffset = topOffset - 10
    self.hoverDesc = self.hoverRoot:AddChild(ArkBuffDescText(nextDesc, contentWidth))
    local _, descH = self.hoverDesc:GetSize()
    self.hoverDesc:SetPosition(0, topOffset, 0)
    topOffset = topOffset - descH
  end

  local height = -topOffset + HOVER_PADDING
  self.hoverBg:SetSize(HOVER_WIDTH, height)
  self.hoverBg:SetPosition(0, -height / 2, 0)
  self.hoverRoot:SetPosition(-ICON_SIZE / 2 + HOVER_WIDTH / 2, ICON_SIZE / 2 + height + 10, 0)
end

function ArkBuffIcon:SetTexture(atlas, tex)
  self.iconImage:SetTexture(atlas, tex)
  self.iconImage:SetSize(self.size)
end

function ArkBuffIcon:SetStacks(stacks)
  self.stacksText:SetString(tostring(stacks))
  
  -- Stack=1时隐藏，大于1才显示
  if stacks == 1 then
    self.stacksBg:Hide()
  else
    self.stacksBg:Show()
  end
  
  -- 检测stack变化：如果进入新的stack，停止闪烁
  if self.currentStacks ~= stacks and self.isBlinking then
    self:StopBlink()
  end
  self.currentStacks = stacks
end

function ArkBuffIcon:SetTotalTime(totalTime)
  self.totalTime = totalTime
end

function ArkBuffIcon:SetRemainingTime(remainingTime)
  self.remainingTime = remainingTime
  -- 每次设置剩余时间时，立刻刷新遮罩显示
  self:UpdateDisplayByRemainingTime()
  
  -- 判断是否需要闪烁
  if remainingTime > 0 and remainingTime <= BLINK_THRESHOLD then
    if not self.isBlinking then
      self:StartBlink()
    end
  else
    if self.isBlinking then
      self:StopBlink()
    end
  end
end

function ArkBuffIcon:UpdateDisplayByRemainingTime()
  -- 根据当前时间计算实际剩余百分比，用于遮罩显示
  if not self.totalTime then
    return
  end
  local scaleHeight = math.max(0, self.remainingTime / self.totalTime)
  self.maskImage:SetScale(1, 1 - scaleHeight)
end

function ArkBuffIcon:StartBlink()
  self.isBlinking = true
  self.blinkTimer = 0
end

function ArkBuffIcon:StopBlink()
  self.isBlinking = false
  self.blinkTimer = 0
  -- 恢复maskImage的默认透明度
  self.maskImage:SetTint(0, 0, 0, 0.7)
end

function ArkBuffIcon:UpdateBlink(dt)
  if not self.isBlinking then
    return
  end
  
  self.blinkTimer = self.blinkTimer + dt
  
  -- 使用正弦波实现平滑的呼吸效果
  local progress = (self.blinkTimer % BLINK_CYCLE) / BLINK_CYCLE
  local alpha = math.sin(progress * math.pi * 2) * 0.15 + 0.55  -- 在0.4-0.7之间波动
  self.maskImage:SetTint(0, 0, 0, alpha)
end

local ArkBuffIcons = Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkBuffIcons")
  self.owner = owner
  -- 按 atlas:tex 联合键分组
  -- buffGroups[key] = { icon = ArkBuffIcon, insts = { buffInst, ... } }
  self.buffGroups = {}
  -- 记录group的顺序，用于布局
  self.groupOrder = {}
  -- 客户端倒计时追踪
  -- buffClientTimers[buffInst] = { serverRemaining, clientStartTick }
  self.buffClientTimers = {}
  self.gap = 10
  self.owner:StartUpdatingComponent(self)
  if TheWorld.ismastersim then
    local buffs = owner:GetArkBuffIcons()
    if next(buffs) then
      for _, buff in ipairs(buffs) do
        self:AddBuff(buff)
      end
    end
  else
    SendModRPCToServer(GetModRPC("arkBuffIcon", "RequestBuffIcons"))
  end
end)

function ArkBuffIcons:AddBuff(buffInst)
  -- 使用 atlas:tex 联合键分组，相同纹理的buff共用一个icon
  local state = buffInst.replica.ark_buff_icon.state
  local groupKey = state.atlas .. ":" .. state.tex
  local group = self.buffGroups[groupKey]
  
  ArkLogger:Debug('ark_buff_icons AddBuff', buffInst, groupKey, group)
  if not group then
    -- 创建新分组
    local icon = ArkBuffIcon(self.owner)
    icon:SetTexture(state.atlas, state.tex)
    icon:SetTotalTime(state.totalTime)
    group = {
      icon = icon,
      insts = {},
    }
    self.buffGroups[groupKey] = group
    table.insert(self.groupOrder, groupKey)
    self:AddChild(icon)
  end

  -- 同一buff实例去重：重连/重载时可能从多个入口重复触发AddBuff
  for _, inst in ipairs(group.insts) do
    if inst == buffInst then
      self:_InitializeBuffTimer(buffInst)
      self:_UpdateGroupDisplay(groupKey)
      return
    end
  end
  
  -- 将buff实例加入分组
  table.insert(group.insts, buffInst)
  
  -- 初始化客户端倒计时
  self:_InitializeBuffTimer(buffInst)
  
  -- 更新布局
  self:_UpdateLayout()
  
  -- 更新分组显示
  self:_UpdateGroupDisplay(groupKey)
end

function ArkBuffIcons:RemoveBuff(buffInst)
  -- 清理客户端倒计时记录
  self.buffClientTimers[buffInst] = nil

  -- 遍历所有分组，移除该buff实例的所有重复引用
  local foundAny = false
  local touchedGroups = {}

  for groupKey, group in pairs(self.buffGroups) do
    local removedInGroup = false
    for i = #group.insts, 1, -1 do
      if group.insts[i] == buffInst then
        table.remove(group.insts, i)
        removedInGroup = true
        foundAny = true
      end
    end
    if removedInGroup then
      ArkLogger:Debug('ark_buff_icons RemoveBuff found', buffInst, groupKey)
      table.insert(touchedGroups, groupKey)
    end
  end

  if not foundAny then
    ArkLogger:Debug('ark_buff_icons RemoveBuff not found in any group', buffInst)
    return
  end

  -- 处理被修改过的分组：有实例则刷新，无实例则回收
  for _, groupKey in ipairs(touchedGroups) do
    local group = self.buffGroups[groupKey]
    if group then
      if #group.insts > 0 then
        ArkLogger:Debug('ark_buff_icons RemoveBuff group still has insts', group.insts)
        self:_UpdateGroupDisplay(groupKey)
      else
        ArkLogger:Debug('ark_buff_icons RemoveBuff group is empty', groupKey)
        group.icon:Kill()
        self.buffGroups[groupKey] = nil
        for i, key in ipairs(self.groupOrder) do
          if key == groupKey then
            table.remove(self.groupOrder, i)
            break
          end
        end
      end
    end
  end

  -- 更新布局
  self:_UpdateLayout()
end

function ArkBuffIcons:_GetDisplayRemainingTime(buffInst)
  -- 获取buff的客户端计算的剩余时间
  local timer = self.buffClientTimers[buffInst]
  if not timer then
    return 0
  end
  
  return timer.remainingTime
end

function ArkBuffIcons:_InitializeBuffTimer(buffInst)
  -- 初始化或重置客户端倒计时
  local state = buffInst.replica.ark_buff_icon.state
  self.buffClientTimers[buffInst] = {
    remainingTime = state.remainingTime,  -- 直接存储剩余时间，每帧递减
  }
end

function ArkBuffIcons:UpdateBuff(buffInst)
  -- 当服务端同步buff状态时，重新初始化客户端倒计时
  local groupKey = buffInst.replica.ark_buff_icon.state.atlas .. ":" .. buffInst.replica.ark_buff_icon.state.tex
  self:_InitializeBuffTimer(buffInst)
  self:_UpdateGroupDisplay(groupKey)
end

function ArkBuffIcons:_UpdateGroupDisplay(groupKey)
  -- 在分组内找到 remainingTime > 0 且最小的buff
  local group = self.buffGroups[groupKey]
  if not group or #group.insts == 0 then
    return
  end
  
  -- 过滤出还未过期的buff (remainingTime > 0)
  local validInsts = {}
  for _, inst in ipairs(group.insts) do
    if inst.replica and inst.replica.ark_buff_icon then
      local clientRemainingTime = self:_GetDisplayRemainingTime(inst)
      if clientRemainingTime > 0 then
        table.insert(validInsts, inst)
      end
    end
  end
  
  if #validInsts > 0 then
    -- 显示层数 = 还未过期的 buff 实例数量
    group.icon:SetStacks(#validInsts)
    -- 按剩余时间排序，找出最小的
    table.sort(validInsts, function(a, b)
      return self:_GetDisplayRemainingTime(a) < self:_GetDisplayRemainingTime(b)
    end)
    local displayBuff = validInsts[1]
    local displayState = displayBuff.replica.ark_buff_icon.state
    local displayRemainingTime = self:_GetDisplayRemainingTime(displayBuff)
    -- group.icon:SetTexture(displayState.atlas, displayState.tex)
    group.icon:SetTotalTime(displayState.totalTime)
    group.icon:SetRemainingTime(displayRemainingTime)
    group.icon:SetHoverContent(displayState.title, displayState.desc)
  else
    -- 没有有效的buff，隐藏icon（或保持显示最后一个已过期的buff）
    group.icon:SetRemainingTime(0)
    group.icon:SetHoverContent(nil, nil)
  end
end

function ArkBuffIcons:_UpdateLayout()
  -- 根据groupOrder中的顺序，横向排布所有group的icon
  local x = ICON_SIZE / 2
  for _, groupKey in ipairs(self.groupOrder) do
    local group = self.buffGroups[groupKey]
    if group then
      -- 设置icon的位置
      group.icon:SetPosition(x, 0, 0)
      -- 移动到下一个icon的x位置
      local iconSize = group.icon.size[1] or 32
      x = x + iconSize + self.gap
    end
  end
end

function ArkBuffIcons:OnUpdate(dt)
  -- 先更新所有buff的客户端倒计时（使用dt递减剩余时间）
  for buffInst, timer in pairs(self.buffClientTimers) do
    timer.remainingTime = math.max(0, timer.remainingTime - dt)
  end
  
  -- 更新所有图标的闪烁效果
  for groupKey, group in pairs(self.buffGroups) do
    if group.icon then
      group.icon:UpdateBlink(dt)
    end
  end
  
  -- 然后更新所有分组的显示
  for groupKey, group in pairs(self.buffGroups) do
    self:_UpdateGroupDisplay(groupKey)
  end
end
return ArkBuffIcons
