local Widget = require "widgets/widget"
local Image = require "widgets/image"

local abs = math.abs
local rawget = rawget
local Lerp = rawget(_G, "Lerp")

local DEFAULT_POSE = {
  x = 0,
  y = 0,
  sx = 1,
  sy = 1,
  rot = 0,
  a = 1,
}

local function Linear(t)
  return t
end

local function _Lerp(a, b, t)
  if Lerp then
    return Lerp(a, b, t)
  end
  return a + (b - a) * t
end

local function _ResolveEaseFn(ease)
  if type(ease) == "function" then
    return ease
  end
  return Linear
end

local function _ResolvePropEase(frame, prop)
  local ease = frame.ease
  if type(ease) == "table" then
    return _ResolveEaseFn(ease[prop])
  end

  if type(ease) == "function" then
    return ease
  end

  local by_name = frame["ease_" .. prop]
  if type(by_name) == "function" then
    return by_name
  end

  return Linear
end

local function _NormalizeKeyframes(keyframes, defaults)
  local count = keyframes and #keyframes or 0
  if count <= 0 then
    return {
      {
        t = 0,
        x = defaults.x,
        y = defaults.y,
        sx = defaults.sx,
        sy = defaults.sy,
        rot = defaults.rot,
        a = defaults.a,
        ease_x_fn = Linear,
        ease_y_fn = Linear,
        ease_sx_fn = Linear,
        ease_sy_fn = Linear,
        ease_rot_fn = Linear,
        ease_a_fn = Linear,
      }
    }
  end

  local sorted = {}
  for i = 1, count do
    sorted[i] = keyframes[i]
  end
  table.sort(sorted, function(a, b)
    return (a.t or 0) < (b.t or 0)
  end)

  local normalized = {}
  local prev = nil
  for i = 1, #sorted do
    local src = sorted[i]
    local frame = {}

    frame.t = src.t
    if frame.t == nil then
      frame.t = prev and prev.t or 0
    end

    frame.x = src.x
    if frame.x == nil then
      frame.x = prev and prev.x or defaults.x
    end

    frame.y = src.y
    if frame.y == nil then
      frame.y = prev and prev.y or defaults.y
    end

    frame.sx = src.sx
    if frame.sx == nil then
      frame.sx = prev and prev.sx or defaults.sx
    end

    frame.sy = src.sy
    if frame.sy == nil then
      frame.sy = prev and prev.sy or defaults.sy
    end

    frame.rot = src.rot
    if frame.rot == nil then
      frame.rot = prev and prev.rot or defaults.rot
    end

    frame.a = src.a
    if frame.a == nil then
      frame.a = prev and prev.a or defaults.a
    end

    frame.ease_x_fn = _ResolvePropEase(src, "x")
    frame.ease_y_fn = _ResolvePropEase(src, "y")
    frame.ease_sx_fn = _ResolvePropEase(src, "sx")
    frame.ease_sy_fn = _ResolvePropEase(src, "sy")
    frame.ease_rot_fn = _ResolvePropEase(src, "rot")
    frame.ease_a_fn = _ResolvePropEase(src, "a")

    normalized[#normalized + 1] = frame
    prev = frame
  end

  return normalized
end

local function _SampleKeyframes(frames, t)
  local count = #frames
  if count == 1 then
    return frames[1]
  end

  if t <= frames[1].t then
    return frames[1]
  end

  for i = 1, count - 1 do
    local k1 = frames[i]
    local k2 = frames[i + 1]

    if t <= k2.t then
      local span = k2.t - k1.t
      if span <= 0 then
        return k2
      end

      local alpha = (t - k1.t) / span
      if alpha < 0 then
        alpha = 0
      elseif alpha > 1 then
        alpha = 1
      end

      return {
        x = _Lerp(k1.x, k2.x, k1.ease_x_fn(alpha)),
        y = _Lerp(k1.y, k2.y, k1.ease_y_fn(alpha)),
        sx = _Lerp(k1.sx, k2.sx, k1.ease_sx_fn(alpha)),
        sy = _Lerp(k1.sy, k2.sy, k1.ease_sy_fn(alpha)),
        rot = _Lerp(k1.rot, k2.rot, k1.ease_rot_fn(alpha)),
        a = _Lerp(k1.a, k2.a, k1.ease_a_fn(alpha)),
      }
    end
  end

  return frames[count]
end

local UIImageAnim = Class(Widget, function(self, config_or_path)
  Widget._ctor(self, "UIImageAnim")

  if type(config_or_path) == "string" then
    self._config = require(config_or_path)
  else
    self._config = config_or_path or {}
  end

  self._compiled_anims = {}
  self._nodes = {}
  self._anim_name = nil
  self._anim = nil
  self._anim_t = 0
  self._accum_dt = 0
  self._frame_step = self._config.frame_step or (1 / 30)
  self._queue = {}
  self._paused = false

  self:_CompileAnims()
  self:_BuildNodes()
end)

function UIImageAnim:_CompileAnims()
  local defaults = DEFAULT_POSE
  local texlib = self._config.texlib or {}
  local anims = self._config.anims or {}

  for name, anim_def in pairs(anims) do
    local compiled = {
      duration = 0,
      elements = {},
    }

    local elements = anim_def.elements or {}
    for i = 1, #elements do
      local element = elements[i]
      local tex_name = texlib[element.tex] or element.tex
      if tex_name ~= nil then
        local stable_key = tostring(element.tex or tex_name)
        local element_id = element.id or (stable_key .. "#" .. tostring(i))
        local base_defaults = {
          x = element.x,
          y = element.y,
          sx = element.sx,
          sy = element.sy,
          rot = element.rot,
          a = element.a,
        }

        if base_defaults.x == nil then base_defaults.x = defaults.x end
        if base_defaults.y == nil then base_defaults.y = defaults.y end
        if base_defaults.sx == nil then base_defaults.sx = defaults.sx end
        if base_defaults.sy == nil then base_defaults.sy = defaults.sy end
        if base_defaults.rot == nil then base_defaults.rot = defaults.rot end
        if base_defaults.a == nil then base_defaults.a = defaults.a end

        local normalized_keyframes = _NormalizeKeyframes(element.keyframes, base_defaults)
        local keyframe_end_t = normalized_keyframes[#normalized_keyframes].t or 0
        if keyframe_end_t > compiled.duration then
          compiled.duration = keyframe_end_t
        end

        compiled.elements[#compiled.elements + 1] = {
          id = element_id,
          tex = tex_name,
          keyframes = normalized_keyframes,
        }
      end
    end

    if compiled.duration <= 0 then
      compiled.duration = 0.001
    end

    self._compiled_anims[name] = compiled
  end
end

function UIImageAnim:_BuildNodes()
  local seen = {}

  for _, anim in pairs(self._compiled_anims) do
    for i = 1, #anim.elements do
      local element = anim.elements[i]
      if not seen[element.id] then
        local image = self:AddChild(Image(self._config.atlas, element.tex))
        image:SetPosition(0, 0, 0)
        image:SetScale(1, 1, 1)
        image:SetRotation(0)
        image:SetTint(1, 1, 1, 0)

        self._nodes[element.id] = {
          image = image,
          px = 0,
          py = 0,
          psx = 1,
          psy = 1,
          prot = 0,
          pa = 0,
        }
        seen[element.id] = true
      end
    end
  end
end

function UIImageAnim:GetAnimationDuration(name)
  local anim = self._compiled_anims[name]
  return anim and anim.duration or 0
end

function UIImageAnim:GetCurrentAnimationName()
  return self._anim_name
end

function UIImageAnim:PlayAnimation(name, loop)
  local anim = self._compiled_anims[name]
  if anim == nil then
    return false
  end

  self._queue = {}
  self._anim_name = name
  self._anim = anim
  self._anim_t = 0
  self._accum_dt = 0
  self._paused = false
  self._loop = loop == true
  self:StartUpdating()
  self:_Advance(0)
  return true
end

function UIImageAnim:PushAnimation(name)
  if self._compiled_anims[name] == nil then
    return false
  end

  self._queue[#self._queue + 1] = {
    name = name,
    loop = false,
  }
  return true
end

function UIImageAnim:Pause()
  self._paused = true
end

function UIImageAnim:Resume()
  self._paused = false
end

function UIImageAnim:_OnAnimFinished()
  if #self._queue > 0 then
    local next_item = table.remove(self._queue, 1)
    self:PlayAnimation(next_item.name, next_item.loop)
  else
    self._anim_name = nil
    self._anim = nil
    self._anim_t = 0
    self._accum_dt = 0
    self:StopUpdating()
  end
end

function UIImageAnim:_ApplyPose(id, pose)
  local node = self._nodes[id]
  if node == nil then
    return
  end

  local image = node.image
  local x = pose.x
  local y = pose.y
  local sx = pose.sx
  local sy = pose.sy
  local rot = pose.rot
  local a = pose.a

  if a < 0 then
    a = 0
  elseif a > 1 then
    a = 1
  end

  if abs(node.px - x) > 0.05 or abs(node.py - y) > 0.05 then
    image:SetPosition(x, y, 0)
    node.px = x
    node.py = y
  end

  if abs(node.psx - sx) > 0.001 or abs(node.psy - sy) > 0.001 then
    image:SetScale(sx, sy, 1)
    node.psx = sx
    node.psy = sy
  end

  if abs(node.prot - rot) > 0.05 then
    image:SetRotation(rot)
    node.prot = rot
  end

  if abs(node.pa - a) > 0.003 then
    image:SetTint(1, 1, 1, a)
    node.pa = a
  end
end

function UIImageAnim:_HideUnusedNodes(active_ids)
  for id, node in pairs(self._nodes) do
    if not active_ids[id] and node.pa > 0.003 then
      node.image:SetTint(1, 1, 1, 0)
      node.pa = 0
    end
  end
end

function UIImageAnim:_Advance(dt)
  local anim = self._anim
  if anim == nil then
    return
  end

  self._anim_t = self._anim_t + dt
  local duration = anim.duration
  local t = self._anim_t

  if duration > 0 then
    if self._loop then
      t = t % duration
      self._anim_t = t
    else
      if t > duration then
        t = duration
      end
    end
  else
    t = 0
  end

  local active_ids = {}
  for i = 1, #anim.elements do
    local element = anim.elements[i]
    local pose = _SampleKeyframes(element.keyframes, t)
    self:_ApplyPose(element.id, pose)
    active_ids[element.id] = true
  end
  self:_HideUnusedNodes(active_ids)

  if not self._loop and duration > 0 and self._anim_t >= duration then
    self:_OnAnimFinished()
  end
end

function UIImageAnim:OnUpdate(dt)
  if self._anim == nil or self._paused then
    return
  end

  self._accum_dt = self._accum_dt + dt
  if self._accum_dt < self._frame_step then
    return
  end

  local step = self._accum_dt
  self._accum_dt = 0
  if step > 0.12 then
    step = 0.12
  end

  self:_Advance(step)
end

return UIImageAnim
