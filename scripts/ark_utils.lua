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

local function printTable(t, maxDepth, indent)
  indent = indent or 0
  maxDepth = maxDepth or 2
  local indentStr = string.rep("  ", indent)

  if indent > maxDepth then
    print(indentStr .. "...")
    return
  end

  for k, v in pairs(t) do
    if type(v) == "table" then
      print(indentStr .. tostring(k) .. ":")
      printTable(v, maxDepth, indent + 1)
    else
      print(indentStr .. tostring(k) .. ": " .. tostring(v))
    end
  end
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

return {
  get = get,
  printTable = printTable,
  shuffleArray = shuffleArray,
  truncateArray = truncateArray,
  concatArray = concatArray,
  uniqueArray = uniqueArray,
  mergeTable = mergeTable,
}
