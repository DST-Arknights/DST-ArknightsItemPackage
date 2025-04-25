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


AddModRPCHandler("arkSkill", "HandEmitSkill", function(player, skillIndex)
  if player and player.components.ark_skill then
    player.components.ark_skill:HandEmitSkill(skillIndex)
  end
end)


local function SetupArkSkillHotKey(config)
  -- 记下原本的热键
  local originalHotKey = {}
  for i, skillConfig in pairs(config.skills) do
    originalHotKey[i] = skillConfig.hotKey
  end
  local localHotKey = nil
  function ThePlayer:SaveArkSkillLocalHotKey(idx, hotKey)
    localHotKey = localHotKey or {}
    if hotKey == nil then
      table.remove(localHotKey, idx)
    else
      localHotKey[idx] = hotKey
    end
    TheSim:SetPersistentString("ark_skill_local_hot_key" .. ThePlayer.userid .. ThePlayer.prefab,
      json.encode(localHotKey), false)
  end

  function ThePlayer:GetArkSkillLocalHotKey(idx)
    return config.skills[idx].hotKey
  end

  function ThePlayer:LoadArkSkillLocalHotKey()
    TheSim:GetPersistentString("ark_skill_local_hot_key" .. ThePlayer.userid .. ThePlayer.prefab,
      function(load_success, str)
        if not load_success then
          localHotKey = {}
          return
        end
        local ok, data = pcall(function()
          return json.decode(str)
        end)
        if not ok then
          localHotKey = {}
          return
        end
        localHotKey = data
      end)
  end
  function ThePlayer:RefreshArkSkillLocalHotKey()
    -- 先恢复原本的热键
    for i, hotKey in pairs(originalHotKey) do
      config.skills[i].hotKey = hotKey
    end
    if not localHotKey then
      return
    end
    for i, hotKey in pairs(localHotKey) do
      if not config.skills[i] then
        break
      end
      config.skills[i].hotKey = hotKey
    end
  end
end

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
    SendModRPCToServer(GetModRPC("arkSkill", "HandEmitSkill"), skillIndex,
      TheInput:IsKeyDown(KEY_CTRL) or TheInput:IsKeyDown(KEY_RCTRL))
    return true
  end
end)

local arkSkillLevelUpImages = {}
function GLOBAL.SetupArkCharacterSkillConfig(prefab, config)
  TUNING.ARK_SKILL_CONFIG = TUNING.ARK_SKILL_CONFIG or {}
  TUNING.ARK_SKILL_CONFIG[prefab] = config
  local skills = config.skills
  for i, skill in ipairs(skills) do
    if i > CONSTANTS.MAX_SKILL_LIMIT then
      break
    end
    
    local resolveAtlas = resolvefilepath(skill.atlas)
    if not arkSkillLevelUpImages[resolveAtlas] then
      arkSkillLevelUpImages[resolveAtlas] = {}
    end 
    arkSkillLevelUpImages[resolveAtlas][skill.image] = true
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
        local desc = STRINGS.UI.ARK_SKILL.CURRENT_LEVEL .. " " .. common.formatSkillLevelString(j-1) .. "\n" .. (STRINGS.UI.ARK_SKILL.NEXT_LEVEL .. " " .. common.formatSkillLevelString(j))
        STRINGS.RECIPE_DESC[upperName] = desc
      end
    end
  end
end

-- 修改技能升级图标的尺寸, 维持高清
AddClassPostConstruct("widgets/spinner", function(self)
  print('spinner inject')
  local SetSelectedIndex = self.SetSelectedIndex
  function self:SetSelectedIndex(index)
    print('SetSelectedIndex', index)
    SetSelectedIndex(self, index)
    local fgimage = self.fgimage
    local atlas = fgimage.atlas
    local texture = fgimage.texture
    if arkSkillLevelUpImages[atlas] and arkSkillLevelUpImages[atlas][texture] then
      fgimage:SetSize(60, 60)
    end
  end
end)


AddPrototyperDef('ark_training_station', {
  icon_atlas = "images/ark_item_prototyper.xml",
  icon_image = "ark_item_prototyper.tex",
  is_crafting_station = true,
  action_str = 'ARK_PROCESSING_STATION',
  filter_text = STRINGS.UI.CRAFTING_FILTERS.ARK_PROCESSING_STATION
})

-- 添加训练站配方
AddRecipe2("ark_training_station",
  {Ingredient("boards", 4), Ingredient("goldnugget", 2)},
  TECH.SCIENCE_TWO,
  {
    placer = 'ark_training_station_placer',
    atlas = "images/ark_training_station.xml",
    image = "ark_training_station.tex",
  },
  {"STRUCTURES"}
)
AddRecipeToFilter("ark_training_station", "PROTOTYPERS")