-- 动态 bigportrait：保留原 Image，选人界面和玩家资料卡使用独立 UIAnim。
-- 在角色模组的 modmain / modimport 中、最终 Assets 声明之后注册。
local portrait_defs = {}

local function IsNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

local function IsFiniteNumber(value)
  return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function GLOBAL.RegisterArkBigPortraitAnim(character, config)
  assert(IsNonEmptyString(character), "Ark bigportrait character must be a non-empty string.")
  assert(type(config) == "table", "Ark bigportrait config must be a table.")
  assert(portrait_defs[character] == nil, "Ark bigportrait already registered: " .. character)
  assert(IsNonEmptyString(config.asset), "Ark bigportrait asset must be an animation ZIP path.")
  assert(IsNonEmptyString(config.bank), "Ark bigportrait bank must be a non-empty string.")
  assert(IsNonEmptyString(config.build), "Ark bigportrait build must be a non-empty string.")

  local asset = config.asset:gsub("\\", "/")
  assert(asset:sub(1, 1) ~= "/" and not asset:match("^%a:") and asset:match("%.zip$"),
    "Ark bigportrait asset must be a ZIP path relative to the calling mod.")

  local anims = {}
  if IsNonEmptyString(config.anim) then
    anims[1] = config.anim
  else
    assert(type(config.anim) == "table", "Ark bigportrait anim must be a name or a non-empty array.")
    local count = 0
    for index, name in pairs(config.anim) do
      assert(type(index) == "number" and index >= 1 and index % 1 == 0 and IsNonEmptyString(name),
        "Ark bigportrait anim must be an array of non-empty animation names.")
      count = count + 1
    end
    assert(count > 0, "Ark bigportrait anim array must not be empty.")
    for index = 1, count do
      assert(IsNonEmptyString(config.anim[index]), "Ark bigportrait anim array must not contain holes.")
      anims[index] = config.anim[index]
    end
  end

  local scale = config.scale == nil and 1 or config.scale
  assert(IsFiniteNumber(scale) and scale > 0, "Ark bigportrait scale must be a positive finite number.")
  local offset = config.offset == nil and { 0, 0 } or config.offset
  assert(type(offset) == "table" and IsFiniteNumber(offset[1]) and IsFiniteNumber(offset[2]),
    "Ark bigportrait offset must contain two finite numbers.")

  -- 原版加载上下文已持有角色模组环境，不把资源误插入物品包的 Assets。
  local modname = ModManager.currentlyloadingmod
  local caller_env = modname ~= nil and ModManager:GetMod(modname) or nil
  assert(caller_env ~= nil, "RegisterArkBigPortraitAnim must be called during modmain / modimport initialization.")
  local assets = rawget(caller_env, "Assets")
  assert(assets == nil or type(assets) == "table", "Calling mod Assets must be a table.")
  if assets == nil then
    assets = {}
    caller_env.Assets = assets
  end
  local found = false
  for _, existing in ipairs(assets) do
    if existing.type == "ANIM" and existing.file:gsub("\\", "/") == asset then
      found = true
      break
    end
  end
  if not found then
    table.insert(assets, Asset("ANIM", asset))
  end

  -- 复制配置，避免调用方后续改表改变正在播放的序列。
  portrait_defs[character] = {
    bank = config.bank,
    build = config.build,
    anims = anims,
    scale = scale,
    offset = { offset[1], offset[2] },
  }
end

if TheNet:IsDedicated() then return end

local UIAnim = require "widgets/uianim"

local function SyncLayout(state)
  if state.anim == nil or not state.active
    or not state.image.inst:IsValid() or not state.anim.inst:IsValid() then return end
  local image, def = state.image, state.def
  local position = image:GetPosition()
  local sx, sy, sz = image:GetLooseScale()
  state.anim:SetPosition(position.x + def.offset[1], position.y + def.offset[2], position.z)
  state.anim:SetScale(sx * def.scale, sy * def.scale, sz)
  state.anim:SetRotation(image:GetRotation())
  local tint = image.tint
  state.anim:GetAnimState():SetMultColour(tint[1], tint[2], tint[3], tint[4] * state.fadealpha)
end

local function HideStatic(state)
  state.hiding_static = true
  state.image:Hide()
  state.hiding_static = false
end

local function UpdatePortrait(root, state)
  local character = root.currentcharacter
  local def = character ~= nil and portrait_defs[character] or nil
  state.def = def
  state.active = def ~= nil
  if def == nil then
    if state.anim ~= nil then
      state.anim:Hide()
      state.anim:GetAnimState():Pause()
    end
    state.character = nil
    return
  end

  if state.anim == nil then
    state.anim = state.image.parent:AddChild(UIAnim())
    state.anim:Hide()
    state.anim:SetClickable(false)
    -- 只移动新动画，保留原 Image 及所有已有兄弟节点的层级关系。
    state.anim:MoveToBack()
  end
  local animstate = state.anim:GetAnimState()
  if state.character ~= character then
    animstate:SetBank(def.bank)
    animstate:SetBuild(def.build)
    animstate:PlayAnimation(def.anims[1], #def.anims == 1)
    for index = 2, #def.anims do
      animstate:PushAnimation(def.anims[index], index == #def.anims)
    end
    state.character = character
  end
  SyncLayout(state)
  state.static_shown = state.image.shown
  HideStatic(state)
  if state.static_shown then
    state.anim:Show()
    animstate:Resume()
  else
    state.anim:Hide()
    animstate:Pause()
  end
end

local function BindImage(image)
  local state = { image = image, active = false, fadealpha = 1 }
  local function AfterLayoutUpdate(...)
    SyncLayout(state)
    return ...
  end
  for _, method in ipairs({ "SetPosition", "SetScale", "SetRotation", "MoveTo", "ScaleTo", "RotateTo" }) do
    ArkHookFunction(state.image, method, function(next, image, ...)
      return AfterLayoutUpdate(next(image, ...))
    end)
  end
  ArkHookFunction(state.image, "SetTint", function(next, image, ...)
    -- 原版 SetTint 直接写颜色，会撤回此前 SetFadeAlpha 的乘数。
    state.fadealpha = 1
    return AfterLayoutUpdate(next(image, ...))
  end)
  ArkHookFunction(state.image, "SetFadeAlpha", function(next, image, alpha, ...)
    if image.can_fade_alpha then state.fadealpha = alpha end
    return AfterLayoutUpdate(next(image, alpha, ...))
  end)
  -- 原版补间逐帧直接写 UITransform；沿用它已有的更新，不添加常驻轮询。
  ArkHookFunction(state.image.inst.components.uianim, "OnWallUpdate", function(next, component, ...)
    return AfterLayoutUpdate(next(component, ...))
  end)

  -- 第三方仍可操作原 Image 的显隐；动态立绘同步这些操作。
  local function AfterShow(...)
    if state.active then
      state.static_shown = state.image.shown
      HideStatic(state)
      if state.static_shown then
        state.anim:Show()
        state.anim:GetAnimState():Resume()
      else
        state.anim:Hide()
        state.anim:GetAnimState():Pause()
      end
    end
    return ...
  end
  ArkHookFunction(state.image, "Show", function(next, image, ...)
    return AfterShow(next(image, ...))
  end)
  local function AfterHide(...)
    if state.active and not state.hiding_static then
      state.static_shown = false
      state.anim:Hide()
      state.anim:GetAnimState():Pause()
    end
    return ...
  end
  ArkHookFunction(state.image, "Hide", function(next, image, ...)
    return AfterHide(next(image, ...))
  end)

  return state
end

local function AttachPortrait(root, update_method)
  if root == nil or type(root[update_method]) ~= "function" then return end
  local state
  local function AfterPortraitUpdate(...)
    local image = root.portrait
    if state ~= nil and state.image ~= image then
      -- SetPlayer / Layout 可能重建 Image，仅销毁我们创建的旧动画。
      state.active = false
      if state.anim ~= nil and state.anim.inst:IsValid() then state.anim:Kill() end
      state = nil
    end
    if state == nil and image ~= nil and image.parent ~= nil and image.inst:IsValid() then
      state = BindImage(image)
    end
    if state ~= nil then UpdatePortrait(root, state) end
    return ...
  end
  ArkHookFunction(root, update_method, function(next, widget, ...)
    -- 先撤回我们自己的 Hide，再由原逻辑及其他 hook 决定新立绘是否显示。
    if state ~= nil and state.active and state.image == root.portrait and state.image.inst:IsValid() then
      state.active = false
      if state.static_shown then state.image:Show() end
    end
    return AfterPortraitUpdate(next(widget, ...))
  end)
  -- 构造函数已经更新过立绘，首次绑定也要立即显示动画。
  AfterPortraitUpdate()
end

AddClassPostConstruct("widgets/redux/characterselect", function(self)
  -- 图鉴等界面也复用 CharacterSelect，只接入入服选人页。
  if self.owner ~= nil and self.owner.name == "CharacterSelectPanel" then
    AttachPortrait(self.selectedportrait, "SetPortrait")
  end
end)

AddClassPostConstruct("widgets/playeravatarpopup", function(self)
  -- 点击玩家查看资料及玩家列表的资料按钮都经过此控件。
  -- 复用 currentcharacter，保留原版皮肤更新及 unknownmod/notselected 降级。
  AttachPortrait(self, "UpdateData")
end)
