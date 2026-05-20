AddComponentPostInit("builder", function(self)
    InstallClassPropertyModifier(self, 'ingredientmod', {
        modifier_name = "ingredientmodminmodifiers",
        default_value = 1,
        combine_fun = math.min,
    })
end)
