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

local Talker = Class(function(self, inst)
  self.inst = inst
  self.sound_map = {}
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
  if not string_path then
    return
  end
  params = params or {}
  local sound_data = table.getfield(self.sound_map, self.voice_lang .. '.' .. string_path)
  -- 没获取到就取第一个语言的
  if not sound_data then
    sound_data = table.getfield(self.sound_map, next(self.sound_map) .. '.' .. string_path)
  end
  if not sound_data then
    ArkLogger:Warn("Talker:Play sound_key not found", string_path)
  elseif self.inst.SoundEmitter then
    self.inst.SoundEmitter:PlaySound(sound_data.path) 
  end
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

function Talker:RegisterVoice(sound_map)
  self.sound_map = sound_map
  self.text_cache_map = {}
end

function Talker:SetVoiceLang(lang)
  self.voice_lang = lang
end

return Talker