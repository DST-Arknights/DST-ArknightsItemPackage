local function GenSafeCall(fn)
	-- 返回一个函数 safeCall，每次调用时重新计算 fn()
	-- 如果 fn() 返回 nil，则返回一个“万能空对象”，
	-- 可以安全地访问任意字段、调用任意方法并继续链式调用。
	local proxy = {}
	local mt = {
		-- 访问任何字段都返回同一个 proxy，支持链式访问：a:b():c().d
		__index = function()
			return proxy
		end,
		-- 调用任何方法/函数都返回 proxy 本身，继续链式调用
		__call = function()
			return proxy
		end,
		-- 赋值操作静默忽略
		__newindex = function()
		end,
	}
	setmetatable(proxy, mt)

	return function(...)
		local obj = fn(...) -- 重新执行 fn，获取最新对象
		if obj ~= nil then
			return obj -- 如果对象存在，直接返回它（包括布尔值）
		end
		-- 对象不存在时，返回安全 proxy，保证 :SetupElite() 等调用不报错
		return proxy
	end
end

GLOBAL.GenSafeCall = GenSafeCall
return GenSafeCall
