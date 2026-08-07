local STRINGS_PREFIX = "STRINGS."

--[[
RegisterPOFile(lang, files)

注册一组 PO 翻译文件, 只加载 lang 对应的一份, 其余不加载、不写 STRINGS。
消费端是 STRINGS.X.Y 直引用 (GetString 也走 STRINGS.CHARACTERS), 因此加载后同步写回 GLOBAL.STRINGS。

@param lang   string|nil  语言代码; nil / "auto" 视为自动识别 (LOC.GetLocaleCode())
                          指定语言在 files 中不存在时, 自动回退加载 en
@param files  table       语言代码 -> po 文件路径。key 与 LOC.GetLocaleCode() 返回的 code 对齐
                          { zh = "languages/x.po", en = "languages/x_en.po", ... }
@return       string|nil  实际加载的语言 code; 无任何可用文件时返回 nil
]]
function GLOBAL.RegisterPOFile(lang, files)
  -- 解析语言: nil / "auto" 跟随游戏当前语言
  if lang == nil or lang == "auto" then
    lang = LOC.GetLocaleCode()
  end

  -- 找不到指定语言则回退英文; 连英文也没有则放弃
  local fname = files and files[lang]
  if fname == nil and lang ~= "en" then
    fname = files and files["en"]
    if fname ~= nil then
      lang = "en"
    end
  end

  if fname == nil then
    return nil
  end

  if IsXB1() and string.sub(fname, 1, 5) ~= 'data/' then
    fname = 'data/' .. fname
  end

  LanguageTranslator:LoadPOFile(fname, lang)

  local strings = LanguageTranslator.languages[lang]
  if strings == nil then
    return nil
  end

  local current = GLOBAL.STRINGS
  for key, value in pairs(strings) do
    if type(key) == "string" and string.sub(key, 1, #STRINGS_PREFIX) == STRINGS_PREFIX then
      local path = string.sub(key, #STRINGS_PREFIX + 1)
      local parts = {}
      for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, tonumber(part) or part) -- 保留原版兼容: 全数字段转数字下标
      end
      local node = current
      for i = 1, #parts - 1 do
        local k = parts[i]
        if node[k] == nil or type(node[k]) ~= "table" then
          node[k] = {}
        end
        node = node[k]
      end
      node[parts[#parts]] = value
    end
  end

  return lang
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
