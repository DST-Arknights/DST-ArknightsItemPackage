local function on_enhance_type(self, new, old)
  if old then
    self.inst:RemoveTag(old .. "_enhanceable")
  end
  if new then
    self.inst:AddTag(new .. "_enhanceable")
  end
end

local function fill_stage(old, new)
  for k, v in pairs(new) do
    if old[k] == nil then
      old[k] = 0
    end
  end
end

local Enhanceable = Class(function(self, inst)
  self.inst = inst
  self.stage = {}
  self.on_enhance_fn = nil
  self.on_stage_apply_fn = nil
  self.can_enhance_fn = nil
  self.enhance_type = nil
end, nil, {
  enhance_type = on_enhance_type
})

function Enhanceable:SetOnEnhanceFn(fn)
  self.on_enhance_fn = fn
end

function Enhanceable:SetOnStageApplyFn(fn)
  self.on_stage_apply_fn = fn
end

function Enhanceable:SetCanEnhanceFn(fn)
  self.can_enhance_fn = fn
end

function Enhanceable:CanEnhance(obj, doer)
  if not self.can_enhance_fn then return true end
  local can, reason = self.can_enhance_fn(self.inst, obj, doer, self.stage)
  return can, reason
end

function Enhanceable:Enhance(obj, doer)
  local old = shallowcopy(self.stage)
  if self.on_enhance_fn then
    self.on_enhance_fn(self.inst, obj, doer, self.stage)
  end
  if self.on_stage_apply_fn then
    fill_stage(old, self.stage)
    self.on_stage_apply_fn(self.inst, self.stage, old)
  end
  if obj.components.stackable then
    obj.components.stackable:Get(1):Remove()
  else
    obj:Remove()
  end
end

function Enhanceable:OnSave()
  local data = {}
  if self.stage then
    data.stage = self.stage
  end
  return data
end

function Enhanceable:OnLoad(data)
  if data and data.stage then
    self.stage = data.stage
  end
  if self.on_stage_apply_fn then
    local old = {}
    self.on_stage_apply_fn(self.inst, self.stage, old)
  end
end

return Enhanceable
