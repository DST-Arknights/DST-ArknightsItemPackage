AddCharacterRecipe("ark_portable_supply", {
  Ingredient("gears", 20),
  Ingredient("trinket_6", 10),
  Ingredient("torch", 1),
  Ingredient("transistor", 5),
}, TECH.SCIENCE_TWO, {
  atlas = "images/inventoryimages/ark_portable_supply.xml",
  image = "ark_portable_supply.tex",
  actionstr = "DEPLOY",
  force_hint = true,
  builder_tag = "ark_character",
}, { "MODS", "STRUCTURES" })

local DEFAULT_RECHARGE_GROUP = "default_skill_charge"

AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim then
    if not inst.components.ark_supply_rechargeable then
      inst:AddComponent("ark_supply_rechargeable")
    end

    inst.components.ark_supply_rechargeable:AddRechargeGroup(DEFAULT_RECHARGE_GROUP, {
      getrechargeamountfn = function(target, charger, data)
      local arkSkill = target.components.ark_skill
      if arkSkill == nil then
        return 0
      end

      for _, skill in pairs(arkSkill:GetAllSkills()) do
        local lvl = skill:GetLevelConfig()
        if lvl ~= nil and skill.data.activationStacks < lvl.maxActivationStacks then
          return 1
        end
      end

      return 0
      end,

      rechargefn = function(target, charger, amount, data)
      if amount < 1 then
        return 0
      end

      local arkSkill = target.components.ark_skill
      if arkSkill == nil then
        return 0
      end

      local changed = false
      for _, skill in pairs(arkSkill:GetAllSkills()) do
        local lvl = skill:GetLevelConfig()
        if lvl ~= nil and skill.data.activationStacks < lvl.maxActivationStacks then
          skill:AddEnergyProgress(1)
          changed = true
        end
      end

      return changed and 1 or 0
      end,
    })
  end
end)
