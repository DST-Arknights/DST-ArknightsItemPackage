--[[
  {
    "zh": {
      "STRINGS.CHARACTERS.WILSON.SPECIAL1": {
        voice_path = "vo/wilson/special1",
        voice_duration = 2,
      }
    },
  }
]]

local Talker = Class(function(self, inst)
  self.inst = inst
  self.sound_map = {}
  self.text_cache_map = {}
end)

function Talker:Play(string_path, params)
  local sound_data = self.sound_map[string_path]
  if not sound_data then
    ArkLogger:Warn("Talker:Play sound_key not found", string_path)
  elseif self.inst.SoundEmitter then
    self.inst.SoundEmitter:PlaySound(sound_data.voice_path) 
  end
  local text = self.text_cache_map[string_path]
  if not text then
    text = table.getfield(string_path)
    self.text_cache_map[string_path] = text
  end
  if text and self.inst.components.talker then
    local time = params.time or sound_data.voice_duration
    self.inst.components.talker:Say(text, time, params.noanim, params.force, params.nobroadcast, params.colour, params.text_filter_context, params.original_author_netid, params.onfinishedlinesfn, params.sgparam)
  end
end

function Talker:SetVoice(sound_map)
  self.sound_map = sound_map
  self.text_cache_map = {}
end

return Talker