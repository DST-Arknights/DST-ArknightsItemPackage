local UIArkCurrency = require("widgets/ui_ark_currency")

AddClassPostConstruct("widgets/statusdisplays", function(self)
    self.arkCurrency = self:AddChild(UIArkCurrency(self.owner))
    self.owner.arkCurrency = self.arkCurrency
    self.arkCurrency:SetPosition(-100, 0, 0)
    SendModRPCToServer(GetModRPC("ark_item", "ark_currency_sync"))
end)