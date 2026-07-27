
TUNING.ARK_CURRENCY_TYPES = {"ark_gold", "ark_diamond_shd", "ark_diamond", "ark_exgg_shd", "ark_hgg_shd", "ark_lgg_shd"}

for _, t in pairs(TUNING.ARK_CURRENCY_TYPES) do
  AddCharacterIngredient(t, {
    Has = function(inst, amount)
      local cur = inst.replica.ark_currency
        and inst.replica.ark_currency:GetArkCurrencyByType(t) or 0
      return cur >= amount, cur
    end,
    Consume = function(inst, amount)
      if inst.components.ark_currency then
        inst.components.ark_currency:AddArkCurrencyByType(t, -amount)
      end
    end,
  })
end

AddPrefabPostInit("world", function(inst)
  if TheNet:GetIsServer() then
    inst:AddComponent("ark_currency_data")
  end
end)

-- 使用货币
AddAction("USE_ARK_CURRENCY", STRINGS.ACTIONS.USE_ARK_CURRENCY.GENERIC, function(act)
  local target = act.target or act.invobject
  if target.components.ark_currency_item and act.doer.components.ark_currency then
    local prices = target.components.ark_currency_item:GetAllPrices()
    for _, v in pairs(prices) do
      act.doer.components.ark_currency:AddArkCurrencyByType(v.currencyType, v.value)
    end
    target.components.stackable:Get():Remove()
    return true
  end
  return false
end)

AddComponentAction('INVENTORY', 'ark_currency_item', function(inst, doer, actions, right)
  table.insert(actions, ACTIONS.USE_ARK_CURRENCY)
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.USE_ARK_CURRENCY, 'useArkCurrency'))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.USE_ARK_CURRENCY, 'useArkCurrency'))

local useArkCurrencyState = State {
  name = "useArkCurrency",
  onenter = function(inst, data)
    local action = inst:GetBufferedAction()
    -- 是否在主世界
    if action ~= nil and not TheWorld.ismastersim then
      inst:PerformPreviewBufferedAction()
    end
    inst.components.locomotor:Stop()
    inst.AnimState:PlayAnimation("give")
  end,
  timeline = {TimeEvent(10 * FRAMES, function(inst)
    if not TheWorld.ismastersim then
      return
    end
    inst:PerformBufferedAction()
  end)},
  events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
}

AddStategraphState("wilson", useArkCurrencyState)
AddStategraphState("wilson_client", useArkCurrencyState)

-- 货币系统ui
table.insert(Assets, Asset("ATLAS", "images/ark_item_ui.xml"))

local function Clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function CalcEpicGoldDropByHealth(maxhealth)
  local health = math.max(1, maxhealth or 1)
  local scale = math.max(1, math.floor(math.sqrt(health) / 25))
  local dropRatio = 2 / 3

  local baseGold2Min = 1 + math.floor(scale * 0.5)
  local baseGold2Max = 2 + scale
  local baseGold1Min = 2 + scale
  local baseGold1Max = 4 + scale * 2
  local baseGold3Chance = Clamp(0.08 + scale * 0.02, 0.08, 0.35)

  local gold2Min = math.max(1, math.floor(baseGold2Min * dropRatio))
  local gold2Max = math.max(gold2Min, math.floor(baseGold2Max * dropRatio))
  local gold1Min = math.max(1, math.floor(baseGold1Min * dropRatio))
  local gold1Max = math.max(gold1Min, math.floor(baseGold1Max * dropRatio))
  local gold3Chance = Clamp(baseGold3Chance * dropRatio, 0.05, 0.35)

  return gold2Min, gold2Max, gold1Min, gold1Max, gold3Chance
end

local function OnEpicDeathDropGold(inst)
  if not inst:HasTag("epic") then
    return
  end
  if not (inst.components and inst.components.health and inst.components.lootdropper) then
    return
  end

  local lootdropper = inst.components.lootdropper
  local maxhealth = inst.components.health.maxhealth or 0
  local gold2Min, gold2Max, gold1Min, gold1Max, gold3Chance = CalcEpicGoldDropByHealth(maxhealth)

  lootdropper:AddLoot("ark_item_gold2", math.random(gold2Min, gold2Max))
  lootdropper:AddLoot("ark_item_gold1", math.random(gold1Min, gold1Max))
  lootdropper:AddChanceLoot("ark_item_gold3", gold3Chance)
end

AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim then
    inst:AddComponent("ark_currency")
  end
end)

AddPrefabPostInitAny(function(inst)
  if not TheWorld.ismastersim then
    return
  end
  if not inst:HasTag("epic") then
    return
  end
  if inst._ark_epic_gold_drop_hooked then
    return
  end

  inst._ark_epic_gold_drop_hooked = true
  inst:ListenForEvent("death", OnEpicDeathDropGold)
end)

-- ── 制作栏金币显示 ────────────────────────────────────────
-- 在制作栏 filter 面板右下角注入金币 widget

local UIArkGoldCrafting = require "widgets/ui_ark_gold_crafting"
local CraftingMenuWidget = require("widgets/redux/craftingmenu_widget")

local GOLD_SLOTS = 2

ArkHookFunction(CraftingMenuWidget, "MakeFilterPanel", function(next, self, width)
    local panel = next(self, width)

    if self.ark_gold_widget then
        return panel
    end

    local gold = panel:AddChild(UIArkGoldCrafting(self.owner))
    self.ark_gold_widget = gold

    -- 布局计算
    local btn_space = self.grid_button_space
    local cols = math.floor(
        -(self.grid_left - btn_space / 2) * 2 / btn_space + 0.5
    )

    -- 统计 grid 中的 filter 按钮数量
    local num_grid_items = 0
    for _, filter_def in ipairs(CRAFTING_FILTER_DEFS) do
        if not filter_def.custom_pos
            and (filter_def ~= CRAFTING_FILTERS.MODS or #filter_def.recipes > 0)
        then
            num_grid_items = num_grid_items + 1
        end
    end

    local grid = panel.filter_grid
    local grid_pos = grid:GetPosition()
    local grid_y = grid_pos.y
    local num_rows = grid.num_rows or 1

    local last_row_count = num_grid_items % cols
    if last_row_count == 0 then
        last_row_count = cols
    end
    local empty_in_last_row = cols - last_row_count

    -- X: 右对齐，占据最后 GOLD_SLOTS 列的中心
    local gold_x = self.grid_left + (cols - GOLD_SLOTS / 2) * btn_space

    -- Y: 空白够就接在末行，不够就换到下一行
    local gold_y
    if empty_in_last_row >= GOLD_SLOTS then
        gold_y = grid_y - (num_rows - 1) * btn_space
    else
        gold_y = grid_y - num_rows * btn_space
        panel.panel_height = panel.panel_height + btn_space
    end

    gold:SetPosition(gold_x, gold_y, 0)

    return panel
end)