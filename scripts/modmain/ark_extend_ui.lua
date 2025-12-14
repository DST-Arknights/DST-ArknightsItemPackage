local ArkExtendUi = require "widgets/ark_extend_ui"
AddClassPostConstruct("screens/playerhud", function(self)
  local _SetMainCharacter = self.SetMainCharacter
  function self:SetMainCharacter(maincharacter)
    _SetMainCharacter(self, maincharacter)
    maincharacter.HUD.controls.arkExtendUi = maincharacter.HUD.controls:AddChild(ArkExtendUi(self.owner))
    maincharacter.HUD.controls.arkExtendUi:MoveToBack()
  end
end)
AddClassPostConstruct("widgets/inventorybar", function(self)
    local _Rebuild = self.Rebuild
    function self:Rebuild(...)
        _Rebuild(self, ...)
        if self.owner.HUD.controls.arkExtendUi then
            self.owner.HUD.controls.arkExtendUi:UpdateLayout()
        end
    end
end)