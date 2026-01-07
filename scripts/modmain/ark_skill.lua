local CONSTANTS = require "ark_constants"
local common = require "ark_common"

-- 技能升级 RPC 处理
AddModRPCHandler("arkSkill", "LevelUpSkill", function(player, skillId)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(skillId)
  if not skill then return end
  local level = (skill.data.level or 1) + 1
  skill:SetLevel(level)
end)

-- 技能设置等级 RPC 处理
AddModRPCHandler("arkSkill", "SetSkillLevel", function(player, skillId, level)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(skillId)
  if not skill then return end
  skill:SetLevel(level)
end)

-- 请求同步技能状态 RPC 处理
AddModRPCHandler("arkSkill", "RequestSyncSkillStatus", function(player, id)
  if not player or not player.components.ark_skill then return end
  player.components.ark_skill:RequestSyncSkillStatus(id)
end)

-- 客户端同步技能状态
AddClientModRPCHandler("arkSkill", "SyncSkillStatus", function (skillId, ...)
  if not ThePlayer then
    return
  end
  local arkSkillUi = ThePlayer.HUD.controls.arkSkillUi
  if not arkSkillUi then
    return
  end
  local skillUi = arkSkillUi.skills.GetSkillById and arkSkillUi.skills:GetSkillById(skillId) or nil
  if not skillUi then
    return
  end
  skillUi:SyncSkillStatus(...)
end)

-- 手动激活技能 RPC 处理
AddModRPCHandler("arkSkill", "ManualActivateSkill", function(player, id, target, targetPos, force)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(id)
  if not skill then return end
  local config = skill.config
  if config.activationMode ~= CONSTANTS.ACTIVATION_MODE.MANUAL then
    return
  end
  local deserializedPos = string.split(targetPos, ",")
  targetPos = Vector3(tonumber(deserializedPos[1]), tonumber(deserializedPos[2]), tonumber(deserializedPos[3]))
  skill:Activate(target, targetPos, force)
end)

-- 手动取消技能 RPC 处理
AddModRPCHandler("arkSkill", "ManualCancelSkill", function(player, id)
  if not player or not player.components.ark_skill then return end
  local skill = player.components.ark_skill:GetSkill(id)
  if not skill then return end
  skill:Cancel()
end)

-- 请求技能配置 RPC 处理
AddModRPCHandler("arkSkill", "ResponseSkillsConfig", function(player)
  if not player or not player.replica.ark_skill then return end
  player.replica.ark_skill:ResponseSkillsConfig()
end)

local arkSkillLevelUpImages = {}

AddClientModRPCHandler("arkSkill", "ClientRegisterSkill", function(config)
  config = json.decode(config)
  if ThePlayer and ThePlayer.replica.ark_skill then
    if ThePlayer.replica.ark_skill then
      ThePlayer.replica.ark_skill:ClientRegisterSkill(config)
    else
      ThePlayer.pending_ark_skill_configs = ThePlayer.pending_ark_skill_configs or {}
      table.insert(ThePlayer.pending_ark_skill_configs, config)
    end
  end
  -- 替换高清资源
  local resolveAtlas = resolvefilepath(config.atlas)
  if not arkSkillLevelUpImages[resolveAtlas] then
    arkSkillLevelUpImages[resolveAtlas] = {}
  end
  arkSkillLevelUpImages[resolveAtlas][config.image] = true
end)

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

function GLOBAL.AddSkillLevelUpRecipes(characterPrefab,skills)
  for i, skill in ipairs(skills) do
    if i > CONSTANTS.MAX_SKILL_LIMIT then
      break
    end
    for j, levelConfig in ipairs(skill.levels) do
      if j > CONSTANTS.MAX_SKILL_LEVEL then
        break
      end
      if j ~= 1 then
        local prefabName = common.genArkSkillLevelUpPrefabNameById(characterPrefab,skill.id, j)
        local ingredients = levelConfig.ingredients or { Ingredient("goldnugget", 1) }
        AddCharacterRecipe(prefabName, ingredients, TECH.ARK_TRAINING_ONE, {
          nounlock = true,
          atlas = skill.atlas,
          image = skill.image,
          actionstr = j <= 7 and "ARK_SKILL_UPDATE" or "ARK_SKILL_SPECIALIZATION",
          builder_tag = common.genArkSkillLevelUpPrefabNameById(characterPrefab,skill.id, j - 1),
          manufactured = true,
        })
        AddRecipeToFilter(prefabName, CRAFTING_FILTERS.CRAFTING_STATION.name)
        local upperName = string.upper(prefabName)
        STRINGS.NAMES[upperName] = STRINGS.UI.ARK_SKILL.SKILL .. " " .. skill.name
        local currentLevel = STRINGS.UI.ARK_SKILL.LEVEL[tostring(j-1)] or tostring(j-1)
        local nextLevel = STRINGS.UI.ARK_SKILL.LEVEL[tostring(j)] or tostring(j)
        local desc = STRINGS.UI.ARK_SKILL.CURRENT_LEVEL .. " " .. " " .. currentLevel .. "\n" .. (STRINGS.UI.ARK_SKILL.NEXT_LEVEL .. " " .. nextLevel)
        STRINGS.RECIPE_DESC[upperName] = desc
      end
    end
  end
end
