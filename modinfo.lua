-- 对不支持的语言兜底到英文（DST 原版 ChooseTranslationTable 只回退到 tbl[1]，
-- 但我们用字典键值而非数字索引，非 en/zh 语言会返回 nil 导致崩溃）
local function T(tbl)
    return ChooseTranslationTable(tbl) or tbl["en"]
end

name = T({
    en = "Arknights Item Package",
    zh = "明日方舟 物品包"
})
-- 版本更新说明（由发布脚本自动维护，请勿手动编辑）
local UPDATE_EN = [[
v2.5.10 (2026-08-11)
- Added "body" tag to Construct Armor (compatibility with 4/5/6 equipment slots)
- Added "amulet" tag to Sympathetic Pendant (compatibility with 4/5/6 equipment slots)
---
v2.5.9 (2026-08-11)
- Updated the sympathetic pendant atlas element coordinates and texture layout
]]

local UPDATE_ZH = [[
v2.5.10 (2026-08-11)
- 为构造盔甲添加 "body" 标签（兼容四五六格装备槽）
- 为同情挂件添加 "amulet" 标签（兼容四五六格装备槽）
---
v2.5.9 (2026-08-11)
- 更新同情挂件的元素坐标和纹理信息
]]

description = T({
    en = [[An Arknights-themed expansion and shared framework for Don't Starve Together.
Includes materials, currencies, crafting stations, elite progression, skills, talents, buff icons, and emoticons.

]] .. UPDATE_EN .. [[

Issues & Suggestions Feedback Channels:
Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
Email: tohsakakuro@outlook.com
QQ Group: 666511586
]],
    zh = [[这是一个饥荒联机版的明日方舟主题扩展与通用前置模组。
包含材料掉落、货币、加工站与训练站、精英化养成、技能、天赋、Buff图标和表情等内容。

]] .. UPDATE_ZH .. [[

需求与建议反馈渠道:
Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
Email: tohsakakuro@outlook.com
QQ群: 666511586

欢迎大家积极参与!]]
})
author = "让 望月心灵"
version = "2.5.10"
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
    -- 开启全模组材料掉落, 默认关闭
    name = "enable_all_materials_drop",
    label = T({
        en = "Enable All Arknights Materials Drop",
        zh = "开启明日方舟材料掉落"
    }),
    hover = T({
        en = "When enabled, all materials from the Arknights mod will drop.",
        zh = "开启后, 明日方舟模组中的所有材料都会掉落"
    }),
    options = {{
        description = T({
            en = "Disable",
            zh = "关闭"
        }),
        data = false
    }, {
        description = T({
            en = "Enable",
            zh = "开启"
        }),
        data = true
    }},
    default = false
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
