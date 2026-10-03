
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

AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim then
    inst:AddComponent("ark_currency")
  end
end)

-- ── 制作栏货币显示 ────────────────────────────────────────
-- 在制作栏 filter 面板右下角注入货币 widget

local UIArkGoldCrafting = require "widgets/ui_ark_gold_crafting"
local CraftingMenuWidget = require("widgets/redux/craftingmenu_widget")

local CURRENCY_SLOTS = 2

ArkHookFunction(CraftingMenuWidget, "MakeFilterPanel", function(next, self, width)
    local panel = next(self, width)

    if self.ark_gold_widget then
        return panel
    end

    -- 布局计算
    local btn_space = self.grid_button_space
    local currency = panel:AddChild(UIArkGoldCrafting(self.owner, btn_space))
    self.ark_gold_widget = currency

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

    -- X: 右对齐，占据最后 CURRENCY_SLOTS 列的中心
    local currency_x = self.grid_left + (cols - (CURRENCY_SLOTS + 1) / 2) * btn_space

    -- Y: 空白够就接在末行，不够就换到下一行
    local currency_y
    if empty_in_last_row >= CURRENCY_SLOTS then
        currency_y = grid_y - (num_rows - 1) * btn_space
    else
        currency_y = grid_y - num_rows * btn_space
        panel.panel_height = panel.panel_height + btn_space
    end

    currency:SetPosition(currency_x, currency_y, 0)

    return panel
end)
