local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local BorderWidget = require "widgets/border_widget"

--[[
    经验条系统 (Chase Animation Model)

    核心设计:
    - real: 服务端同步的真实数据 {level, exp}
    - anim: UI动画数据 {level, exp}，持续追赶 real
    - 追赶动画接近最终目标时减速，中间等级全速通过
    - 每级100%时触发闪烁，然后升级继续追赶

    状态机:
    - "idle": 动画已追上真实数据
    - "chasing": 正在追赶
    - "flashing": 等待闪烁动画完成
]]

local ArkExpBar = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkExpBar")
    self.owner = owner

    -- 配置
    self.config = {
        size = {232, 8},
        border = 2,
        -- 颜色
        tint_bg = {0.23, 0.23, 0.23, 1},
        tint_inner = {0, 0, 0, 0.5},
        tint_preview = {0.4, 0.7, 1, 0.6},
        tint_flash = {1, 1, 1, 1},
        -- 滚动纹理
        scroll_speed = 50,
        -- 追赶动画 (百分比速度，与经验值无关)
        chase_base_speed = 1,   -- 基础速度 (进度条百分比/秒，1 = 1秒填满)
        chase_min_speed = 0.08,   -- 最小速度 (接近目标时)
        chase_decel_pct = 0.15,   -- 减速阈值 (剩余进度百分比)
        -- 闪烁动画
        flash_fade_speed = 4.0,   -- 闪烁消退速度
    }

    -- 数据模型
    self.real = { elite = 1, level = 1, exp = 0 }  -- 服务端数据
    self.anim = { elite = 1, level = 1, exp = 0 }  -- 动画数据

    -- 状态
    self.state = "idle"        -- idle | chasing | flashing
    self.flashAlpha = 0        -- 闪烁透明度

    -- 缓存 (减少每帧计算和 UI 调用)
    self._cache = {
        animTotalExp = 100,    -- 当前动画等级的 totalExp
        animElite = 1,         -- 上次缓存的动画精英化等级
        animLevel = 1,         -- 上次缓存的动画等级
        animWidth = -1,        -- 上次动画条宽度
        previewWidth = -1,     -- 上次预览条宽度
        expDisplay = -1,       -- 上次显示的经验值
    }

    -- 初始化 UI 组件
    self:_InitUI()
    self:SetSize(self.config.size[1], self.config.size[2])
    self.owner:StartUpdatingComponent(self)
    self.owner:DoTaskInTime(0, function()
      local state = self.owner.replica.ark_elite and self.owner.replica.ark_elite.state
      if state then
        self:SetRealData(state.elite, state.level, state.currentExp, true)
      end
    end)
end)

-- 初始化所有 UI 组件
function ArkExpBar:_InitUI()
    -- 背景层
    self.backgroundPanel = self:AddChild(BorderWidget(0, 0, {
        borderWidth = self.config.border,
        borderColor = self.config.tint_bg,
        backgroundColor = self.config.tint_inner,
    }))
    self.bg1 = self.backgroundPanel.borderImage
    self.bg2 = self.backgroundPanel.innerImage

    -- 预览条 (显示真实进度)
    self.previewBar = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.previewBar:SetTint(unpack(self.config.tint_preview))
    self.previewBar:SetHRegPoint(ANCHOR_LEFT)
    self.previewBar:SetSize(0, 0)

    -- 滚动纹理进度条
    self.progressClip = self:AddChild(Widget("progressClip"))
    self.scrollTextureBox = self.progressClip:AddChild(Widget("scrollTextureBox"))
    self.scrollTextures = {}
    local firstTex = self.scrollTextureBox:AddChild(Image("images/ark_item_ui.xml", "progress_bar_slice.tex"))
    firstTex:SetHRegPoint(ANCHOR_LEFT)
    table.insert(self.scrollTextures, firstTex)
    local w, h = firstTex:GetSize()
    self.scrollTextureWidth = w
    self.scrollTextureQuarterHeight = h / 4
    self.scrollOffset = 0

    -- 闪烁层
    self.flashOverlay = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.flashOverlay:SetHRegPoint(ANCHOR_LEFT)
    if self.flashOverlay.SetBlendMode then
        self.flashOverlay:SetBlendMode(BLENDMODE.Additive)
    end
    self.flashOverlay:Hide()
    self.flashOverlay:SetClickable(false)

    -- 经验文字
    self.expText = self:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 18, "EXP 0/0"))
    self.expText:Hide()
end

----------------------------------------------------------------
-- 数据查询
----------------------------------------------------------------

-- 获取指定等级的升级所需经验 (直接查询，用于非当前等级)
function ArkExpBar:_GetTotalExp(level)
    local rep = self.owner and self.owner.replica and self.owner.replica.ark_elite
    return rep and rep:GetLevelUpExp(level) or 100
end

-- 获取当前动画等级的 totalExp (带缓存，考虑 elite 变化)
function ArkExpBar:_GetAnimTotalExp()
    if self._cache.animElite ~= self.anim.elite or self._cache.animLevel ~= self.anim.level then
        self._cache.animElite = self.anim.elite
        self._cache.animLevel = self.anim.level
        self._cache.animTotalExp = self:_GetTotalExp(self.anim.level)
    end
    return self._cache.animTotalExp
end

-- 计算从动画状态到真实目标的总经验距离
function ArkExpBar:_CalcDistanceToReal()
    if self.anim.level == self.real.level then
        return self.real.exp - self.anim.exp
    end
    -- 当前等级剩余 + 中间等级总和 + 最终等级目标
    local dist = self:_GetAnimTotalExp() - self.anim.exp
    for lvl = self.anim.level + 1, self.real.level - 1 do
        dist = dist + self:_GetTotalExp(lvl)
    end
    return dist + self.real.exp
end

----------------------------------------------------------------
-- 每帧更新
----------------------------------------------------------------

function ArkExpBar:OnUpdate(dt)
    self:_TickTextureScroll(dt)
    self:_TickChaseAnimation(dt)
    self:_TickFlashFade(dt)
end

-- 纹理滚动动画
function ArkExpBar:_TickTextureScroll(dt)
    if self.config.scroll_speed == 0 then return end
    self.scrollOffset = (self.scrollOffset + self.config.scroll_speed * dt) % self.scrollTextureQuarterHeight
    self.scrollTextureBox:SetPosition(0, -self.scrollOffset, 0)
end

-- 追赶动画主逻辑
function ArkExpBar:_TickChaseAnimation(dt)
    if self.state == "flashing" then return end



    -- 目标: 需升级则追到满，否则追到真实经验
    local needLevelUp = self.anim.level < self.real.level
    local targetExp = needLevelUp and self:_GetAnimTotalExp() or self.real.exp
    local diff = targetExp - self.anim.exp

    -- 已到达目标
    if diff < 0.5 then
        self.anim.exp = targetExp
        if needLevelUp then
            self:_TriggerFlash()
        else
            self.state = "idle"
        end
        self:_RefreshVisuals()
        return
    end

    -- 追赶中
    self.state = "chasing"
    local speed = self:_CalcChaseSpeed()
    self.anim.exp = math.min(self.anim.exp + speed * dt, targetExp)
    self:_RefreshVisuals()
end

-- 计算追赶速度 (基于百分比，接近最终目标时减速)
-- 返回：每秒增加的经验值
function ArkExpBar:_CalcChaseSpeed()
    local totalExp = self:_GetAnimTotalExp()
    local cfg = self.config

    -- 计算剩余进度百分比
    local needLevelUp = self.anim.level < self.real.level
    local targetExp = needLevelUp and totalExp or self.real.exp
    local remainingPct = (targetExp - self.anim.exp) / totalExp

    -- 基于百分比的速度
    local speedPct
    if remainingPct > cfg.chase_decel_pct then
        speedPct = cfg.chase_base_speed
    else
        -- 线性减速
        local ratio = remainingPct / cfg.chase_decel_pct
        speedPct = cfg.chase_min_speed + (cfg.chase_base_speed - cfg.chase_min_speed) * ratio
    end

    -- 转换为 exp/秒
    return speedPct * totalExp
end

-- 触发升级闪烁
function ArkExpBar:_TriggerFlash()
    self.state = "flashing"
    self.flashAlpha = 1.0
    self.flashOverlay:Show()
    self.flashOverlay:SetTint(1, 1, 1, 1)
end

-- 闪烁消退动画
function ArkExpBar:_TickFlashFade(dt)
    if self.flashAlpha <= 0 then return end

    self.flashAlpha = self.flashAlpha - self.config.flash_fade_speed * dt

    if self.flashAlpha <= 0 then
        self.flashAlpha = 0
        self.flashOverlay:Hide()
        if self.state == "flashing" then
            self:_OnLevelUp()
        end
    else
        local r, g, b = unpack(self.config.tint_flash)
        self.flashOverlay:SetTint(r, g, b, self.flashAlpha)
    end
end

-- 升级完成: 等级+1, 经验归零, 继续追赶
function ArkExpBar:_OnLevelUp()
    self.anim.level = self.anim.level + 1
    self.anim.exp = 0
    self.state = "chasing"
    self:_NotifyEliteUI()
    self:_RefreshVisuals()
end

-- 通知 elite_ui 更新等级显示
function ArkExpBar:_NotifyEliteUI()
    local extendUI = self.owner and self.owner.HUD and self.owner.HUD.controls and self.owner.HUD.controls.arkExtendUi
    if extendUI and extendUI.elite then
        extendUI.elite:SetLevel(self.anim.level)
    end
end

----------------------------------------------------------------
-- 视觉刷新
----------------------------------------------------------------

-- 刷新所有视觉元素 (带脏检查，避免无效 UI 调用)
function ArkExpBar:_RefreshVisuals()
    local cache = self._cache
    local totalExp = self:_GetAnimTotalExp()
    local contentW = self.content_size[1]
    local contentH = self.content_size[2]

    -- 动画进度条宽度
    local animProgress = math.min(self.anim.exp / totalExp, 1)
    local animWidth = math.floor(animProgress * contentW)
    if cache.animWidth ~= animWidth then
        cache.animWidth = animWidth
        self.progressClip:SetScissor(0, -contentH / 2, animWidth, contentH)
    end

    -- 预览条宽度 (升级中显示满)
    local previewExp = self.anim.level < self.real.level and totalExp or self.real.exp
    local previewProgress = math.min(previewExp / totalExp, 1)
    local previewWidth = math.floor(previewProgress * contentW)
    if cache.previewWidth ~= previewWidth then
        cache.previewWidth = previewWidth
        self.previewBar:SetSize(previewWidth, contentH)
    end

    -- 经验文字 (只在整数值变化时更新)
    local expDisplay = math.floor(self.anim.exp)
    if cache.expDisplay ~= expDisplay then
        cache.expDisplay = expDisplay
        self.expText:SetString("EXP " .. expDisplay .. "/" .. totalExp)
    end
end

----------------------------------------------------------------
-- 外部接口
----------------------------------------------------------------

function ArkExpBar:SetRealData(elite, level, exp, force)
    local eliteChanged = self.anim.elite ~= elite
    self.real.elite = elite
    self.real.level = level
    self.real.exp = exp

    -- 首次加载: 直接同步到真实数据，跳过动画 (或强制更新)
    if force then
        self.anim.elite = elite
        self.anim.level = level
        self.anim.exp = exp
        self.state = "idle"
        self:_NotifyEliteUI()
    elseif eliteChanged then
        -- 精英化变更时，从新阶段的 1 级 0 经验开始追赶
        self.anim.elite = elite
        self.anim.level = 1
        self.anim.exp = 0
        self.state = "chasing"
        self:_NotifyEliteUI()
    end

    self:_RefreshVisuals()
end

function ArkExpBar:GetSize()
    return self.config.size[1], self.config.size[2]
end

function ArkExpBar:SetSize(width, height)
    height = height or self.config.size[2]
    self.config.size = {width, height}

    local b = self.config.border
    self.content_pos = Vector3(b, 0, 0)
    self.content_size = {width - b * 2, height - b * 2}

    self.backgroundPanel:SetSize(width, height)
    self.backgroundPanel:SetPosition(width / 2, 0, 0)

    self.previewBar:SetPosition(self.content_pos)
    self.previewBar:SetSize(0, self.content_size[2])

    self.progressClip:SetPosition(self.content_pos)

    self.flashOverlay:SetPosition(self.content_pos)
    self.flashOverlay:SetSize(self.content_size[1], self.content_size[2])

    -- 经验文字位置 (居中，只需设置一次)
    self.expText:SetPosition(width / 2, 0, 0)

    -- 重置缓存，强制刷新
    self._cache.animWidth = -1
    self._cache.previewWidth = -1
    self._cache.expDisplay = -1

    self:_RefreshScrollTextures()
    self:_RefreshVisuals()
end

function ArkExpBar:_RefreshScrollTextures()
    if not self.scrollTextureWidth or self.scrollTextureWidth <= 0 then return end
    local needed = math.ceil(self.content_size[1] / self.scrollTextureWidth)
    local current = #self.scrollTextures

    for i = current + 1, needed do
        local tex = self.scrollTextureBox:AddChild(Image("images/ark_item_ui.xml", "progress_bar_slice.tex"))
        tex:SetHRegPoint(ANCHOR_LEFT)
        tex:SetPosition((i - 1) * self.scrollTextureWidth, 0, 0)
        table.insert(self.scrollTextures, tex)
    end

    for i = current, needed + 1, -1 do
        table.remove(self.scrollTextures):Kill()
    end
end

----------------------------------------------------------------
-- 焦点事件
----------------------------------------------------------------

function ArkExpBar:OnGainFocus()
    self.expText:Show()
end

function ArkExpBar:OnLoseFocus()
    self.expText:Hide()
end

return ArkExpBar
