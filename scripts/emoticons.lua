local emotions = {}

local emotion_groups = {
    {
        key = "autochess_basic",
        name = "AutoChess",
        atlas = "images/emoticon_autochess_basic.xml",
        icons = {
            "cooperate_battle",
            "happy_battle",
            "scared_battle",
            "sorry_battle",
            "thanks_battle",
            "thinking_battle",
        },
    },
}

for _, group in ipairs(emotion_groups) do
    for order, key in ipairs(group.icons) do
        table.insert(emotions, {
            group = group.key,
            name = key,
            atlas = group.atlas,
            tex = "pic_"..key..".tex",
            alt = key,
            group_name = group.name,
            order = order,
            sound = "ark_item/HUD/emojidialogue"
        })
        table.insert(emotions, {
            group = "test_group_2" .. group.key,
            name = key,
            atlas = group.atlas,
            tex = "pic_"..key..".tex",
            alt = key,
            group_name = group.name,
            order = order,
            sound = "ark_item/HUD/emojidialogue"
        })
    end
end

return emotions
