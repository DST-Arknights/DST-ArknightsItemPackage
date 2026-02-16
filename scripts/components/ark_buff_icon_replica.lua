local SafeCallBuffIconsUI = GenSafeCall(function (inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi and inst.HUD.controls.arkExtendUi.buffIcons or nil
end)
local ArkBuffIconReplica = Class(function(self, inst)
  self.inst = inst
  self.state = NetState(inst, "ark_buff_icon")
  self.state:OnAttached(function()
    SafeCallBuffIconsUI(ThePlayer):AddBuff(self.inst)
  end)
  self.state:OnDetached(function()
    SafeCallBuffIconsUI(ThePlayer):RemoveBuff(self.inst)
  end)
  self.state:Watch({ "remainingTime", "totalTime", "atlas", "tex", "title", "desc" }, function()
    -- 当服务端同步buff状态时，重新初始化客户端倒计时基准
    SafeCallBuffIconsUI(ThePlayer):UpdateBuff(self.inst)
  end)
end)
return ArkBuffIconReplica