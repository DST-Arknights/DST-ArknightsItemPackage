AddComponentPostInit("builder", function(self)
    InstallClassPropertyModifier(self, 'ingredientmod', {
        modifier_name = "ingredientmodminmodifiers",
        default_value = 0,
        combine_fun = math.min,
    })
end)
