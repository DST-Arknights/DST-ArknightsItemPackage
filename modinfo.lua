name = ChooseTranslationTable({
    en = "Arknights Item Package",
    zh = "明日方舟 物品包"
})
description = ChooseTranslationTable({
    en = [[This mod adds some items from Arknights to Don't Starve Together.
Feedback and suggestions:

Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
QQ: 3139902761
Email: tohsakakuro@outlook.com
QQ Group: 666511586

Welcome to join us!
]],
    zh = [[这个mod将一些明日方舟的物品添加到饥荒联机版中。
需求与建议反馈渠道:

Issues: https://github.com/DST-Arknights/DST-ArknightsItemPackage/issues
QQ: 3139902761
Email: tohsakakuro@outlook.com
QQ群: 666511586

欢迎大家积极参与!]]
})
author = "让 望月心灵"
version = "1.0.12"
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
    label = ChooseTranslationTable({
        en = "Choose Language",
        zh = "选择语言"
    }),
    hover = ChooseTranslationTable({
        en = "Choose the language of the mod",
        zh = "选择mod的语言"
    }),
    options = {{
        description = ChooseTranslationTable({
            en = "Chinese",
            zh = "中文"
        }),
        data = "zh"
    }, {
        description = ChooseTranslationTable({
            en = "Auto",
            zh = "自动"
        }),
        data = "auto"
    }},
    default = "auto"
}, Title({
    name = "mods_compatibility",
    label = ChooseTranslationTable({
        en = "Other Mods Compatibility",
        zh = "其他模组选项"
    }),
}), {
    name = 'amiya_hecheng_collect',
    label = ChooseTranslationTable({
        en = "Amiya Diamond Collect",
        zh = "阿米娅合成玉 采集"
    }),
    hover = ChooseTranslationTable({
        en = "When enabled, the modded Amiya will no longer occupy extra inventory space when she drops the diamond.",
        zh = "开启后, 模组阿米娅掉落的合成玉不再额外占用背包空间"
    }),
    options = {{
        description = ChooseTranslationTable({
            en = "Enable",
            zh = "开启"
        }),
        data = true
    }, {
        description = ChooseTranslationTable({
            en = "Disable",
            zh = "关闭"
        }),
        data = false
    }},
    default = false
}}
