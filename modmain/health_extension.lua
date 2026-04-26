local SourceModifierList = require("util/sourcemodifierlist")

AddComponentPostInit("health", function(self)
    local function modified_callback()
        self:ForceUpdateHUD(true)
    end
    InstallClassPropertyModifier(self, 'maxhealth', {
        modifier_name = "maxhealthaddmodifiers",
        default_value = 0,
        combine_fun = SourceModifierList.additive,
        calc_fun = function(inst, modifier, value)
            return value + modifier:Get()
        end,
        modified_callback = modified_callback,
    })
    InstallClassPropertyModifier(self, 'maxhealth', {
        modifier_name = "maxhealthmultmodifiers",
        default_value = 1,
        combine_fun = SourceModifierList.multiply,
        calc_fun = function(inst, modifier, value)
            return math.max(1, value * modifier:Get())
        end,
        modified_callback = modified_callback,
    })
    InstallClassPropertyModifier(self, 'minhealth', {
        modifier_name = "minhealthmodifiers",
        default_value = 0,
        combine_fun = function(a, b) return math.max(a, b) end,
        calc_fun = function(inst, modifier, value)
            return math.max(value, modifier:Get())
        end,
    })
end)
