local function ontotalTime(self, value)
  self.inst.replica.ark_buff_icon.state.totalTime = value
end
local function onremainingTime(self, value)
  local same_value = self.remainingTime == value
  self.inst.replica.ark_buff_icon.state.remainingTime = value
  if same_value then
    -- 同值刷新不会触发 netvar dirty，手动强制同步一次。
    self.inst.replica.ark_buff_icon.state:ForceSync()
  end
end
local function onatlas(self, value)
  self.inst.replica.ark_buff_icon.state.atlas = value
end
local function ontex(self, value)
  self.inst.replica.ark_buff_icon.state.tex = value
end
local function ontitle(self, value)
  self.inst.replica.ark_buff_icon.state.title = value
end
local function ondesc(self, value)
  self.inst.replica.ark_buff_icon.state.desc = value
end

local ArkBuffIcon = Class(function(self, inst)
  self.inst = inst
  self.totalTime = 0
  self.remainingTime = 0
  self.atlas = ''
  self.tex = ''
  self.title = ''
  self.desc = ''
end, nil, {
  totalTime = ontotalTime,
  remainingTime = onremainingTime,
  atlas = onatlas,
  tex = ontex,
  title = ontitle,
  desc = ondesc,
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

function ArkBuffIcon:SetTitle(title)
  self.title = title
end

function ArkBuffIcon:SetDesc(desc)
  self.desc = desc
end

function ArkBuffIcon:AttachTo(target)
  self.inst.replica.ark_buff_icon.state:Attach(target)
end

return ArkBuffIcon
