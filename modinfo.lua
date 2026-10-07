-- 对不支持的语言兜底到英文（DST 原版 ChooseTranslationTable 只回退到 tbl[1]，
-- 但我们用字典键值而非数字索引，非 en/zh 语言会返回 nil 导致崩溃）
local function T(tbl)
    return ChooseTranslationTable(tbl) or tbl["en"]
end

name = T({
    en = "Arknights Item Package",
    zh = "明日方舟 物品包"
})
version = "2.10.0"

-- 版本更新说明（由发布脚本自动维护，请勿手动编辑）
local UPDATE_EN = [[
v2.10.0 (2026-10-08)
- Supply Station recharge now shows the actual accepted amount as a popup at the target and syncs it to other clients; the popup follows the target, stays at its last position to fade out if the target is gone, and uses adjusted font size and italic number font.
- Supply Stations now consume fuel based on each target's actual total usage and show only one cumulative recharge number; default skill recharge consumes fuel only when skill progress or charges actually change.
- Character select and player profile cards now support animated big portraits: they can be registered, play animations in sequence, automatically loop the last segment, and fall back to static portraits.
- Added healing recharge for Construct Armor; adjusted M3 Cocoon Armor's health exchange to a fixed 20 Health balance line, limited each exchange to move toward the boundary, and made Mon3tr chain healing charge equipped Cocoon Armor at 25% of theoretical healing.
- Added new emote icons and the Mon3tr emote group, removed extra emotes, adjusted AutoChess group icon order; fixed false RemoveSkill failed / ID mismatch errors on entity destruction, and improved Portable Supply Station animation, fuel management, VFX color, and label settings.
---
v2.9.1 (2026-10-05)
- Removed the mod-wide material drop configuration option.
]]

local UPDATE_ZH = [[
v2.10.0 (2026-10-08)
- 补给站充能现在会在目标处显示实际接受量的飘字，并同步给其他客户端；飘字会跟随目标，目标失效后保留最后位置淡出，同时调整了字号与斜体数字字体。
- 充能站现在按目标实际总用量扣除燃料，并只显示一次累计充能数值；默认技能充能仅在进度或层数实际变化时消耗燃料。
- 选人界面和玩家资料卡支持动态大立绘：可注册并顺序播放动画，自动循环最后一段，兼容静态立绘降级。
- 新增“构造护甲”治疗充能；调整 M3茧甲生命交换机制为固定 20 点生命平衡线，限制单次交换向边界靠拢，并让 Mon3tr 链式治疗按理论治疗量的 25% 为已装备茧甲充能。
- 新增表情图标与 Mon3tr 表情组，移除多余表情并调整 AutoChess 组图标顺序；修复实体销毁时的 RemoveSkill failed / ID mismatch 误报，并优化便携式补给站的动画、燃料管理、特效颜色和标签。
---
v2.9.1 (2026-10-05)
- 移除了全模组材料掉落配置选项。
]]

description = T({
    en = [[An Arknights-themed expansion and shared framework for Don't Starve Together.
Includes materials, currencies, crafting stations, elite progression, skills, talents, buff icons, and emoticons.

Current version: ]] .. version .. "\n" .. UPDATE_EN .. [[

Issues & Suggestions Feedback Channels:
Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
Email: tohsakakuro@outlook.com
QQ Group: 666511586
]],
    zh = [[这是一个饥荒联机版的明日方舟主题扩展与通用前置模组。
包含材料掉落、货币、加工站与训练站、精英化养成、技能、天赋、Buff图标和表情等内容。

当前版本: ]] .. version .. "\n" .. UPDATE_ZH .. [[

需求与建议反馈渠道:
Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
Email: tohsakakuro@outlook.com
QQ群: 666511586

欢迎大家积极参与!]]
})
author = "让 望月心灵"
forumthread = "https://steamcommunity.com/sharedfiles/filedetails/?id=3677284770"

api_version = 10

dont_starve_compatible = false
reign_of_giants_compatible = false

dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"

priority = 1

server_filter_tags = {"arknights", "明日方舟", "item", "物品"}

local function Title(opt)
    opt.options = {{ description = "", data = 0 }}
    opt.default = 0
    return opt
end

configuration_options = {{
    name = "language",
    label = T({
        en = "Choose Language",
        zh = "选择语言"
    }),
    hover = T({
        en = "Choose the language of the mod",
        zh = "选择mod的语言"
    }),
    options = {{
        description = T({
            en = "Chinese",
            zh = "中文"
        }),
        data = "zh"
    }, {
        description = T({
            en = "Auto",
            zh = "自动"
        }),
        data = "auto"
    }},
    default = "auto"
}, {
    name = "hand_base_scale",
    label = T({
        en = "Skill Bar Size",
        zh = "技能栏大小"
    }),
    hover = T({
        en = "Adjust the overall skill bar UI scale. 1.2 matches the current standard size.",
        zh = "调整 技能栏 整体缩放。1.2 为当前标准大小"
    }),
    options = {{
        description = T({
            en = "Small (1.0)",
            zh = "较小 (1.0)"
        }),
        data = 1.0
    }, {
        description = T({
            en = "Standard (1.2)",
            zh = "标准 (1.2)"
        }),
        data = 1.2
    }, {
        description = T({
            en = "Large (1.4)",
            zh = "较大 (1.4)"
        }),
        data = 1.4
    }, {
        description = T({
            en = "Extra Large (1.6)",
            zh = "超大 (1.6)"
        }),
        data = 1.6
    }},
    default = 1.2
}, Title({
    name = "mods_compatibility",
    label = T({
        en = "Other Mods Compatibility",
        zh = "其他模组选项"
    }),
}), {
    name = 'amiya_hecheng_collect',
    label = T({
        en = "Amiya Diamond Optimization",
        zh = "阿米娅合成玉 优化"
    }),
    hover = T({
        en = "When enabled, the modded Amiya will no longer occupy extra inventory space when she drops the diamond.",
        zh = "开启后, 模组阿米娅掉落的合成玉不再额外占用背包空间"
    }),
    options = {{
        description = T({
            en = "Enable",
            zh = "开启"
        }),
        data = true
    }, {
        description = T({
            en = "Disable",
            zh = "关闭"
        }),
        data = false
    }},
    default = false
}}
