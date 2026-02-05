AddClassPostConstruct("widgets/widget", function(self)
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
