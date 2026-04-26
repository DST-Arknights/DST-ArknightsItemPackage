local SourceModifierList = require("util/sourcemodifierlist")
local function GetClassIndex()
  local class = Class(function() end, nil, {})
  return class.__index, class.__newindex
end

local __index, __newindex = GetClassIndex()

local function RunPipeline(class, pipeline)
  local value = class[pipeline.base_symbol]
  for _, step in ipairs(pipeline.steps) do
    value = step.calc_fun(class.inst, step.modifier, value)
  end
  local props = rawget(class, "_")
  local old = props[pipeline.prop_name][1]
  props[pipeline.prop_name][1] = value
  if pipeline.old_setter then
    pipeline.old_setter(class, value, old)
  end
end

local function GetOrCreatePipeline(class, property_name)
  local pipeline_key = "_pipeline_" .. property_name
  local existing = rawget(class, pipeline_key)
  if existing then
    return existing, false
  end
  local props = rawget(class, "_")
  local old_setter = props[property_name] and props[property_name][2] or nil
  local base_symbol = Symbol("modifier_base_" .. property_name)
  class[base_symbol] = class[property_name]
  local pipeline = {
    base_symbol = base_symbol,
    prop_name = property_name,
    steps = {},
    old_setter = old_setter,
  }
  rawset(class, pipeline_key, pipeline)
  return pipeline, true
end

function GLOBAL.InstallClassPropertyModifier(class, property_name, config)
  local props = rawget(class, "_")
  -- 没有定义过__newindex 的无法安装
  assert(props ~= nil, "Class does not have a _ property, cannot install modifier")
  -- config: modifier_name, default_value, combine_fun, calc_fun, modified_callback
  assert(type(config) == "table", "config must be a table")
  assert(config.calc_fun == nil or type(config.calc_fun) == "function", "config.calc_fun must be a function")
  assert(config.modified_callback == nil or type(config.modified_callback) == "function",
    "config.modified_callback must be a function")

  local meta_table = getmetatable(class)
  if meta_table.__index == meta_table then
    meta_table.__index = __index
    meta_table.__newindex = __newindex
  end

  local pipeline, is_new = GetOrCreatePipeline(class, property_name)

  local modifier_name = config.modifier_name or property_name .. "modifiers"
  local default_value = config.default_value or 1
  local combine_fun = config.combine_fun or SourceModifierList.multiply
  local calc_fun = config.calc_fun or function(inst, modifier, value) return value * modifier:Get() end
  local modified_callback = config.modified_callback or function(inst, modifier) end

  -- 先占位，modifier 创建后填入
  local step = { calc_fun = calc_fun, modified_callback = modified_callback }

  local modifier = SourceModifierList(class.inst, default_value, combine_fun, function(inst, mod)
    RunPipeline(class, pipeline)
    step.modified_callback(inst, mod)
  end)

  step.modifier = modifier
  class[modifier_name] = modifier
  table.insert(pipeline.steps, step)

  -- 只在第一次安装时替换 setter
  if is_new then
    local new_setter = function(self, new_value, old_value)
      self[pipeline.base_symbol] = new_value
      RunPipeline(self, pipeline)
    end
    if props[property_name] then
      props[property_name][2] = new_setter
    else
      addsetter(class, property_name, new_setter)
    end
  end
end
