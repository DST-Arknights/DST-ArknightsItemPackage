local SourceModifierList = require("util/sourcemodifierlist")

AddComponentPostInit("health", function(self)
    local function modified_callback()
        self:ForceUpdateHUD(true)
    end
    InstallClassPropertyModifier(self, 'maxhealth', {
        modifier_name = "maxhealthaddmodifiers",
        default_value = 0,
        combine_fun = SourceModifierList.additive,
        modified_callback = modified_callback,
    })
    InstallClassPropertyModifier(self, 'maxhealth', {
        modifier_name = "maxhealthmultmodifiers",
        default_value = 1,
        combine_fun = SourceModifierList.multiply,
        modified_callback = modified_callback,
    })
    InstallClassPropertyModifier(self, 'minhealth', {
        modifier_name = "minhealthmodifiers",
        default_value = 0,
        combine_fun = math.max,
    })
end)
