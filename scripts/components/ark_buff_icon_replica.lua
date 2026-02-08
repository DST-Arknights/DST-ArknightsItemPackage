local SafeCallBuffIconsUI = GenSafeCall(function (inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi and inst.HUD.controls.arkExtendUi.buffIcons or nil
end)
local ArkBuffIconReplica = Class(function(self, inst)
  self.inst = inst
  self.state = NetState(inst, "ark_buff_icon")
  self.state:OnAttached(function()
    ArkLogger:Debug('ark_buff_icon_replica OnAttached')
    SafeCallBuffIconsUI(ThePlayer):AddBuff(self.inst)
  end)
  self.state:OnDetached(function()
    ArkLogger:Debug('ark_buff_icon_replica OnDetached')
    SafeCallBuffIconsUI(ThePlayer):RemoveBuff(self.inst)
  end)
  self.state:Watch({ "remainingTime", "totalTime", "atlas", "tex" }, function()
    ArkLogger:Debug('ark_buff_icon_replica Watch OnDirty', self.state.remainingTime, self.state.totalTime, self.state.atlas, self.state.tex)
    -- 当服务端同步buff状态时，重新初始化客户端倒计时基准
    SafeCallBuffIconsUI(ThePlayer):UpdateBuff(self.inst)
  end)
end)
return ArkBuffIconReplica