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
v2.6.0 (2026-08-18)
- Optimized elite stage name display, using Chinese number words instead of Arabic numerals for stages 1-10
- Introduced the invisible prefab ark_craft_callback for recipes that only trigger callbacks without producing items
- Refactored elite upgrade and skill install craft callback logic and adjusted related recipe tech requirements
- Fixed Chinese/English prompt text shown when elite level is insufficient
- Reworked the flying component to control altitude with a physical motor instead of directly modifying the y coordinate, re-driving height when moving, and adjusted flight/landing collision
- Completed flyer network sync by mounting state to the replica for prediction compensation and auto-adding the component on player init
- Optimized emotion buff application while a badge is equipped to avoid wrongly restoring emotion state after unequipping
- Optimized entity serialization/deserialization to support skill state management
- Added item enhancement component and feature, including CN/EN translations for enhancement limit prompts
- Optimized armor structure event listening with a priority mechanism for min-HP events and cleaned up redundant description text
---
v2.5.12 (2026-08-12)
- Updated M3 Cocoon Armor data and renamed its prefab
- Added armor_construct resource
]]

local UPDATE_ZH = [[
v2.6.0 (2026-08-18)
- 优化精英阶段名称显示，1至10阶段使用数字词替代阿拉伯数字
- 引入隐形预制体 ark_craft_callback，用于仅触发回调无需实际产物的配方
- 重构精英升级与技能安装的制造回调逻辑，调整相关配方的科技需求
- 修复精英等级不足时的中英文提示文本
- 重构飞行组件，改用物理马达控制垂直高度而非直接修改 y 坐标，移动时重新驱动高度，并调整飞行与降落碰撞
- 完善飞行组件网络同步，将状态挂载到 replica 支持预测补偿，并在玩家初始化时自动添加组件
- 优化徽章装备状态下的情绪 buff 应用逻辑，避免脱装后错误恢复情绪状态
- 优化实体序列化与反序列化逻辑，支持技能状态管理
- 新增物品强化组件与功能，更新强化上限提示的中英文翻译
- 优化盔甲构造的事件监听，使用优先级机制处理最小生命值事件，并移除多余的描述文本
---
v2.5.12 (2026-08-12)
- 修改M3茧甲数据, 预制体重命名
- 新增 armor_construct 资源
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
version = "2.6.0"
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
