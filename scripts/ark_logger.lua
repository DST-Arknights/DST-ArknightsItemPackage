-- 确保 Class 函数存在 (饥荒环境中默认存在，如果在外部测试需要自己定义)
-- require "class" 

local LOG_LEVEL = {
    NONE = -1,
    TRACE = 0,
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

local Logger = Class(function(self, level, name, enabled, timestamp)
    -- 1. 初始化名称 (默认为 "Logger")
    self.name = name or modname or "Logger"

    -- 2. 初始化级别 (支持字符串或数字，默认为 INFO)
    self.level = self:ParseLevel(level)

    -- 3. 初始化开关 (默认为 true)
    self.enabled = (enabled ~= false)

    -- 4. 初始化时间戳开关 (默认为 true)
    self.timestamp = (timestamp ~= false)
end)

-- 将常量挂载到类上，方便外部访问，如 Logger.LEVEL.DEBUG
Logger.LEVEL = LOG_LEVEL

-- 建立反向映射表：级别数字 -> 级别名称
local LEVEL_NAME = {}
for name, level in pairs(LOG_LEVEL) do
    LEVEL_NAME[level] = name
end

-- 辅助：解析级别参数
function Logger:ParseLevel(level)
    if type(level) == "number" then
        return level
    end
    if type(level) == "string" then
        return LOG_LEVEL[level:upper()] or LOG_LEVEL.INFO
    end
    -- 默认级别
    return LOG_LEVEL.INFO
end

-- 辅助：获取级别名称
function Logger:GetLevelName(level)
    return LEVEL_NAME[level] or "LOG"
end

-- 核心打印函数
function Logger:Log(level, ...)
    -- 检查开关和级别
    if not self.enabled or level < self.level then
        return
    end

    local parts = {}

    -- 1. 添加时间戳
    if self.timestamp then
        table.insert(parts, string.format("[%s]", os.date("%Y-%m-%d %H:%M:%S")))
    end

    -- 2. 添加名称
    if self.name then
        table.insert(parts, string.format("[%s]", self.name))
    end

    -- 3. 添加级别名称
    table.insert(parts, string.format("[%s]", self:GetLevelName(level)))

    -- 组合前缀
    local prefix = table.concat(parts, " ")
    
    -- 饥荒中通常使用 print，如果你的环境有 modprint，可以替换下面这行
    print(prefix, unpack({...}))
end

--------------------------------------------------------------------------
-- 公开调用的方法
--------------------------------------------------------------------------

function Logger:Trace(...)
    self:Log(LOG_LEVEL.TRACE, ...)
end

function Logger:Debug(...)
    self:Log(LOG_LEVEL.DEBUG, ...)
end

function Logger:Info(...)
    self:Log(LOG_LEVEL.INFO, ...)
end

function Logger:Warn(...)
    self:Log(LOG_LEVEL.WARN, ...)
end

function Logger:Error(...)
    self:Log(LOG_LEVEL.ERROR, ...)
end
local logger = Logger(LOG_LEVEL.TRACE, 'DEFAULT')

local loggerCache = {}

-- 尝试从调用栈中找到“声明 logger 的模组环境”
-- 逻辑：从当前函数的上层调用开始，逐级向上查找第一个同时包含 MODROOT 和 modname 的 fenv
-- 这样，无论是本模组还是其他模组调用，都尽量绑定到“声明 logger 的那个模组”的环境
local function FindCallerModEnv()
	-- level 1: FindCallerModEnv
	-- level 2: ArkLogger:DeclareLogger
	-- level 3 开始才是实际的调用方 / 其上层
	local level = 3
	while true do
		local info = debug.getinfo(level, "f")
		if info == nil then
			return nil
		end

		local f = info.func
		local fenv = getfenv and getfenv(f) or nil
		if fenv and rawget(fenv, "MODROOT") and rawget(fenv, "modname") then
			return fenv
		end

		level = level + 1
	end
end

-- 允许用户在模组里声明logger
local ArkLogger = Class(function(self)
end)

function ArkLogger:DeclareLogger(level, name, enabled, timestamp)
	-- 优先尝试从调用栈中推断“声明 logger 的模组环境”
	local caller_env = FindCallerModEnv()
	if caller_env and caller_env.MODROOT then
		local mroot = caller_env.MODROOT
		local mname = caller_env.modname

		-- 默认名称：优先使用显式传入的 name，其次使用调用方的 modname，最后退回本模组名
		local logger_name = name or mname or modname or "Logger"

		-- 允许重复声明，新的声明会覆盖旧的
		loggerCache[mroot] = Logger(level, logger_name, enabled, timestamp)
		return loggerCache[mroot]
	end

	-- 找不到调用方模组环境时，退回到默认 logger，避免报错
	return logger
end
local function getFilePath()
    local status, result = pcall(function()
        local source = debug.getinfo(6, "S").source
        source = source:gsub("\\", "/")
        return source
    end)
    if not status then
        return nil
    end
    return result
end
local pathLoggerCache = {}
local function MathLogger(path)
    if not path then
        return logger
    end
    if pathLoggerCache[path] then
        return pathLoggerCache[path]
    end
    -- 遍历loggerCache，找到最长匹配的MODROOT
    local bestMatch = nil
    local bestMatchLen = 0
    for modroot, loggerInstance in pairs(loggerCache) do
        if modroot ~= 'DEFAULT' then
            -- 统一路径分隔符为 /
            local normalizedModroot = modroot:gsub("\\", "/")
            if string.find(path, normalizedModroot, 1, true) == 1 then
                -- 检查是否是最长匹配
                if #normalizedModroot > bestMatchLen then
                    bestMatch = loggerInstance
                    bestMatchLen = #normalizedModroot
                end
            end
        end
    end

    if bestMatch then
        pathLoggerCache[path] = bestMatch
        return bestMatch
    end

    pathLoggerCache[path] = logger
    return logger
end
function ArkLogger:GetLogger()
    local path = getFilePath()
    return MathLogger(path)
end

function ArkLogger:Trace(...)
    self:GetLogger():Trace(...)
end
function ArkLogger:Debug(...)
    self:GetLogger():Debug(...)
end
function ArkLogger:Info(...)
    self:GetLogger():Info(...)
end
function ArkLogger:Warn(...)
    self:GetLogger():Warn(...)
end
function ArkLogger:Error(...)
    self:GetLogger():Error(...)
end

GLOBAL.ArkLogger = ArkLogger()
return Logger
