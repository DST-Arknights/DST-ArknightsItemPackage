local CONSTANTS = require "ark_constants"
local common = require "ark_common"

-- 手动激活技能 RPC 处理
AddModRPCHandler("arkSkill", "ManualActivateSkill", function(player, id, target, targetPos, force)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(id)
  if not skill then return end
  local config = skill:GetConfig()
  if config.activationMode ~= CONSTANTS.ACTIVATION_MODE.MANUAL then
    return
  end
  local deserializedPos = string.split(targetPos, ",")
  targetPos = Vector3(tonumber(deserializedPos[1]), tonumber(deserializedPos[2]), tonumber(deserializedPos[3]))
  skill:TryActivate(
    {
      target = target,
      targetPos = targetPos,
      force = force
    }
  )
end)

-- 手动取消技能 RPC 处理
AddModRPCHandler("arkSkill", "ManualCancelSkill", function(player, id)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(id)
  if not skill then return end
  skill:Cancel()
end)

-- 卸载临时技能 RPC 处理
AddModRPCHandler("arkSkill", "UninstallSkill", function(player, id)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(id)
  if skill and skill.data.isTemporary then
    player.components.ark_skill:RemoveSkill(id)
  end
end)

local function defaultLevelConfigs(levelConfigs)
  local copyLevelConfigs = {}
  for _, levelConfig in ipairs(levelConfigs) do
    local copyLevelConfig = {
      activationEnergy = levelConfig.activationEnergy or 1,
      buffDuration = levelConfig.buffDuration or 0.3,
      bulletCount = levelConfig.bulletCount or nil,
      maxActivationStacks = levelConfig.maxActivationStacks or 1,
      desc = levelConfig.desc or '',
      params = levelConfig.params or {},
      recipeIngredients = levelConfig.recipeIngredients or nil,
    }
    table.insert(copyLevelConfigs, copyLevelConfig)
  end
  return copyLevelConfigs
end

local function checkAndDefaultSkill(skill)
  assert(skill, "Skill config is nil.")
  assert(skill.id, "Skill config missing id.")
  if skill.energyRecoveryMode then
    assert(table.contains(CONSTANTS.ENERGY_RECOVERY_MODE, skill.energyRecoveryMode), "Invalid energyRecoveryMode for skill " .. skill.id)
  end
  if skill.activationMode then
    assert(table.contains(CONSTANTS.ACTIVATION_MODE, skill.activationMode), "Invalid activationMode for skill " .. skill.id)
  end
  assert(type(skill.levels) == "table" and #skill.levels > 0, "Skill " .. skill.id .. " must have at least one level config.")
  local copySkill = {
    id = skill.id,
    atlas = skill.atlas or '',
    image = skill.image or '',
    name = skill.name or skill.id,
    recipe_atlas = skill.recipe_atlas,
    recipe_image = skill.recipe_image,
    lockedDesc = skill.lockedDesc or '',
    energyRecoveryMode = skill.energyRecoveryMode or CONSTANTS.ENERGY_RECOVERY_MODE.AUTO,
    activationMode = skill.activationMode or CONSTANTS.ACTIVATION_MODE.MANUAL,
    hotkey = skill.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL and skill.hotkey or nil,
    levels = defaultLevelConfigs(skill.levels)
  }
  -- 透传所有回调字段
  local callbackFields = {
    "ActivateTest",
    "OnActivate", "OnDeactivate", "OnLocked", "OnUnlocked",
    "OnEnergyRecovering", "OnActivateReady", "OnActivateEffect",
    "OnBulletCut", "OnLevelChange",
    "OnInstall", "OnAdd", "OnRemove", "OnStep", "OnSave", "OnLoad",
  }
  for _, field in ipairs(callbackFields) do
    if skill[field] ~= nil then
      copySkill[field] = skill[field]
    end
  end
  return copySkill
end
local arkSkillLevelUpImages = {}
local SkillsSymbol = Symbol("ARK_SKILLS")
TUNING[SkillsSymbol] = {}
function GLOBAL.RegisterArkSkill(skill)
  assert(skill and skill.id, "Invalid skill config, missing id: " .. tostring(skill))
  if TUNING[SkillsSymbol][skill.id] then
    ArkLogger:Warn("Skill with id " .. skill.id .. " already exists, skipping registration.")
    return
  end
  skill = checkAndDefaultSkill(skill)
  TUNING[SkillsSymbol][skill.id] = skill
   -- 替换高清资源
  if not TheNet:IsDedicated() then
    local resolveAtlas = resolvefilepath(skill.atlas)
    if not arkSkillLevelUpImages[resolveAtlas] then
      arkSkillLevelUpImages[resolveAtlas] = {}
    end
    arkSkillLevelUpImages[resolveAtlas][skill.image] = true
  end
  -- 安装配方
  for level, levelConfig in ipairs(skill.levels) do
    local ingredients = levelConfig.recipeIngredients
    if ingredients then
      local previousLevel = level - 1
      local prefabName = common.genArkSkillLevelUpPrefabNameById(skill.id, level)
      local rep = AddCharacterRecipe(prefabName, ingredients, TECH.ARK_TRAINING_ONE, {
        nounlock = true,
        atlas = skill.atlas,
        image = skill.image,
        actionstr = level <= 7 and "ARK_SKILL_UPDATE" or "ARK_SKILL_SPECIALIZATION",
        builder_tag = common.genArkSkillLevelUpPrefabNameById(skill.id, previousLevel),
        manufactured = true,
      }, { "CRAFTING_STATION" })
      -- 机器制造回调
      rep.manufacturedfn = function(inst, doer)
        if doer and doer.components.ark_skill then
          local skill = doer.components.ark_skill:GetSkill(skill.id)
          if skill then
            skill:SetLevel(level)
          end
        end
      end
      local upperName = string.upper(prefabName)
      STRINGS.NAMES[upperName] = skill.name or (STRINGS.UI.ARK_SKILL.SKILL .. " " .. skill.name)
      if skill.desc then
        STRINGS.RECIPE_DESC[upperName] = skill.desc
      else
        local currentLevelStr = STRINGS.UI.ARK_SKILL.LEVEL[previousLevel] or tostring(previousLevel)
        local nextLevelStr = STRINGS.UI.ARK_SKILL.LEVEL[level] or tostring(level)
        local desc = STRINGS.UI.ARK_SKILL.CURRENT_LEVEL .. " " .. " " .. currentLevelStr .. "\n" .. (STRINGS.UI.ARK_SKILL.NEXT_LEVEL .. " " .. nextLevelStr)
        STRINGS.RECIPE_DESC[upperName] = desc
      end
    end
  end
  -- 学习配方（临时安装技能，供其他角色学习使用）
  local DEFAULT_INSTALL_LIMIT_TIME = 3 * 8 * 60
  local installPrefabName = common.genArkSkillInstallPrefabNameById(skill.id)
  local installRep = AddCharacterRecipe(installPrefabName, {
    Ingredient("ark_gold", 180000),
    Ingredient(CHARACTER_INGREDIENT.SANITY, 50),
  }, TECH.ARK_TRAINING_ONE, {
    nounlock = true,
    atlas = skill.recipe_atlas or skill.atlas,
    image = skill.recipe_image or skill.image,
    actionstr = "ARK_SKILL_INSTALL",
    manufactured = true,
  }, { "CRAFTING_STATION" })
  local _skillId = skill.id
  installRep.canbuild = function(recipe, inst, pt, rotation, prototyper, skin)
    if inst and inst.components.ark_skill then
      return inst.components.ark_skill:CanAddSkill(_skillId)
    end
    return false, "ARK_SKILL_CANNOT_LEARN"
  end
  installRep.manufacturedfn = function(inst, doer)
    if doer and doer.components.ark_skill then
      local can = doer.components.ark_skill:CanAddSkill(_skillId)
      if can then
        doer.components.ark_skill:AddSkill(_skillId, DEFAULT_INSTALL_LIMIT_TIME)
        doer.components.ark_skill:GetSkill(_skillId):Unlock()
      end
    end
  end
  local upperInstallName = string.upper(installPrefabName)
  STRINGS.NAMES[upperInstallName] = skill.name
  STRINGS.RECIPE_DESC[upperInstallName] = STRINGS.UI.ARK_SKILL.INSTALL_SKILL_DESC
end

function GLOBAL.GetArkSkillConfigById(id)
  local cfg = TUNING[SkillsSymbol][id]
  assert(cfg, "No skill config found for id: " .. tostring(id))
  return cfg
end

-- 修改技能升级图标的尺寸, 维持高清
AddClassPostConstruct("widgets/spinner", function(self)
  local SetSelectedIndex = self.SetSelectedIndex
  function self:SetSelectedIndex(index)
    SetSelectedIndex(self, index)
    local fgimage = self.fgimage
    local atlas = fgimage.atlas
    local texture = fgimage.texture
    if arkSkillLevelUpImages[atlas] and arkSkillLevelUpImages[atlas][texture] then
      fgimage:SetSize(60, 60)
    end
  end
end)

AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim and not inst.components.ark_skill then
    inst:AddComponent("ark_skill")
  end
end)