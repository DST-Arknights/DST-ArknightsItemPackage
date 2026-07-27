function GLOBAL.MergePOFile(fname, langCode)
  if IsXB1() then
    if string.sub(fname, 1, 5) ~= 'data/' then
      fname = 'data/' .. fname
    end
  end
  local isCurrentLocale = (langCode == LOC.GetLocaleCode())
  LanguageTranslator:LoadPOFile(fname, langCode)
  local strings = LanguageTranslator.languages[langCode]
  for key, value in pairs(strings) do
    if type(key) == "string" and string.sub(key, 1, 8) == "STRINGS." then
      local path = string.sub(key, 9)
      local parts = {}
      for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, tonumber(part) or part)
      end
      local current = GLOBAL.STRINGS
      for i = 1, #parts - 1 do
        if current[parts[i]] == nil or type(current[parts[i]]) ~= "table" then
          current[parts[i]] = {}
        end
        current = current[parts[i]]
      end
      if #parts > 0 then
        local lastKey = parts[#parts]
        if isCurrentLocale then
          current[lastKey] = value
        elseif current[lastKey] == nil then
          current[lastKey] = value
        end
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
