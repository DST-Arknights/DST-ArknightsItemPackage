local emotions = {}
local sound = "ark_item/HUD/emojidialogue"
local atlas = "images/ark_emoticon.xml"
local emotion_groups = {
    {
        key = "autochess_basic",
        name = "AutoChess",
        atlas = atlas,
        icons = {
            "cooperate_battle",
            "sorry_battle",
            "thanks_battle",
            "autochess_g2_2",
            "autochess_g2_6",
            "autochess_g2_1",
        },
    },{
        key = "mimizi",
        name = "Mimizi",
        atlas = atlas,
        icons = {
            "mimizi_1",
            "mimizi_2",
            "mimizi_3",
            "mimizi_4",
            "mimizi_5",
            "mimizi_6",
        },
    },{
        key = "weiweimei",
        name = "WeiWeiMei",
        atlas = atlas,
        icons = {
            "weiweimei_1",
            "weiweimei_2",
            "weiweimei_3",
            "weiweimei_4",
            "weiweimei_5",
            "weiweimei_6",
        },
    },{
        key = "mon3tr",
        name = "Mon3tr",
        atlas = atlas,
        icons = {
            "mon3tr_1",
            "mon3tr_2",
            "mon3tr_3",
            "mon3tr_4",
            "mon3tr_5",
            "mon3tr_6",
        },
    },{
        key = "ling",
        name = "Ling",
        atlas = atlas,
        icons = {
            "ling_1",
            "ling_2",
            "ling_3",
            "ling_4",
            "ling_5",
            "ling_6",
        },
    },
}


for _, group in ipairs(emotion_groups) do
    for order, key in ipairs(group.icons) do
        table.insert(emotions, {
            group = group.key,
            name = key,
            atlas = group.atlas,
            tex = key..".tex",
            alt = key,
            group_name = group.name,
            order = order,
            sound = sound,
        })
    end
end

return emotions
