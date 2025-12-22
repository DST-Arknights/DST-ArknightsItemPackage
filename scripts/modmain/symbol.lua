-- 创建Symbol的工厂函数
local function Symbol(description)
    -- 创建唯一对象（空表）
    local symbol = {}
    
    -- 添加描述属性（可选）
    if type(description) == "string" then
        -- 使用闭包保存描述文本而不是直接暴露
        local desc = description
        function symbol.getDescription()
            return desc
        end
    end
    
    -- 添加元方法支持调试输出
    setmetatable(symbol, {
        __tostring = function()
            return "Symbol(" .. (description or "") .. ")"
        end,
        
        -- 阻止意外修改（可选）
        __newindex = function()
            error("Symbols are immutable", 2)
        end
    })
    
    return symbol
end

GLOBAL.Symbol = Symbol