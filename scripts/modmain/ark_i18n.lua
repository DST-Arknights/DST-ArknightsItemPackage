local utils = require('ark_utils')

function GLOBAL.MergePOFile(fname, langCode, default)
  local localeCode = LOC.GetLocaleCode();
  if langCode ~= localeCode and not default then
    return
  end
  if IsXB1() then
    -- 检查是不是 data/开头的,如果是就不额外处理了
    if string.sub(fname, 1, 5) ~= 'data/' then
      -- 如果不是,就加上 data/
      fname = 'data/' .. fname
    end
  end
  local loadedLanguages = LanguageTranslator.languages[langCode]
  LanguageTranslator:LoadPOFile(fname, langCode)
  local newLoadedLanguages = LanguageTranslator.languages[langCode]
  utils.mergeTable(loadedLanguages, newLoadedLanguages)
  LanguageTranslator.languages[langCode] = loadedLanguages
  -- Recursively merge translation keys into STRINGS
  for key, value in pairs(newLoadedLanguages) do
    if type(key) == "string" and string.sub(key, 1, 8) == "STRINGS." then
      local path = string.sub(key, 9) -- Remove "STRINGS." prefix
      local parts = {}
      for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
      end

      local current = GLOBAL.STRINGS
      for i = 1, #parts - 1 do
        if current[parts[i]] == nil then
          current[parts[i]] = {}
        elseif type(current[parts[i]]) ~= "table" then
          current[parts[i]] = {}
        end
        current = current[parts[i]]
      end
      
      if #parts > 0 then
        current[parts[#parts]] = value
      end
    end
  end
end