--[[
  {
    zh = {
      ["STRINGS.CHARACTERS.WILSON.SPECIAL1"] = {
        path = "vo/wilson/special1",
        duration = 2,
      },
    },
  }

  当前组件文本解析顺序:
  1) GetString(self.inst, key)
  2) table.getfield(key)
]]
-- 全局 voice 数据注册表
local GLOBAL_SOUND_MAP = TUNING.GLOBAL_SOUND_MAP or {}

local Talker = Class(function(self, inst)
  self.inst = inst
  self._voice_key = nil -- 当前实例选用的 voice key
  self.text_cache_map = {}
  self.voice_lang = 'zh'
end)

local function ResolveText(inst, string_path)
  local text = GetString(inst, string_path)
  if text then
    return text
  end
  return table.getfield(string_path)
end


-- 在全局语音表中按 key 查找 string_path
-- 优先当前语言，回退到该 key 下的第一个语言
local function TryResolveVoiceFromKey(key, string_path, voice_lang)
  local lang_tbl = GLOBAL_SOUND_MAP[key]
  if not lang_tbl then return nil end
  local lang_map = lang_tbl[voice_lang]
  if lang_map and lang_map[string_path] then
    return lang_map[string_path]
  end
  local first_lang = next(lang_tbl)
  if first_lang then
    local first_lang_map = lang_tbl[first_lang]
    if first_lang_map and first_lang_map[string_path] then
      return first_lang_map[string_path]
    end
  end
end

function Talker:ResolveVoiceData(string_path)
  -- 1. 优先查 SetupVoice 设置的 key
  local data = self._voice_key and TryResolveVoiceFromKey(self._voice_key, string_path, self.voice_lang)
  if data then return data end
  -- 2. 扩散查找全局表第一个可用 key
  for key in pairs(GLOBAL_SOUND_MAP) do
    data = TryResolveVoiceFromKey(key, string_path, self.voice_lang)
    if data then return data end
  end
end

function Talker:Play(string_path, params)
  if not string_path then return end
  params = params or {}
  local sound = params.sound ~= false
  local talk = params.talk ~= false
  if not sound and not talk then return end
  local interrupt = params.interrupt ~= false
  local talk_params = params.talker_params or {}
  local sound_params = params.sound_params or {}
  talk_params.sgparam = talk_params.sgparam or {}
  -- 仅当需要播放声音 或 需要 duration 回退时才查表
  local sound_data = (sound or not talk_params.time) and self:ResolveVoiceData(string_path) or nil
  if sound and sound_data and sound_data.path and self.inst.SoundEmitter then
    local name = sound_data.name or string_path
    if interrupt then
      self.inst.SoundEmitter:KillSound(name)
    end
    self.inst.SoundEmitter:PlaySound(sound_data.path, name, sound_params.volume, sound_params.ispredicted)
    talk_params.sgparam.played_by_i18n_talker = true
  end
  if talk then
    local text = self.text_cache_map[string_path]
    if not text then
      text = ResolveText(self.inst, string_path)
      self.text_cache_map[string_path] = text
    end
    if text and self.inst.components.talker then
      local time = talk_params.time or (sound_data and sound_data.duration)
      self.inst.components.talker:Say(text, time, talk_params.noanim, talk_params.force, talk_params.nobroadcast, talk_params.colour, talk_params.text_filter_context, talk_params.original_author_netid, talk_params.onfinishedlinesfn, talk_params.sgparam)
    end
  end
end
-- 组件方法，设置当前实例使用的 voice key
function Talker:SetupVoice(key)
  self._voice_key = key
  self.text_cache_map = {}
end

function Talker:SetVoiceLang(lang)
  self.voice_lang = lang
end

return Talker
