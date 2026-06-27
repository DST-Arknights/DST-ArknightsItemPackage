local assets = {
  Asset("ATLAS", "images/ui_sympathetic_pendants.xml")
}
-- TODO: 替换i18n
local buffs = { {
  assets = assets,
  name = "sympathetic_pendant_confused_owner_buff",
  title = "共情项坠:困惑",
  description = "增加移动速度,减少攻击力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "confused.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_confused_shared_buff",
  title = "共情项坠:困惑(来自队友)",
  description = "增加移动速度,减少攻击力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "confused.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_angry_owner_buff",
  title = "共情项坠:愤怒",
  description = "增加攻击力,减少防御力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "angry.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_angry_shared_buff",
  title = "共情项坠:愤怒(来自队友)",
  description = "增加攻击力,减少防御力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "angry.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_happy_owner_buff",
  title = "共情项坠:快乐",
  description = "增加生命恢复,减少饥饿消耗",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "happy.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_happy_shared_buff",
  title = "共情项坠:快乐(来自队友)",
  description = "增加生命恢复,减少饥饿消耗",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "happy.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_sad_owner_buff",
  title = "共情项坠:悲伤",
  description = "减少移动速度,增加防御力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "sad.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_sad_shared_buff",
  title = "共情项坠:悲伤(来自队友)",
  description = "减少移动速度,增加防御力",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "sad.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_normal_owner_buff",
  title = "共情项坠:快乐",
  description = "增加生命恢复,减少饥饿消耗",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "normal.tex",
}, {
  assets = assets,
  name = "sympathetic_pendant_normal_shared_buff",
  title = "共情项坠:快乐(来自队友)",
  description = "增加生命恢复,减少饥饿消耗",
  icon_atlas = "images/ui_sympathetic_pendants.xml",
  icon_image = "normal.tex",
}, }

local results = {}
for _, v in ipairs(buffs) do
  table.insert(results, ArkMakeBuff(v))
end

return unpack(results)
