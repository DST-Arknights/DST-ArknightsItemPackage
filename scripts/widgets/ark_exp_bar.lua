local Widget = require "widgets/widget"
local Image = require "widgets/image"

local ArkExpBar = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkExpBar")
    self.owner = owner
    
    -- 配置参数
    self.config = {
        size = {300, 20},
        border = 2,
        tint_bg = {0.23, 0.23, 0.23, 1},
        tint_inner = {0, 0, 0, 0.5},
        tint_preview = {0.4, 0.7, 1, 0.6},
        -- [新增] 闪烁配置
        tint_flash = {1, 1, 1, 1},   -- 闪烁层的颜色（通常白色或亮金色）
        flash_speed = 4,             -- 闪烁频率
        flash_min_alpha = 0.0,       -- 最小透明度
        flash_max_alpha = 0.6,       -- 最大透明度
        
        scroll_speed = 50,
        anim_speed_linear = 100,
        anim_smooth_factor = 10,
    }

    self.totalExp = 100
    self.currentExp = 0
    self.displayedExp = 0
    
    -- 用于计算闪烁的时间累加器
    self.flashTime = 0 

    self:_InitBackgrounds()
    self:_InitPreviewBar()
    self:_InitScrollSystem()
    
    -- 4. [新增] 初始化闪烁遮罩层
    self:_InitFlashOverlay()

    self:SetSize(self.config.size[1], self.config.size[2])
    self.owner:StartUpdatingComponent(self)

    -- test: 
    self.testTask = self.owner:DoPeriodicTask(3, function()
        -- 测试：加经验，直到超过满级演示闪烁
        local nextExp = self.currentExp + 30
        self:SetExp(nextExp, self.totalExp)
    end)
end)

--------------------------------------------------------------------------
-- 初始化构建部分
--------------------------------------------------------------------------

function ArkExpBar:_InitBackgrounds()
    self.bg1 = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.bg1:SetTint(unpack(self.config.tint_bg))
    self.bg1:SetHRegPoint(ANCHOR_LEFT)

    self.bg2 = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.bg2:SetTint(unpack(self.config.tint_inner))
    self.bg2:SetHRegPoint(ANCHOR_LEFT)
end

function ArkExpBar:_InitPreviewBar()
    self.previewBar = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.previewBar:SetTint(unpack(self.config.tint_preview))
    self.previewBar:SetHRegPoint(ANCHOR_LEFT)
    self.previewBar:SetSize(0, 0) 
end

function ArkExpBar:_InitScrollSystem()
    self.progressClip = self:AddChild(Widget("progressClip"))
    self.scrollTextureBox = self.progressClip:AddChild(Widget("scrollTextureBox"))
    self.scrollTextures = {}
    
    local firstTex = self.scrollTextureBox:AddChild(Image("images/ark_item_ui.xml", "progress_bar_slice.tex"))
    table.insert(self.scrollTextures, firstTex)
    firstTex:SetHRegPoint(ANCHOR_LEFT)
    
    local w, h = firstTex:GetSize()
    self.scrollTextureWidth = w
    self.scrollTextureQuarterHeight = h / 4
    self.scrollOffset = 0
end

-- [新增] 初始化闪烁层
function ArkExpBar:_InitFlashOverlay()
    -- 这是一个覆盖在进度条最上方的白色图层
    self.flashOverlay = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.flashOverlay:SetHRegPoint(ANCHOR_LEFT)
    
    -- 设置为叠加混合模式，会让闪烁看起来像发光 (如果不喜欢太亮，可以删掉这行)
    if self.flashOverlay.SetBlendMode then
        self.flashOverlay:SetBlendMode(BLENDMODE.Additive)
    end

    -- 初始隐藏
    self.flashOverlay:Hide()
    self.flashOverlay:SetClickable(false) -- 确保不阻挡鼠标点击
end

--------------------------------------------------------------------------
-- 核心逻辑部分
--------------------------------------------------------------------------

function ArkExpBar:OnUpdate(dt)
    self:UpdateTextureScroll(dt)
    self:UpdateExpAnimation(dt)
    
    -- [新增] 更新闪烁逻辑
    self:UpdateFlashAnimation(dt)
end

-- [修改] 处理满级闪烁：等待动画完成后再闪烁
function ArkExpBar:UpdateFlashAnimation(dt)
    -- 1. 目标是否已满级？
    local isTargetMax = self.currentExp >= self.totalExp
    
    -- 2. 动画是否已跑完？(显示值是否已经追上了目标值)
    -- 我们允许极其微小的误差，或者直接判断 >= 
    local isAnimFinished = self.displayedExp >= (self.currentExp - 0.01)

    -- 只有同时满足：(设定已满级) 且 (血条已经跑到位置了) 才闪烁
    if isTargetMax and isAnimFinished then
        if not self.flashOverlay:IsVisible() then
            self.flashOverlay:Show()
            -- 刚开始闪烁时，重置一下时间，让波形从0开始 (Alpha从最小值开始)，过渡更自然
            self.flashTime = 0 
        end

        self.flashTime = self.flashTime + dt
        
        -- 正弦波呼吸逻辑 (0~1)
        local sinVal = (math.sin(self.flashTime * self.config.flash_speed) + 1) * 0.5
        
        -- 映射透明度
        local alpha = self.config.flash_min_alpha + sinVal * (self.config.flash_max_alpha - self.config.flash_min_alpha)
        
        local r, g, b = unpack(self.config.tint_flash)
        self.flashOverlay:SetTint(r, g, b, alpha)
    else
        -- 未满级 或者 动画还在跑，隐藏闪烁
        if self.flashOverlay:IsVisible() then
            self.flashOverlay:Hide()
            self.flashTime = 0
        end
    end
end

function ArkExpBar:UpdateTextureScroll(dt)
    if self.config.scroll_speed == 0 then return end
    self.scrollOffset = self.scrollOffset + self.config.scroll_speed * dt
    if self.scrollTextureQuarterHeight > 0 then
        self.scrollOffset = self.scrollOffset % self.scrollTextureQuarterHeight
    end
    self.scrollTextureBox:SetPosition(0, -self.scrollOffset, 0)
end

function ArkExpBar:UpdateExpAnimation(dt)
    if math.abs(self.displayedExp - self.currentExp) < 0.01 then
        if self.displayedExp ~= self.currentExp then
            self.displayedExp = self.currentExp
            self:RefreshProgressVisuals()
        end
        return
    end

    if self.displayedExp < self.currentExp then
        local diff = self.currentExp - self.displayedExp
        local speed = diff * self.config.anim_smooth_factor
        local min_speed = 10 
        self.displayedExp = self.displayedExp + math.max(speed, min_speed) * dt
        if self.displayedExp > self.currentExp then self.displayedExp = self.currentExp end
    else
        self.displayedExp = self.displayedExp - self.config.anim_speed_linear * dt
        if self.displayedExp < self.currentExp then self.displayedExp = self.currentExp end
    end
    self:RefreshProgressVisuals()
end

function ArkExpBar:RefreshProgressVisuals()
    local maxVal = math.max(1, self.totalExp)
    
    local scrollProgress = math.min(math.max(self.displayedExp / maxVal, 0), 1)
    local scrollWidth = scrollProgress * self.content_size[1]

    -- 裁切滚动条
    self.progressClip:SetScissor(0, -self.content_size[2]/2, scrollWidth, self.content_size[2])

    -- 预览条
    local targetProgress = math.min(math.max(self.currentExp / maxVal, 0), 1)
    local previewWidth = targetProgress * self.content_size[1]
    self.previewBar:SetSize(previewWidth, self.content_size[2])
end

--------------------------------------------------------------------------
-- 对外接口
--------------------------------------------------------------------------

function ArkExpBar:SetExp(current, total)
    self.currentExp = current
    self.totalExp = total or self.totalExp
    self:RefreshProgressVisuals()
    
    -- 这里不需要额外写闪烁逻辑，因为OnUpdate会自动检测 currentExp >= totalExp
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

    self.bg1:SetSize(width, height)
    self.bg2:SetSize(self.content_size[1], self.content_size[2])
    self.bg2:SetPosition(self.content_pos)
    
    self.previewBar:SetPosition(self.content_pos)
    self.previewBar:SetSize(0, self.content_size[2]) 

    self.progressClip:SetPosition(self.content_pos)
    
    -- [新增] 设置闪烁层的大小和位置
    -- 它的大小应该等于内容区域的大小（除去边框），覆盖在所有条之上
    self.flashOverlay:SetPosition(self.content_pos)
    self.flashOverlay:SetSize(self.content_size[1], self.content_size[2])

    self:RefreshScrollTextures()
    self:RefreshProgressVisuals()
end

function ArkExpBar:RefreshScrollTextures()
    if not self.scrollTextureWidth or self.scrollTextureWidth <= 0 then return end
    local needed = math.ceil(self.content_size[1] / self.scrollTextureWidth)
    local current = #self.scrollTextures
    if current < needed then
        for i = current + 1, needed do
            local tex = self.scrollTextureBox:AddChild(Image("images/ark_item_ui.xml", "progress_bar_slice.tex"))
            tex:SetHRegPoint(ANCHOR_LEFT)
            tex:SetPosition((i - 1) * self.scrollTextureWidth, 0, 0)
            table.insert(self.scrollTextures, tex)
        end
    elseif current > needed then
        for i = current, needed + 1, -1 do
            local tex = table.remove(self.scrollTextures)
            tex:Kill()
        end
    end
end

return ArkExpBar