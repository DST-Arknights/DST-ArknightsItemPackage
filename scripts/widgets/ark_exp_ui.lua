local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local common = require "ark_common"

local function TestExpSync(self)
    -- 测试数据
    local testData = {
        -- 测试连续变更场景
        {elite = 1, level = 1, leftExp = 0},     -- 初始状态
        {elite = 1, level = 1, leftExp = 20},    -- 小幅增加
        {elite = 1, level = 1, leftExp = 30},    -- 动画未完成时再次增加
        {elite = 1, level = 1, leftExp = 80},    -- 动画减速阶段时大幅增加
        {elite = 1, level = 1, leftExp = 90},    -- 动画减速阶段时小幅增加
        -- 测试等级变更场景
        {elite = 1, level = 2, leftExp = 20},    -- 升级
        {elite = 1, level = 2, leftExp = 50},    -- 普通增加
        {elite = 1, level = 2, leftExp = 90},    -- 动画减速阶段时增加
        -- 测试精英化场景
        {elite = 2, level = 1, leftExp = 20},    -- 精英化
        {elite = 2, level = 1, leftExp = 60},    -- 动画未完成时增加
    }
    
    local currentIndex = 1
    -- 每1秒同步一次数据，缩短间隔以便观察连续变更效果
    self.testTask = self.owner:DoPeriodicTask(1, function()
        local data = testData[currentIndex]
        if data then
            -- 打印当前状态便于调试
            -- print(string.format("Test Data %d: elite=%d, level=%d, leftExp=%d", 
            --     currentIndex, data.elite, data.level, data.leftExp))
            self:SetData(1, 1, data.elite, data.level, data.leftExp)
            currentIndex = currentIndex + 1
            if currentIndex > #testData then
                currentIndex = 1  -- 循环播放
            end
        end
    end)
end

local ArkExp = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkExp")
    self.owner = owner
    self.width = 800
    self.height = 10
    -- 三个背景条, 一个常态背景, 一个立即进度背景, 一个动画进度背景
    local progressBar = self:AddChild(Widget("arkExpProgressBar"))
    local progressBarBg = progressBar:AddChild(Image("images/ui.xml", "white.tex"))
    progressBarBg:SetSize(self.width, self.height)
    progressBarBg:SetTint(0, 0, 0, 0.8)
    local progressBarFill = progressBar:AddChild(Image("images/ui.xml", "white.tex"))
    self.progressBarFill = progressBarFill
    progressBarFill:SetSize(self.width, self.height)
    progressBarFill:SetTint(0, 0, .6, 0.8)
    -- 设置进度条的锚点为左侧
    progressBarFill:SetHRegPoint(ANCHOR_LEFT)
    progressBarFill:SetPosition(self.width/-2, 0, 0)
    local progressBarAnim = progressBar:AddChild(Image("images/ui.xml", "white.tex"))
    self.progressBarAnim = progressBarAnim
    progressBarAnim:SetSize(self.width, self.height)
    progressBarAnim:SetTint(0, .6, 0, 0.8)
    -- 设置动画进度条的锚点为左侧
    progressBarAnim:SetHRegPoint(ANCHOR_LEFT)
    progressBarAnim:SetPosition(self.width/-2, 0, 0)
    local infoWidget = self:AddChild(Widget("arkExpInfo"))
    local infoText = infoWidget:AddChild(Text(FALLBACK_FONT_FULL, 24))
    self.infoText = infoText
    infoText:SetPosition(self.width/-2 - 80, 80, 0)

    -- 动画相关的属性
    self.currentProgress = 0  -- 当前动画进度
    self.targetProgress = 0   -- 目标进度
    self.animSpeed = 0.5      -- 基础动画速度
    self.upgradeAnimSpeed = 0.8  -- 升级动画速度（比普通动画快）
    self.slowdownThreshold = 0.1  -- 开始减速的距离阈值
    self.lastDiff = 0         -- 上一帧的差值
    self.data = {
        elite = 0,
        level = 0,
    }
    
    self.owner:StartUpdatingComponent(self)
    
    -- 启动测试
    TestExpSync(self)
end)

local function UpdateProgress(self, dt)
    if self.currentProgress == self.targetProgress then
        return
    end

    local diff = self.targetProgress - self.currentProgress
    local absDiff = math.abs(diff)
    local direction = diff > 0 and 1 or -1

    -- 计算实际速度
    local speed = self.animSpeed
    if absDiff < self.slowdownThreshold then
        -- 只有在接近最终目标时才减速
        if absDiff >= self.lastDiff then
            -- 如果差值在增大，说明目标在远离，使用满速
            speed = self.animSpeed
        else
            -- 否则按照接近程度减速
            speed = speed * (absDiff / self.slowdownThreshold)
        end
    end
    
    self.lastDiff = absDiff
    local newProgress = self.currentProgress + direction * speed * dt
    
    -- 确保不会过头
    if direction > 0 then
        self.currentProgress = math.min(newProgress, self.targetProgress)
    else
        self.currentProgress = math.max(newProgress, self.targetProgress)
    end

    -- 更新动画进度条
    self.progressBarAnim:SetScissor(0, self.height/-2, self.currentProgress * self.width, self:GetWorldSize().y * 2)
end

function ArkExp:GetWorldSize()
    local scale = self:GetScale()
    return Vector3(self.width * scale.x, self.height * scale.y, 0)
end

function ArkExp:OnUpdate(dt)
    UpdateProgress(self, dt)
end

function ArkExp:SetData(rarity, potential, elite, level, leftExp)
    -- 计算目标进度
    local nextLevelExp = common.getNextLevelExp(elite, level)
    -- 确保进度不超过1
    local progress = nextLevelExp and math.min(leftExp / nextLevelExp, 1) or 0
    
    -- 打印调试信息
    -- print(string.format("SetData: elite=%d, level=%d, leftExp=%d, nextLevelExp=%s, progress=%.2f", 
    --     elite, level, leftExp, tostring(nextLevelExp), progress))
    
    -- 立即更新即时进度条
    self.progressBarFill:SetScissor(0, self.height/-2, progress * self.width, self:GetWorldSize().y)
    -- 检查等级是否变动（包括精英化等级）
    local levelChanged = elite ~= self.data.elite or level ~= self.data.level
    
    if levelChanged then
        -- 等级变动时，从0开始动画
        self.currentProgress = 0
        self.targetProgress = progress
        -- print(string.format("Level changed, starting animation from 0 to %.2f", progress))
    else
        -- 普通经验值变化，直接设置目标
        self.targetProgress = progress
        -- print(string.format("Normal exp change: setting target progress to %.2f", progress))
    end
    
    -- 更新当前等级信息
    self.data.elite = elite
    self.data.level = level
    -- 更新文本信息
    if nextLevelExp then
        self.infoText:SetString(string.format("Elite%d\nLevel%d\n(%d/%d)", elite, level, leftExp, nextLevelExp))
    else
        self.infoText:SetString(string.format("Elite%d\nLevel%d (Max)", elite, level))
    end
end

return ArkExp
