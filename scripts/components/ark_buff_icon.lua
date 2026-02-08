local function ontotalTime(self, value)
  self.inst.replica.ark_buff_icon.state.totalTime = value
end
local function onremainingTime(self, value)
  self.inst.replica.ark_buff_icon.state.remainingTime = value
end
local function onatlas(self, value)
  self.inst.replica.ark_buff_icon.state.atlas = value
end
local function ontex(self, value)
  self.inst.replica.ark_buff_icon.state.tex = value
end
local ArkBuffIcon = Class(function(self, inst)
  self.inst = inst
  self.totalTime = 0
  self.remainingTime = 0
  self.atlas = ''
  self.tex = ''
end, nil, {
  totalTime = ontotalTime,
  remainingTime = onremainingTime,
  atlas = onatlas,
  tex = ontex,
})

function ArkBuffIcon:SetTexture(atlas, tex)
  self.atlas = atlas
  self.tex = tex
end

function ArkBuffIcon:SetTotalTime(totalTime)
  self.totalTime = totalTime
end

function ArkBuffIcon:SetRemainingTime(remainingTime)
  self.remainingTime = remainingTime
end

function ArkBuffIcon:AttachTo(target)
  self.inst.replica.ark_buff_icon.state:Attach(target)
end

return ArkBuffIcon
