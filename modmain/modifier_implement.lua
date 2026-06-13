local SourceModifierList = require("util/sourcemodifierlist")

AddComponentPostInit("combat", function(self)
  InstallClassPropertyModifier(self, "defaultdamage", {
    modifier_name = "defaultdamageaddmodifiers",
    default_value = 0,
    combine_fun = SourceModifierList.additive,
  })
  InstallClassPropertyModifier(self, "defaultdamage", {
    modifier_name = "defaultdamagemultmodifiers",
    default_value = 1,
    combine_fun = SourceModifierList.multiply,
  })
  InstallClassPropertyModifier(self, "attackrange", {
    modifier_name = "attackrangeaddmodifiers",
    default_value = 0,
    combine_fun = SourceModifierList.additive,
  })
  InstallClassPropertyModifier(self, "hitrange", {
    modifier_name = "hitrangeaddmodifiers",
    default_value = 0,
    combine_fun = SourceModifierList.additive,
  })
end)

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
  ArkHookFunction(self, "OnLoad", function(next, self, data)
    next(self, data)
    self.inst:DoTaskInTime(0, function()
      local haspenalty = data.penalty ~= nil and data.penalty > 0 and data.penalty < 1
      if self.inst.prefab == 'ling' then
        ArkLogger:Debug("Health OnLoad", "health", data.health)
      end
      if data.health ~= nil then
          self:SetVal(data.health, "file_load")
          self:ForceUpdateHUD(true)
      elseif data.percent ~= nil then
          -- used for setpieces!
          -- SetPercent already calls ForceUpdateHUD
          self:SetPercent(data.percent, true, "file_load")
      elseif haspenalty then
          self:ForceUpdateHUD(true)
      end
    end)
  end)
end)

AddComponentPostInit("builder", function(self)
  InstallClassPropertyModifier(self, 'ingredientmod', {
    modifier_name = "ingredientmodminmodifiers",
    default_value = 1,
    combine_fun = math.min,
  })
end)

AddComponentPostInit("hunger", function(self)
  InstallClassPropertyModifier(self, 'max', {
    modifier_name = "maxhungeraddmodifiers",
    default_value = 0,
    combine_fun = SourceModifierList.additive,
  })
end)

AddComponentPostInit("sanity", function(self)
  InstallClassPropertyModifier(self, 'max', {
    modifier_name = "maxsanityaddmodifiers",
    default_value = 0,
    combine_fun = SourceModifierList.additive,
  })
end)