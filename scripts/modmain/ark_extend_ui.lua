local ArkExtendUi = require "widgets/ark_extend_ui"

AddClassPostConstruct("widgets/controls", function(self)
  self.arkExtendUi = self:AddChild(ArkExtendUi(self.owner, self))
  self.arkExtendUi:MoveToBack()

  local _ShowCraftingAndInventory = self.ShowCraftingAndInventory
  function self:ShowCraftingAndInventory()
    _ShowCraftingAndInventory(self)
    self.arkExtendUi:Show()
  end

  local _HideCraftingAndInventory = self.HideCraftingAndInventory
  function self:HideCraftingAndInventory()
    _HideCraftingAndInventory(self)
    self.arkExtendUi:Hide()
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