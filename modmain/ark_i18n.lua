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
        table.insert(parts, tonumber(part) or part)
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

function GLOBAL.SayAndVoice(inst, key, params)
  if not params then
    params = {}
  end
  if not inst.components.i18n_talker then
    inst:AddComponent("i18n_talker")
  end
  inst.components.i18n_talker:Play(key, params)
  -- if inst.components.i18n_talker then
  --   inst.components.i18n_talker:Play(key, params)
  -- elseif inst.components.talker then
  --   local text = GetString(inst, key)
  --   if not text then
  --     text = table.getfield(key)
  --   end
  --   inst.components.talker:Say(text, params.time, params.noanim, params.force, params.nobroadcast, params.colour, params.text_filter_context, params.original_author_netid, params.onfinishedlinesfn, params.sgparam)
  -- end
end

TUNING.GLOBAL_SOUND_MAP = {}
function GLOBAL.RegisterVoice(key, lang)
  TUNING.GLOBAL_SOUND_MAP[key] = lang
end

AddStategraphPostInit("wilson", function(sg)
  local Old = sg.events.ontalk.fn
  sg.events.ontalk.fn = function(inst, data)
    if data and data.sgparam and data.sgparam.played_by_i18n_talker then
      return
    end
    return Old(inst, data)
  end
end)
