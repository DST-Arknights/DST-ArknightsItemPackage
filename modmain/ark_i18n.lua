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

--------------------------------------------------------
-- 配音系统
-- RegisterVoice 注册档案 (key 为中心的语音表 + 默认变体/音量)
-- BindVoice 把实体绑定到档案 (全局弱表, 无组件)
-- SayAndVoice 单函数: 文字气泡 (talker:Say) + 语音 (SoundEmitter)
--------------------------------------------------------

local VOICE_PROFILES = {}                             -- 档案注册表: key -> { data, voice_lang, volume }
local VOICE_BIND = setmetatable({}, { __mode = "k" }) -- 弱表: inst -> 档案 key, 实体销毁自动释放

--[[
RegisterVoice(key, filepath, opts)

注册一个配音档案。filepath 在调用方 mod 的上下文 require, 数据文件返回 key 为中心的表:
  { [STRINGS_KEY] = { [voice_lang] = { path=..., duration=..., name=?... }, ... }, ... }

@param key      string  档案名 (BindVoice 用)
@param filepath string  语音数据文件路径, 相对调用方 mod 的 scripts/ (例: "languages/ling_voice")
@param opts     table   可选
  voice_lang  string  默认配音变体; 缺省取数据文件里第一个变体
  volume      number  默认音量
]]
function GLOBAL.RegisterVoice(key, filepath, opts)
  opts = opts or {}
  local data = require(resolvefilepath(filepath))
  local voice_lang = opts.voice_lang
  if voice_lang == nil then
    local _, entry = next(data)
    voice_lang = entry and next(entry) or nil -- 缺省: 数据里第一个变体
  end
  VOICE_PROFILES[key] = {
    data = data,
    voice_lang = voice_lang,
    volume = opts.volume,
  }
end

--[[
BindVoice(inst, key)

把实体的说话绑定到已注册的配音档案。无组件、无状态外露, 全局弱表, 实体销毁自动释放。

@param inst  entity
@param key   string  RegisterVoice 注册的档案名
]]
function GLOBAL.BindVoice(inst, key)
  VOICE_BIND[inst] = key
end

--[[
SayAndVoice(inst, key, opts)

单函数播放: 一条 key 同时走文字 (talker:Say) 与语音 (SoundEmitter)。
key 同时是 STRINGS 文案键与语音表键, 文案走原版 GetString (角色专属/通用台词)。

语音查找无回退: 只查绑定档案里当前 voice_lang 的直接命中, 有就是有, 没有就是没有。

@param inst  entity   说话的实体
@param key   string   STRINGS 键 / 语音表键
@param opts  table    可选, 全部平铺:
  text      true  出文字气泡; false = 只语音
  voice     true  播语音;     false = 只文字
  time      nil   气泡时长; 缺省跟随语音表的 duration
  volume    nil   音量; 缺省用 RegisterVoice 的默认
  noanim / force / nobroadcast / colour   透传 talker:Say
  sgparam   nil   附加给 ontalk 事件的数据; 播了语音时内部并入 skip_default_talk
]]
function GLOBAL.SayAndVoice(inst, key, opts)
  if inst == nil or key == nil then return end
  opts = opts or {}
  local sgparam = opts.sgparam or {}
  local time = opts.time

  if opts.voice ~= false then
    local profile_key = VOICE_BIND[inst]
    local profile = profile_key and VOICE_PROFILES[profile_key]
    local entry = profile and profile.data[key]
    local voice = entry and entry[profile.voice_lang]
    if voice and voice.path and inst.SoundEmitter then
      local volume = opts.volume ~= nil and opts.volume or profile.volume
      inst.SoundEmitter:PlaySound(voice.path, voice.name or key, volume)
      sgparam.skip_default_talk = true -- 有语音 → 拦截默认说话动画
      time = time or voice.duration
    end
  end

  if opts.text ~= false then
    local text = GetString(inst, key, nil, true)
    if text and inst.components.talker then
      inst.components.talker:Say(text, time, opts.noanim, opts.force, opts.nobroadcast, opts.colour, nil, nil, nil, sgparam)
    end
  end
end

-- 有语音的台词说话时, 跳过 stategraph 的默认说话反应 (DoTalkSound / acting_talk)
-- 见 SayAndVoice 写入的 sgparam.skip_default_talk
AddStategraphPostInit("wilson", function(sg)
  local Old = sg.events.ontalk.fn
  sg.events.ontalk.fn = function(inst, data)
    if data and data.sgparam and data.sgparam.skip_default_talk then
      return
    end
    return Old(inst, data)
  end
end)
