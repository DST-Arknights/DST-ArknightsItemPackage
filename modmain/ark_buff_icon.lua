AddPlayerPostInit(function(inst)
  function inst:GetArkBuffIcons()
    local debuffable = self.components.debuffable
    if debuffable then
      local buffs = debuffable.debuffs
      local buffList = {}
      for name, buff in pairs(buffs) do
        if buff.components.ark_buff_icon then
          table.insert(buffList, buff)
        end
      end
      return buffList
    end
    return {}
  end
end)

-- 注册rpc, 用于在ui初始化的时候向服务器请求一次buff
AddModRPCHandler("arkBuffIcon", "RequestBuffIcons", function(player)
  if not player then
    return
  end
  local buffList = player:GetArkBuffIcons()
  if next(buffList) then
    SendModRPCToClient(GetClientModRPC("arkBuffIcon", "SyncBuffIcons"), player.userid, unpack(buffList))
    return
  end
end)

AddClientModRPCHandler("arkBuffIcon", "SyncBuffIcons", function(...)
  if not ThePlayer or not ThePlayer.HUD or not ThePlayer.HUD.controls or not ThePlayer.HUD.controls.arkExtendUi or not ThePlayer.HUD.controls.arkExtendUi.buffIcons then
    return
  end
  for _, buff in ipairs({...}) do
    ThePlayer.HUD.controls.arkExtendUi.buffIcons:AddBuff(buff)
  end
end)