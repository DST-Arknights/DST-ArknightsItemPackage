local CONSTANTS = require "ark_constants"
local common = require "ark_common"

-- 添加技能升级的制作回调
AddModRPCHandler("arkSkill", "LevelUpSkill", function(player, skillIndex)
  if player and player.components.ark_skill then
    player.components.ark_skill:LevelUpSkill(skillIndex)
  end
end)

AddModRPCHandler("arkSkill", "RequestSyncSkillStatus", function(player, idx)
  if player and player.components.ark_skill then
    player.components.ark_skill:RequestSyncSkillStatus(idx)
  end
end)

AddClientModRPCHandler("arkSkill", "SyncSkillStatus", function (skillIndex, ...)
  if not ThePlayer then
    return
  end
  local arkSkillUi = ThePlayer.HUD.controls.arkSkillUi
  if not arkSkillUi then
    return
  end
  local skillUi = arkSkillUi:GetSkill(skillIndex)
  -- local oldLevel = skillUi.level
  skillUi:SyncSkillStatus(...)
  -- ThePlayer:PushEvent("refreshcrafting")
end)


AddModRPCHandler("arkSkill", "ManualActivateSkill", function(player, skillIndex)
  if player and player.components.ark_skill then
    player.components.ark_skill:ManualActivateSkill(skillIndex)
  end
end)



AddModRPCHandler("arkSkill", "ManualCancelSkill", function(player, skillIndex)
  if player and player.components.ark_skill then
    player.components.ark_skill:ManualCancelSkill(skillIndex)
  end
end)


local function getStorageKey(player)
  return "ark_skill_local_hot_key" .. player.userid .. player.prefab
end

local function SetupArkSkillHotKey(config)
  local hotKeyManager = {
    default = {},  -- 默认热键配置
    custom = nil,   -- 自定义热键配置
  }

  -- 保存默认热键配置
  for i, skillConfig in pairs(config.skills) do
    hotKeyManager.default[i] = skillConfig.hotKey
  end

  -- 保存自定义热键
  function ThePlayer:SaveArkSkillLocalHotKey(idx, hotKey)
    hotKeyManager.custom = hotKeyManager.custom or {}
    
    if hotKey == nil then
      table.remove(hotKeyManager.custom, idx)
    else
      hotKeyManager.custom[idx] = hotKey
    end

    TheSim:SetPersistentString(getStorageKey(ThePlayer), 
      json.encode(hotKeyManager.custom), false)
  end

  -- 获取热键配置
  function ThePlayer:GetArkSkillLocalHotKey(idx)
    return config.skills[idx].hotKey
  end

  -- 加载自定义热键配置
  function ThePlayer:LoadArkSkillLocalHotKey()
    TheSim:GetPersistentString(getStorageKey(ThePlayer),
      function(load_success, str)
        if not load_success then
          hotKeyManager.custom = {}
          return
        end

        local ok, data = pcall(json.decode, str)
        if not ok then
          hotKeyManager.custom = {}
          return
        end

        hotKeyManager.custom = data
      end)
  end

  -- 刷新热键配置
  function ThePlayer:RefreshArkSkillLocalHotKey()
    -- 恢复默认热键
    for i, hotKey in pairs(hotKeyManager.default) do
      config.skills[i].hotKey = hotKey
    end

    -- 应用自定义热键
    if not hotKeyManager.custom then return end
    
    for i, hotKey in pairs(hotKeyManager.custom) do
      if config.skills[i] then
        config.skills[i].hotKey = hotKey
      end
    end
  end
end

local arkSkillLevelUpImages = {}

AddClientModRPCHandler("arkSkill", "SetupArkSkillUi", function(config)
  if not config or not ThePlayer.HUD or ThePlayer.HUD.controls.arkSkillUi then
    return
  end
  local config = json.decode(config)
  local controls = ThePlayer.HUD.controls
  local ArkSkillUi = require "widgets/ark_skill_ui"
  controls.arkSkillUi = controls.inv.hand_inv:AddChild(ArkSkillUi(ThePlayer, config))
  controls.arkSkillUi:SetPosition(config.position or Vector3(-840, 80, 0))
  controls.arkSkillUi:SetScale(.5, .5, .5)
  -- 安装本地热键方法
  SetupArkSkillHotKey(config)
  ThePlayer:LoadArkSkillLocalHotKey()
  ThePlayer:RefreshArkSkillLocalHotKey()

  local function findSkillHotKeyIndex(hotKey, skillConfigs)
    for i, config in pairs(skillConfigs) do
      if config.hotKey == hotKey then
        return i
      end
    end
  end
  -- 替换高清资源
  for _, skill in pairs(config.skills) do
    local resolveAtlas = resolvefilepath(skill.atlas)
    if not arkSkillLevelUpImages[resolveAtlas] then
      arkSkillLevelUpImages[resolveAtlas] = {}
    end
    arkSkillLevelUpImages[resolveAtlas][skill.image] = true
  end

  -- 安装热键
  local _OnRawKey = ThePlayer.HUD.OnRawKey
  function ThePlayer.HUD:OnRawKey(key, down)
    if not down then
      return _OnRawKey(self, key, down)
    end
    if ThePlayer.HUD._settingSkillHotKeyCallback then
      -- 检查是否有冲突
      local conflictIndex = findSkillHotKeyIndex(key, config.skills)
      ThePlayer.HUD._settingSkillHotKeyCallback(key, conflictIndex)
      return true
    end
    local skillIndex = findSkillHotKeyIndex(key, config.skills)
    if not skillIndex then
      return _OnRawKey(self, key, down)
    end
    local skill = controls.arkSkillUi:GetSkill(skillIndex)
    skill:TryActivateSkill()
    return true
  end
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


-- AddPrototyperDef('ark_training_room', {
--   icon_atlas = "images/ark_item_prototyper.xml",
--   icon_image = "ark_item_prototyper.tex",
--   is_crafting_station = true,
--   action_str = 'ARK_WORKSHOP',
--   filter_text = STRINGS.UI.CRAFTING_FILTERS.ARK_WORKSHOP
-- })

-- -- 添加训练室配方
-- AddRecipe2("ark_training_room",
--   {Ingredient("boards", 4), Ingredient("goldnugget", 2)},
--   TECH.SCIENCE_TWO,
--   {
--     placer = 'ark_training_room_placer',
--     atlas = "images/ark_training_room.xml",
--     image = "ark_training_room.tex",
--   },
--   {"STRUCTURES"}
-- )
-- AddRecipeToFilter("ark_training_room", "PROTOTYPERS")

function GLOBAL.ARK_GLOBAL.SetupArkSkillConfig(prefab, config)
  TUNING.ARK_SKILL[string.upper(prefab)] = config
  local skills = config.skills
  for i, skill in ipairs(skills) do
    if i > CONSTANTS.MAX_SKILL_LIMIT then
      break
    end

    for j, levelConfig in ipairs(skill.levels) do
      if j > CONSTANTS.MAX_SKILL_LEVEL then
        break
      end
      if j ~= 1 then
        local prefabName = common.genArkSkillLevelUpPrefabName(i, j)
        local ingredients = levelConfig.ingredients or { Ingredient("goldnugget", 1) }
        local tag = common.genArkSkillLevelTag(i, j - 1)
        AddCharacterRecipe(prefabName, ingredients, TECH.ARK_TRAINING_ONE, {
          nounlock = true,
          atlas = skill.atlas,
          image = skill.image,
          actionstr = j <= 7 and "ARK_SKILL_UPDATE" or "ARK_SKILL_SPECIALIZATION",
          builder_tag = tag,
          manufactured = true,
        })
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

function GLOBAL.ARK_GLOBAL.GetArkSkillConfig(prefab)
  return TUNING.ARK_SKILL[string.upper(prefab)]
end