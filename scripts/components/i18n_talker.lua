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


function Talker:Play(string_path, params)
  if not string_path then return end
  params = params or {}
  params.sgparam = params.sgparam or {}
  local sound_data = nil
  -- 1. 优先查 SetupVoice 设置的 key
  if self._voice_key and GLOBAL_SOUND_MAP[self._voice_key] then
    local lang_map = GLOBAL_SOUND_MAP[self._voice_key][self.voice_lang]
    if lang_map and lang_map[string_path] then
      sound_data = lang_map[string_path]
    end
    -- 若当前语言找不到，尝试该key下的第一个语言
    if not sound_data then
      local first_lang = next(GLOBAL_SOUND_MAP[self._voice_key])
      if first_lang then
        local first_lang_map = GLOBAL_SOUND_MAP[self._voice_key][first_lang]
        if first_lang_map and first_lang_map[string_path] then
          sound_data = first_lang_map[string_path]
        end
      end
    end
  end
  -- 2. 若没找到，扩散查找全局表第一个可用key
  if not sound_data then
    for key, lang_tbl in pairs(GLOBAL_SOUND_MAP) do
      local lang_map = lang_tbl[self.voice_lang]
      if lang_map and lang_map[string_path] then
        sound_data = lang_map[string_path]
        break
      end
      -- 查第一个语言
      local first_lang = next(lang_tbl)
      if not sound_data and first_lang then
        local first_lang_map = lang_tbl[first_lang]
        if first_lang_map and first_lang_map[string_path] then
          sound_data = first_lang_map[string_path]
          break
        end
      end
    end
  end
  if not sound_data then
    ArkLogger:Warn("Talker:Play sound_key not found", string_path)
  elseif self.inst.SoundEmitter then
    if not params.overlap then
      self.inst.SoundEmitter:KillSound(string_path)
    end
    self.inst.SoundEmitter:PlaySound(sound_data.path, string_path)
    params.sgparam.played_by_i18n_talker = true
  end
  ArkLogger:Debug("Talker: notext", string_path, params.notext)
  if not params.notext then
    local text = self.text_cache_map[string_path]
    if not text then
      text = ResolveText(self.inst, string_path)
      self.text_cache_map[string_path] = text
    end
    if text and self.inst.components.talker then
      local time = params.time or (sound_data and sound_data.duration)
      self.inst.components.talker:Say(text, time, params.noanim, params.force, params.nobroadcast, params.colour, params.text_filter_context, params.original_author_netid, params.onfinishedlinesfn, params.sgparam)
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
