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
v2.7.1 (2026-09-24)
- Reposition publish script parameters and improve the blacklist mechanism.
- Add first-release mode and improve changelog generation and validation in the publishing workflow.
- Add support for converting Steam description Markdown to BBCode.
- Update carryable item recipes, adjusting required materials and technology categories.
- Simplify project configuration in the publish scripts and support generating local test builds.
- Add voice playback channel options and improve voice playback management.
- Fix abnormal flight height when lag compensation is enabled.
- Update PowerShell scripts to support UTF-8 encoding and ensure Chinese output displays correctly.
---
v2.7.0 (2026-09-11)
- Comment out the ark_backpack recipe
- Update the recipe material amounts for 盔甲构造 and 同情挂坠
- Update crafting menu icons and related configuration files
- Add crafting menu icons XML configuration: create a new XML file defining the texture and elements for the crafting menu
- Add technology recipe filter and diamond currency display
- Add target filtering and focus animation configuration supported by the map selector to the target selector
- Add the fly anim flight animation resource
- Refactor the target selector and hotkey manager, and update file paths to improve module imports
- Refactor the target selector, add map coordinate selector support, and update the docs
- Update the fly anim animation resource again
- Update the README and docs, adding explanations of the target selector and skill callback semantics
- Add the ArkLoadLuaFile function to load Lua files and return their value
- Refactor the voice system, adding voice registration, binding, and playback features
- Add skill selector support and optimize skill activation logic
- Optimize skill description handling to support a shared description across multiple levels
- Introduce the target selector framework, replacing the AOE selector and optimizing skill activation logic
- Change changelog to a Chinese/English grouped format (all Chinese first, English after): AI prompt outputs a Chinese bullet group + --- + an English bullet group; Get-ChangelogVersionEntries returns ZhItems/EnItems and stays compatible with the old en|zh format; modinfo.ps1 uses ZhItems/EnItems directly to generate UPDATE_ZH/UPDATE_EN
- Filter AI CLI diagnostic log lines so they don't leak into the changelog: diagnostic lines such as [claude-code:unrecognized_model] that claude CLI writes to stderr were merged via 2>&1 and written into CHANGELOG.md; lines starting with [claude-code: are now filtered out
]]

local UPDATE_ZH = [[
v2.7.1 (2026-09-24)
- 调整发布脚本参数位置并优化黑名单机制。
- 添加首次发布模式，优化发布流程中的 changelog 生成与校验。
- 添加将 Steam 介绍 Markdown 转换为 BBCode 的功能。
- 更新可携带物品配方，调整所需材料与科技分类。
- 简化发布脚本的项目配置管理，并支持生成本地内测版本。
- 添加语音播放通道选项，优化语音播放管理。
- 修复启用延时补偿时飞行高度异常的问题。
- 更新 PowerShell 脚本以支持 UTF-8 编码，确保中文输出正常。
---
v2.7.0 (2026-09-11)
- 注释掉 ark_backpack 配方
- 更新盔甲构造与同情挂坠的配方材料数量
- 更新制作菜单图标及相关配置文件
- 新增 crafting menu icons XML 配置：创建新的 XML 文件，定义 crafting menu 纹理与元素
- 添加 technology recipe filter 与 diamond currency display
- 为 target selector 添加地图选择器支持的目标过滤与焦点动画配置
- 添加 fly anim 飞行动画资源
- 重构目标选择器与热键管理器，调整文件路径以优化模块导入
- 重构目标选择器，新增地图坐标选择器支持并更新文档
- 再次更新 fly anim 动画资源
- 更新 README 与文档，补充目标选择器与技能回调语义说明
- 新增 ArkLoadLuaFile 函数，用于加载 Lua 文件并返回其值
- 重构配音系统，新增语音注册、绑定与播放功能
- 新增技能选择器支持，优化技能激活逻辑
- 优化技能描述处理，支持多个级别共用描述
- 引入目标选择器框架，替代 AOE 选择器并优化技能激活逻辑
- changelog 改为中英分组格式（中文在前、英文在后）：AI prompt 输出中文 bullet 组 + --- + 英文 bullet 组，Get-ChangelogVersionEntries 返回 ZhItems/EnItems 并兼容旧 en|zh 格式，modinfo.ps1 直接用 ZhItems/EnItems 生成 UPDATE_ZH/UPDATE_EN
- 过滤 AI CLI 诊断日志行，避免混入 changelog：claude CLI 向 stderr 输出的 [claude-code:unrecognized_model] 等诊断行被 2>&1 合并后写入 CHANGELOG.md，现过滤以 [claude-code: 开头的日志行
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
version = "2.7.1"
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
