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
            "happy_battle",
            "scared_battle",
            "sorry_battle",
            "thanks_battle",
            "thinking_battle",
        },
    },{
        key = "autochess_guard",
        name = "AutoChessGuard",
        atlas = atlas,
        icons = {
            "autochess_g2_1",
            "autochess_g2_2",
            "autochess_g2_3",
            "autochess_g2_4",
            "autochess_g2_5",
            "autochess_g2_6",
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
