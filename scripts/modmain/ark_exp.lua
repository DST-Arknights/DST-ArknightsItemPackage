
-- 添加经验系统的RPC处理
AddModRPCHandler("arkExp", "RequestSyncExpStatus", function(player)
  if player and player.components.ark_exp then
    player.components.ark_exp:RequestSyncExpStatus()
  end
end)

AddClientModRPCHandler("arkExp", "SyncExpStatus", function(...)
  if not ThePlayer then return end
  local arkExpUi = ThePlayer.HUD.controls.arkExpUi
  if not arkExpUi then return end
  arkExpUi:SetData(...)
end)

AddClientModRPCHandler("arkExp", "SetupArkExpUi", function()
  if not ThePlayer.HUD or ThePlayer.HUD.controls.arkExpUi then return end
  local controls = ThePlayer.HUD.controls
  local ArkExpUi = require "widgets/ark_exp_ui"
  controls.arkExpUi = controls.inv.hand_inv:AddChild(ArkExpUi(ThePlayer))
  controls.arkExpUi:SetPosition(0, 80, 0)  -- 放在技能UI下方
end)

-- 设置角色经验配置的全局函数
function GLOBAL.SetupArkCharacterExpConfig(prefab, config)
  TUNING.ARK_EXP_CONFIG = TUNING.ARK_EXP_CONFIG or {}
  TUNING.ARK_EXP_CONFIG[prefab] = config
end