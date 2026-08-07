TUNING.CONSTRUCT_ARMOR = {
  MAX_CONDITION = 2000,
  -- 血量/耐久互换速率: 2000 耐久 12 分钟换完
  EXCHANGE_RATE_PER_SECOND = 2000 / (12 * 60),
  EXCHANGE_TICK = 1,
  EXCHANGE_PAUSE_AFTER_DAMAGE = 15,
  ABSORB_PERCENT = 1,
}

AddRecipe2('construct_armor', {
  Ingredient("marble", 6),
  Ingredient("rope", 2),
  Ingredient("nightmarefuel", 4),
  Ingredient("purplegem", 2),
}, TECH.MAGIC_THREE, {
  force_hint = true,
}, {
  "ARMOUR",
  "MAGIC",
  "CHARACTER",
  "MODS",
})
