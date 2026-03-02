local root = arg[1] or "."

local function join_path(base, relative)
  if base:sub(-1) == "/" or base:sub(-1) == "\\" then
    return base .. relative
  end
  return base .. "/" .. relative
end

local source_path = join_path(root, "scripts/ark_item_declare.lua")
local output_path = join_path(root, "docs/ark_item_enhanced_table.md")

local function read_all(path)
  local file, err = io.open(path, "r")
  if not file then
    error("无法读取文件: " .. path .. "\n" .. tostring(err))
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function write_all(path, content)
  local file, err = io.open(path, "w")
  if not file then
    error("无法写入文件: " .. path .. "\n" .. tostring(err))
  end
  file:write(content)
  file:close()
end

local function trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local source_text = read_all(source_path)

local names = {}
for line in source_text:gmatch("[^\r\n]+") do
  local prefab, name = line:match("prefab%s*=%s*'([^']+)'%s*,%s*%-%-%s*(.+)%s*$")
  if prefab and name then
    names[prefab] = trim(name)
  end
end

local CHARACTER_INGREDIENT = {
  HEALTH = "decrease_health",
  MAX_HEALTH = "half_health",
  SANITY = "decrease_sanity",
  MAX_SANITY = "half_sanity",
  OLDAGE = "decrease_oldage"
}

local FOODTYPE = {
  GENERIC = "GENERIC",
  MEAT = "MEAT",
  VEGGIE = "VEGGIE",
  ELEMENTAL = "ELEMENTAL",
  GEARS = "GEARS",
  HORRIBLE = "HORRIBLE",
  INSECT = "INSECT",
  SEEDS = "SEEDS",
  BERRY = "BERRY",
  RAW = "RAW",
  BURNT = "BURNT",
  NITRE = "NITRE",
  ROUGHAGE = "ROUGHAGE",
  WOOD = "WOOD",
  GOODIES = "GOODIES",
  MONSTER = "MONSTER",
  LUNAR_SHARDS = "LUNAR_SHARDS",
  CORPSE = "CORPSE",
  MIASMA = "MIASMA"
}

local TUNING = setmetatable({}, {
  __index = function(t, key)
    rawset(t, key, 0)
    return 0
  end
})

local env = {
  CHARACTER_INGREDIENT = CHARACTER_INGREDIENT,
  FOODTYPE = FOODTYPE,
  TUNING = TUNING
}

local chunk
local load_err
if _VERSION == "Lua 5.1" and setfenv then
  chunk, load_err = loadfile(source_path)
  if chunk then
    setfenv(chunk, env)
  end
else
  chunk, load_err = loadfile(source_path, "t", env)
end

if not chunk then
  error("加载 ark_item_declare.lua 失败:\n" .. tostring(load_err))
end

local ok, declared_items = pcall(chunk)
if not ok then
  error("执行 ark_item_declare.lua 失败:\n" .. tostring(declared_items))
end

local function is_sanity_prefab(prefab)
  if prefab == nil then
    return false
  end
  if prefab == CHARACTER_INGREDIENT.SANITY then
    return true
  end
  local as_text = tostring(prefab)
  return as_text:find("SANITY", 1, true) ~= nil
end

local function format_ref(prefab)
  local prefab_text = tostring(prefab)
  local display_name = names[prefab_text]
  if display_name and display_name ~= "" then
    return string.format("`%s(%s)`", prefab_text, display_name)
  end
  return string.format("`%s`", prefab_text)
end

local function format_recipe(entry)
  if type(entry.recipe) ~= "table" or type(entry.recipe[1]) ~= "table" then
    return ""
  end

  local formatted = {}
  for _, ingredient in ipairs(entry.recipe[1]) do
    local prefab = ingredient and ingredient.prefab
    if prefab and not is_sanity_prefab(prefab) then
      formatted[#formatted + 1] = format_ref(prefab)
    end
  end

  return table.concat(formatted, ", ")
end

local function format_drop(entry)
  if type(entry.drop) ~= "table" then
    return ""
  end

  local ordered = {}
  local exists = {}
  for _, drop_item in ipairs(entry.drop) do
    local prefab = drop_item and drop_item.prefab
    if prefab then
      local prefab_text = tostring(prefab)
      if not exists[prefab_text] then
        exists[prefab_text] = true
        ordered[#ordered + 1] = string.format("`%s`", prefab_text)
      end
    end
  end

  return table.concat(ordered, ", ")
end

local lines = {
  "# 材料增强表（自动生成）",
  "",
  "> 该文件由 `tools/generate_ark_item_table.lua` 自动生成，请勿手改。",
  ">",
  "> 生成命令：`lua tools/generate_ark_item_table.lua`",
  "",
  "| <div style=\"width:40px\">图片</div> | <div style=\"width:100px\">名称</div> | 代码 | 掉落自 | 合成自 |",
  "| --- | --- | --- | --- | --- |"
}

for _, entry in ipairs(declared_items) do
  local prefab = tostring(entry.prefab)
  local item_name = names[prefab] or prefab
  local image = string.format("![%s](../imageSource/images/ark_item/%s.png)", item_name, prefab)
  local code = string.format("`%s`", prefab)
  local drop = format_drop(entry)
  local recipe = format_recipe(entry)

  lines[#lines + 1] = string.format("| %s | %s | %s | %s | %s |", image, item_name, code, drop, recipe)
end

lines[#lines + 1] = ""

write_all(output_path, table.concat(lines, "\n"))
print("已生成: " .. output_path)
