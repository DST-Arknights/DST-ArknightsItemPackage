-- 根据路径获取table中的值
local function get(source, path)
  string.gsub(path, '[^.]+', function(w)
    if source == nil then
      return nil
    end
    source = source[w]
  end)
  return source
end


local function shuffleArray(array)
  local n = #array
  for i = n, 2, -1 do
    local j = math.random(i)
    array[i], array[j] = array[j], array[i]
  end
end

local function truncateArray(arr, length)
  if #arr > length then
    for i = #arr, length + 1, -1 do
      table.remove(arr, i)
    end
  end
end

local function concatArray(arr1, arr2)
  local newArr = {}
  for i, v in ipairs(arr1) do
    table.insert(newArr, v)
  end
  for i, v in ipairs(arr2) do
    table.insert(newArr, v)
  end
  return newArr
end

-- 数组去重
local function uniqueArray(arr)
  local hash = {}
  local res = {}
  for _, v in ipairs(arr) do
    if not hash[v] then
      res[#res + 1] = v
      hash[v] = true
    end
  end
  return res
end

local function mergeTable(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == 'table' then
      if not t1[k] then
        t1[k] = {}
      end
      mergeTable(t1[k], v)
    else
      t1[k] = v
    end
  end
  return t1
end

local function cloneTable(t)
  local newTable = {}
  for k, v in pairs(t) do
    if type(v) == 'table' then
      newTable[k] = cloneTable(v)
    else
      newTable[k] = v
    end
  end
  return newTable
end

local function findIndex(arr, value)
  for i, v in ipairs(arr) do
    if v == value then
      return i
    end
  end
  return nil
end

-- 将字符串按指定长度拆分成字符串数组
local function splitStringByLength(str, length)
  local result = {}
  local currentLength = 0
  local currentString = ""
  local i = 1

  while i <= #str do
    local char = str:sub(i, i)
    local byte = string.byte(char)
    local charLength = 1

    if byte >= 0 and byte <= 127 then
      currentLength = currentLength + 1
    elseif byte >= 192 and byte <= 223 then
      charLength = 2
      currentLength = currentLength + 2
    elseif byte >= 224 and byte <= 239 then
      charLength = 3
      currentLength = currentLength + 2
    elseif byte >= 240 and byte <= 247 then
      charLength = 4
      currentLength = currentLength + 2
    end

    currentString = currentString .. str:sub(i, i + charLength - 1)
    i = i + charLength

    if currentLength >= length then
      table.insert(result, currentString)
      currentString = ""
      currentLength = 0
    end
  end

  if currentString ~= "" then
    table.insert(result, currentString)
  end

  return result
end

return {
  get = get,
  shuffleArray = shuffleArray,
  truncateArray = truncateArray,
  concatArray = concatArray,
  uniqueArray = uniqueArray,
  mergeTable = mergeTable,
  cloneTable = cloneTable,
  findIndex = findIndex,
  splitStringByLength = splitStringByLength,
}
