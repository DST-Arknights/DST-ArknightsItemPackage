local Widget = require "widgets/widget"
local ImageButton = require "widgets/imagebutton"

AddClassPostConstruct("widgets/widget", function(self)
  local _WidgetKill = self.Kill
  function self:Kill(...)
    self:ClearHoverWidget()
    if _WidgetKill then
      return _WidgetKill(self, ...)
    end
  end

  function self:CancelScissorTo(run_complete_fn)
    if self.inst.components.uianim ~= nil then
      self.inst.components.uianim:CancelScissorTo(run_complete_fn)
    end
  end

  function self:ScissorTo(from, to, time, fn)
    if not self.inst.components.uianim then
      self.inst:AddComponent("uianim")
    end
    self.inst.components.uianim:ScissorTo(from, to, time, fn)
  end

  function self:ClearHoverWidget()
    if self._HoverWidgetShowTask then
      self._HoverWidgetShowTask:Cancel()
      self._HoverWidgetShowTask = nil
    end
    if self._HoverWidgetHideTask then
      self._HoverWidgetHideTask:Cancel()
      self._HoverWidgetHideTask = nil
    end

    if self.hoverwidget_focus_proxy then
      self.hoverwidget_focus_proxy:Kill()
      self.hoverwidget_focus_proxy = nil
    end

    if self._HoverWidgetOnGainFocus ~= nil and self.OnGainFocus == self._HoverWidgetOnGainFocus then
      self.OnGainFocus = self._PrevOnGainFocusForHoverWidget
    end
    if self._HoverWidgetOnLoseFocus ~= nil and self.OnLoseFocus == self._HoverWidgetOnLoseFocus then
      self.OnLoseFocus = self._PrevOnLoseFocusForHoverWidget
    end

    self._HoverWidgetOnGainFocus = nil
    self._HoverWidgetOnLoseFocus = nil
    self._PrevOnGainFocusForHoverWidget = nil
    self._PrevOnLoseFocusForHoverWidget = nil

    if self.hoverwidget then
      self.hoverwidget:Hide()
      self.hoverwidget = nil
    end

    self._HoverWidgetSource = nil
    self._HoverWidgetSourceIsFn = nil

    if self.hoverwidget_root then
      self.hoverwidget_root:Hide()
      self.hoverwidget_root:Kill()
      self.hoverwidget_root = nil
    end
  end

  function self:SetHoverWidget(widgetOrFn, params)
    if widgetOrFn == nil then
      self:ClearHoverWidget()
      return
    end

    params = params or {}

    self:ClearHoverWidget()

    if params.attach_to_parent ~= nil then
      self.hoverwidget_root = params.attach_to_parent:AddChild(Widget("hoverwidget_root"))
    else
      self.hoverwidget_root = Widget("hoverwidget_root")
      self.hoverwidget_root.global_widget = true
      self.hoverwidget_root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    end
    self.hoverwidget_root:Hide()

    self._HoverWidgetSource = widgetOrFn
    self._HoverWidgetSourceIsFn = type(widgetOrFn) == "function"

    if not self._HoverWidgetSourceIsFn then
      self.hoverwidget = self.hoverwidget_root:AddChild(widgetOrFn)
      self.hoverwidget:Hide()
    else
      self.hoverwidget = nil
    end

    local ensure_hover_widget = function(owner)
      if owner.hoverwidget ~= nil then
        return owner.hoverwidget
      end
      if owner.hoverwidget_root == nil then
        return nil
      end
      local hover_widget = FunctionOrValue(owner._HoverWidgetSource, owner)
      if hover_widget == nil then
        return nil
      end
      owner.hoverwidget = owner.hoverwidget_root:AddChild(hover_widget)
      owner.hoverwidget:Hide()
      return owner.hoverwidget
    end

    local show_hover_widget = function(owner)
      if owner.hoverwidget_root == nil then
        return
      end

      local hover_widget = ensure_hover_widget(owner)
      if hover_widget == nil then
        return
      end

      if params.attach_to_parent ~= nil then
        local world_pos = owner:GetWorldPosition() - params.attach_to_parent:GetWorldPosition()
        local parent_scale = params.attach_to_parent:GetScale()

        local x_pos = world_pos.x / parent_scale.x + (params.offset_x or 0)
        local y_pos = world_pos.y / parent_scale.y + (params.offset_y or 26)
        owner.hoverwidget_root:SetPosition(x_pos, y_pos)
        owner.hoverwidget_root:MoveToFront()
      else
        local world_pos = owner:GetWorldPosition()
        local x_pos = world_pos.x + (params.offset_x or 0)
        local y_pos = world_pos.y + (params.offset_y or 26)
        owner.hoverwidget_root:SetPosition(x_pos, y_pos)
      end

      hover_widget:Show()
      owner.hoverwidget_root:Show()
    end

    local hide_hover_widget = function(owner)
      if owner.hoverwidget then
        if owner._HoverWidgetSourceIsFn then
          owner.hoverwidget:Kill()
          owner.hoverwidget = nil
        else
          owner.hoverwidget:Hide()
        end
      end
      if owner.hoverwidget_root then
        owner.hoverwidget_root:Hide()
      end
    end

    local show_delay = params.show_delay
      or params.delay_show
      or 0
    local hide_delay = params.hide_delay
      or params.delay_hide
      or 0

    local request_show_hover_widget = function(owner)
      if owner._HoverWidgetHideTask then
        owner._HoverWidgetHideTask:Cancel()
        owner._HoverWidgetHideTask = nil
      end

      if owner._HoverWidgetShowTask then
        owner._HoverWidgetShowTask:Cancel()
        owner._HoverWidgetShowTask = nil
      end

      if show_delay > 0 then
        owner._HoverWidgetShowTask = owner.inst:DoTaskInTime(show_delay, function()
          owner._HoverWidgetShowTask = nil
          show_hover_widget(owner)
        end)
      else
        show_hover_widget(owner)
      end
    end

    local request_hide_hover_widget = function(owner)
      if owner._HoverWidgetShowTask then
        owner._HoverWidgetShowTask:Cancel()
        owner._HoverWidgetShowTask = nil
      end

      if owner._HoverWidgetHideTask then
        owner._HoverWidgetHideTask:Cancel()
        owner._HoverWidgetHideTask = nil
      end

      if hide_delay > 0 then
        owner._HoverWidgetHideTask = owner.inst:DoTaskInTime(hide_delay, function()
          owner._HoverWidgetHideTask = nil
          hide_hover_widget(owner)
        end)
      else
        hide_hover_widget(owner)
      end
    end

    self._PrevOnGainFocusForHoverWidget = self.OnGainFocus
    self._PrevOnLoseFocusForHoverWidget = self.OnLoseFocus

    local hover_parent = self.text or self
    if hover_parent.GetString ~= nil and hover_parent:GetString() ~= "" then
      self.hoverwidget_focus_proxy = hover_parent:AddChild(ImageButton("images/ui.xml", "blank.tex", "blank.tex", "blank.tex", nil, nil, {1,1}, {0,0}))
      self.hoverwidget_focus_proxy.image:ScaleToSize(hover_parent:GetRegionSize())

      self.hoverwidget_focus_proxy.OnGainFocus = function()
        request_show_hover_widget(self)
      end
      self.hoverwidget_focus_proxy.OnLoseFocus = function()
        request_hide_hover_widget(self)
      end
    else
      self._HoverWidgetOnGainFocus = function(owner)
        request_show_hover_widget(owner)
        if owner._PrevOnGainFocusForHoverWidget then
          owner._PrevOnGainFocusForHoverWidget(owner)
        end
      end
      self._HoverWidgetOnLoseFocus = function(owner)
        request_hide_hover_widget(owner)
        if owner._PrevOnLoseFocusForHoverWidget then
          owner._PrevOnLoseFocusForHoverWidget(owner)
        end
      end

      self.OnGainFocus = self._HoverWidgetOnGainFocus
      self.OnLoseFocus = self._HoverWidgetOnLoseFocus
    end
  end
end)

-- 已安装标志
local installed_symbol = Symbol("installed_symbol")

local function SetupForceStopWallUpdatingComponent(inst)
  if inst[installed_symbol] then
    return
  end
  inst[installed_symbol] = true
  local _StopWallUpdatingComponent = inst.StopWallUpdatingComponent
  function inst:StopWallUpdatingComponent(comp)
    if comp.scissor_t then
      return
    end
    _StopWallUpdatingComponent(self, comp)
  end
end

AddComponentPostInit("uianim", function(self, inst)
  function self:FinishCurrentScissor()
    if not self.inst or not self.inst:IsValid() then
      -- sometimes the ent becomes invalid during a "finished" callback, but this gets run anyways.
      return
    end

    local val = self.scissor_dest
    self.scissor_t = nil

    if self.inst.widget and self.inst.widget.SetScissor then
      self.inst.widget:SetScissor(val.x, val.y, val.w, val.h)
    end

    if self.scissor_whendone then
      local whendone = self.scissor_whendone
      self.scissor_whendone = nil
      whendone()
    end
  end

  function self:CancelScissorTo(run_complete_fn)
    self.scissor_t = nil
    if run_complete_fn ~= nil and self.scissor_whendone then
      self.scissor_whendone()
    end
    self.scissor_whendone = nil
  end

  function self:ScissorTo(start, dest, duration, whendone, curve)
    SetupForceStopWallUpdatingComponent(self.inst)
    if self.scissor_t then
      self:FinishCurrentScissor()
    end

    -- 参数验证和默认值设置
    if type(start) ~= "table" or type(dest) ~= "table" then
      print("ScissorTo: start and dest must be tables with x, y, w, h fields")
      return
    end

    -- 确保参数完整性，支持多种格式
    self.scissor_start = {
      x = start.x or start[1] or 0,
      y = start.y or start[2] or 0,
      w = start.w or start.width or start[3] or 0,
      h = start.h or start.height or start[4] or 0
    }

    self.scissor_dest = {
      x = dest.x or dest[1] or 0,
      y = dest.y or dest[2] or 0,
      w = dest.w or dest.width or dest[3] or 0,
      h = dest.h or dest.height or dest[4] or 0
    }

    self.scissor_duration = duration or 1
    self.scissor_t = 0
    self.scissor_curve = curve or function(t)
      return t
    end -- 默认线性曲线

    self.scissor_whendone = whendone
    self.inst:StartWallUpdatingComponent(self)

    -- 设置初始裁剪框
    if self.inst.widget and self.inst.widget.SetScissor then
      self.inst.widget:SetScissor(self.scissor_start.x, self.scissor_start.y, self.scissor_start.w, self.scissor_start.h)
    end
  end

  local _UIAnim_OnWallUpdate = self.OnWallUpdate
  function self:OnWallUpdate(dt)
    -- 调用原始的 OnWallUpdate
    _UIAnim_OnWallUpdate(self, dt)

    if not self.inst:IsValid() then
      self.inst:StopWallUpdatingComponent(self)
      return
    end
    if not self.update_while_paused and TheNet:IsServerPaused() then
      return
    end
    -- 添加 ScissorTo 动画逻辑
    if self.scissor_t then
      self.scissor_t = self.scissor_t + dt
      if self.scissor_t < self.scissor_duration then
        -- 计算动画进度 (0-1)
        local progress = self.scissor_t / self.scissor_duration
        -- 应用自定义曲线函数
        local curved_progress = self.scissor_curve(progress)

        -- 插值计算各个分量
        local x = self.scissor_start.x + (self.scissor_dest.x - self.scissor_start.x) * curved_progress
        local y = self.scissor_start.y + (self.scissor_dest.y - self.scissor_start.y) * curved_progress
        local w = self.scissor_start.w + (self.scissor_dest.w - self.scissor_start.w) * curved_progress
        local h = self.scissor_start.h + (self.scissor_dest.h - self.scissor_start.h) * curved_progress

        if self.inst.widget and self.inst.widget.SetScissor then
          self.inst.widget:SetScissor(x, y, w, h)
        end
      else
        self:FinishCurrentScissor()
      end
    end
    if not self.scale_t and not self.pos_t and not self.tint_t and not self.rot_t and not self.scissor_t then
      self.inst:StopWallUpdatingComponent(self)
    end
  end
end)
