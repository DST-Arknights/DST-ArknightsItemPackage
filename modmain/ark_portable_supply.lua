AddRecipe2("ark_portable_supply", {
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
}, { "ARK_TECHNOLOGY" })

local DEFAULT_RECHARGE_KEY = "default_skill_charge"

local function RechargeSkills(inst, charger, availableCharge)
  if availableCharge < 1 then
    return 0
  end
  local arkSkill = inst.components.ark_skill
  if arkSkill == nil then
    return 0
  end

  local changed = false
  for _, skill in pairs(arkSkill:GetAllSkills()) do
    local lvl = skill:GetLevelConfig()
    if lvl ~= nil and skill.data.activationStacks < lvl.maxActivationStacks then
      local beforeProgress = skill.data.energyProgress
      local beforeStacks = skill.data.activationStacks
      skill:AddEnergyProgress(1)
      if skill.data.energyProgress ~= beforeProgress or skill.data.activationStacks ~= beforeStacks then
        changed = true
      end
    end
  end
  return changed and 1 or 0
end

AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim then
    if not inst.components.ark_supply_rechargeable then
      inst:AddComponent("ark_supply_rechargeable")
    end

    local rechargeable = inst.components.ark_supply_rechargeable
    if rechargeable.rechargehandlers[DEFAULT_RECHARGE_KEY] ~= nil then
      return
    end

    rechargeable:AddRechargeHandler(DEFAULT_RECHARGE_KEY, RechargeSkills)
  end
end)
