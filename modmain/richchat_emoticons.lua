local Widget = GLOBAL.require("widgets/widget")
local Text = GLOBAL.require("widgets/text")
local Image = GLOBAL.require("widgets/image")

local CHAT_SIZE = 30
local CHAT_ROW_GAP = 2
local CHAT_QUEUE_SIZE = 7
local CHAT_BOTTOM_Y = -624
local CHAT_SCROLL_VISUAL_SIZE = 14
local DEFAULT_EMOTICON_GROUP = "default"

local _registry_revision = 0
local _max_rich_line_height = CHAT_SIZE + CHAT_ROW_GAP

local _registry = {}
local _registry_group_map = {}
local _registry_group_order = {}

local function ValidateIdentifier(key)
    return type(key) == "string"
        and key:match("^[a-z0-9_%-]+$") ~= nil
end

local function NormalizeVAlign(valign)
    if valign == "top" then
        return "top"
    end
    if valign == "middle" or valign == "center" then
        return "middle"
    end
    return "bottom"
end

local function CopyArray(values)
    if values == nil then
        return nil
    end

    local out = {}
    for i, value in ipairs(values) do
        out[i] = value
    end
    return out
end

local function NormalizeGroupKey(group)
    if type(group) == "string" and group ~= "" then
        return group
    end
    return DEFAULT_EMOTICON_GROUP
end

local function MakeRegistryKey(group, name)
    return string.format("%s/%s", group, name)
end

local function MakeEmoticonCode(group, name)
    if group == DEFAULT_EMOTICON_GROUP then
        return ":img/"..name..":"
    end
    return ":img/"..group.."/"..name..":"
end

local function ResolveGroupName(group_key, def)
    if type(def.group_name) == "string" and def.group_name ~= "" then
        return def.group_name
    end
    return group_key
end

local function EnsureRegistryGroup(group_key, def)
    local group = _registry_group_map[group_key]
    if group == nil then
        group = {
            key = group_key,
            name = ResolveGroupName(group_key, def),
            order = {},
            entries = {},
        }
        _registry_group_map[group_key] = group
        table.insert(_registry_group_order, group)
    elseif type(def.group_name) == "string" and def.group_name ~= "" then
        group.name = def.group_name
    end

    return group
end

local function UpsertRegistryGroupEntry(group_key, key)
    local group = _registry_group_map[group_key]
    if group == nil then
        return
    end

    if group.entries[key] == nil then
        group.entries[key] = true
        table.insert(group.order, key)
    end
end

local function RegisterChatEmoticon(def)
    assert(type(def) == "table", "chat emoticon def must be a table")
    assert(ValidateIdentifier(def.name), "chat emoticon def.name is required and must be a simple identifier")
    assert(type(def.atlas) == "string" and def.atlas ~= "", "chat emoticon def.atlas is required")
    assert(type(def.tex) == "string" and def.tex ~= "", "chat emoticon def.tex is required")

    local group_key = NormalizeGroupKey(def.group)
    assert(ValidateIdentifier(group_key), "chat emoticon def.group must be a simple identifier")

    local registry_key = MakeRegistryKey(group_key, def.name)
    _registry[registry_key] =
    {
        name = def.name,
        atlas = def.atlas,
        tex = def.tex,
        width = def.width or 52,
        height = def.height or 52,
        baseline = def.baseline or -2,
        valign = NormalizeVAlign(def.valign),
        tint = def.tint,
        sound = def.sound,
        alt = def.alt or def.name,
        group = group_key,
        group_name = ResolveGroupName(group_key, def),
        order = def.order or (#_registry_group_order + 1),
    }

    _registry_revision = _registry_revision + 1
    _max_rich_line_height = math.max(_max_rich_line_height, (_registry[registry_key].height or 52) + math.abs(def.baseline or -2) * 2 + CHAT_ROW_GAP)

    EnsureRegistryGroup(group_key, def)
    UpsertRegistryGroupEntry(group_key, registry_key)
end

GLOBAL.RegisterChatEmoticon = RegisterChatEmoticon

local function GetRegisteredChatEmoticons()
    local groups = {}

    for _, group in ipairs(_registry_group_order) do
        local icons = {}

        for _, key in ipairs(group.order) do
            local def = _registry[key]
            if def ~= nil then
                table.insert(icons, {
                    key = key,
                    group = def.group,
                    name = def.name,
                    atlas = def.atlas,
                    tex = def.tex,
                    width = def.width,
                    height = def.height,
                    tint = CopyArray(def.tint),
                    sound = def.sound,
                    alt = def.alt,
                    emoticon_code = MakeEmoticonCode(def.group, def.name),
                    order = def.order or 0,
                })
            end
        end

        table.sort(icons, function(a, b)
            if a.order == b.order then
                return a.name < b.name
            end
            return a.order < b.order
        end)

        table.insert(groups, {
            key = group.key,
            name = group.name,
            icons = icons,
        })
    end

    return groups
end

GLOBAL.GetRegisteredChatEmoticons = GetRegisteredChatEmoticons

local function PushTextToken(tokens, text)
    if text ~= nil and text ~= "" then
        table.insert(tokens,
        {
            type = "text",
            value = text,
        })
    end
end

local function TryParseImageToken(raw, start_pos)
    local rest = raw:sub(start_pos)
    local group, name = rest:match("^:img/([a-z0-9_%-]+)/([a-z0-9_%-]+):")
    if group ~= nil then
        local token_raw = ":img/"..group.."/"..name..":"

        return
        {
            type = "image",
            group = group,
            name = name,
            raw = token_raw,
            next_pos = start_pos + #token_raw,
        }
    end

    name = rest:match("^:img/([a-z0-9_%-]+):")
    if name == nil then
        return nil
    end

    local token_raw = ":img/"..name..":"

    return
    {
        type = "image",
        group = DEFAULT_EMOTICON_GROUP,
        name = name,
        raw = token_raw,
        next_pos = start_pos + #token_raw,
    }
end

local function ParseRichChat(raw)
    local tokens = {}
    local i = 1
    local n = raw ~= nil and #raw or 0

    while i <= n do
        local start_pos = raw:find(":img/", i, true)
        if start_pos == nil then
            PushTextToken(tokens, raw:sub(i))
            break
        end

        if start_pos > 1 and raw:sub(start_pos - 1, start_pos - 1) == "\\" then
            PushTextToken(tokens, raw:sub(i, start_pos - 2))
            PushTextToken(tokens, ":img/")
            i = start_pos + 5
        else
            PushTextToken(tokens, raw:sub(i, start_pos - 1))

            local token = TryParseImageToken(raw, start_pos)
            if token ~= nil then
                table.insert(tokens,
                {
                    type = token.type,
                    group = token.group,
                    name = token.name,
                    raw = token.raw,
                })
                i = token.next_pos
            else
                PushTextToken(tokens, ":")
                i = start_pos + 1
            end
        end
    end

    return tokens
end

local function ContainsRichToken(raw)
    return type(raw) == "string" and raw:find(":img/", 1, true) ~= nil
end

local function FindFirstEmoticonSound(raw)
    if not ContainsRichToken(raw) then
        return nil
    end

    local tokens = ParseRichChat(raw)
    for _, token in ipairs(tokens) do
        if token.type == "image" then
            local def = _registry[MakeRegistryKey(token.group, token.name)]
            if def ~= nil and type(def.sound) == "string" and def.sound ~= "" then
                return def.sound
            end
        end
    end

    return nil
end

local function SplitTextForLayout(text)
    local out = {}
    local i = 1
    local len = #text

    while i <= len do
        local s, e = text:find("%s+", i)
        if s == i then
            table.insert(out, text:sub(s, e))
            i = e + 1
        elseif s ~= nil then
            table.insert(out, text:sub(i, s - 1))
            i = s
        else
            table.insert(out, text:sub(i))
            break
        end
    end

    return out
end

local function MeasureText(self, str)
    self._richchat_measure:SetString(str or "")
    return self._richchat_measure:GetRegionSize()
end

local function MeasureCharWrappedText(self, str, maxwidth)
    local parts = {}
    local current = ""

    for _, codepoint in utf8.codes(str) do
        local ch = utf8.char(codepoint)
        local probe = current .. ch
        if current ~= "" and MeasureText(self, probe) > maxwidth then
            table.insert(parts, current)
            current = ch
        else
            current = probe
        end
    end

    if current ~= "" then
        table.insert(parts, current)
    end

    return parts
end

local function BuildItems(self, message)
    local items = {}
    local tokens = ParseRichChat(message or "")

    for _, token in ipairs(tokens) do
        if token.type == "text" then
            local words = SplitTextForLayout(token.value)
            for _, word in ipairs(words) do
                local width = MeasureText(self, word)
                if width > self.message_width and not word:match("^%s+$") then
                    local chunks = MeasureCharWrappedText(self, word, self.message_width)
                    for _, chunk in ipairs(chunks) do
                        table.insert(items,
                        {
                            type = "text",
                            value = chunk,
                            width = MeasureText(self, chunk),
                        })
                    end
                else
                    table.insert(items,
                    {
                        type = "text",
                        value = word,
                        width = width,
                    })
                end
            end
        elseif token.type == "image" then
            local registry_key = MakeRegistryKey(token.group, token.name)
            local def = _registry[registry_key]
            if def ~= nil then
                table.insert(items,
                {
                    type = "image",
                    group = def.group,
                    name = def.name,
                    width = def.width,
                    height = def.height,
                    baseline = def.baseline or -2,
                })
            else
                table.insert(items,
                {
                    type = "text",
                    value = token.raw,
                    width = MeasureText(self, token.raw),
                })
            end
        end
    end

    return items
end

local function BuildLines(self, items)
    local lines = {}
    local current =
    {
        items = {},
        width = 0,
        height = CHAT_SIZE + CHAT_ROW_GAP,
    }

    local function PushLine()
        if #current.items > 0 then
            table.insert(lines, current)
        end
        current =
        {
            items = {},
            width = 0,
            height = CHAT_SIZE + CHAT_ROW_GAP,
        }
    end

    for _, item in ipairs(items) do
        local item_width = item.width or 0
        local would_overflow = #current.items > 0 and (current.width + item_width > self.message_width)

        if would_overflow then
            PushLine()
        end

        table.insert(current.items, item)
        current.width = current.width + item_width

        if item.type == "image" and item.height ~= nil then
            current.height = math.max(current.height, item.height + math.abs(item.baseline or 0) * 2 + CHAT_ROW_GAP)
        end
    end

    if #current.items > 0 then
        table.insert(lines, current)
    end

    if #lines == 0 then
        table.insert(lines,
        {
            items = {},
            width = 0,
            height = CHAT_SIZE + CHAT_ROW_GAP,
        })
    end

    return lines
end

local function ClearRichNodes(self)
    if self._richchat_nodes ~= nil then
        for _, node in ipairs(self._richchat_nodes) do
            node:Kill()
        end
    end
    self._richchat_nodes = {}
    self._richchat_content_height = CHAT_SIZE + CHAT_ROW_GAP
end

local function GetImageCenterY(line_center_y, def)
    local baseline = def.baseline or -2
    local valign = def.valign or "bottom"
    local image_height = def.height or CHAT_SIZE

    local text_top = line_center_y + CHAT_SIZE * 0.5
    local text_baseline = line_center_y - CHAT_SIZE * 0.5

    if valign == "top" then
        return text_top - image_height * 0.5 + baseline
    elseif valign == "middle" then
        return line_center_y + baseline
    end

    return text_baseline + image_height * 0.5 + baseline
end

local function RenderRichMessage(self, message, colour)
    ClearRichNodes(self)

    local lines
    if type(message) == "table" and message._richchat_lines ~= nil then
        lines = message._richchat_lines
    else
        local items = BuildItems(self, message)
        lines = BuildLines(self, items)
    end

    local total_height = 0
    for _, line in ipairs(lines) do
        total_height = total_height + line.height
    end
    self._richchat_content_height = total_height

    local y = total_height * 0.5 - lines[1].height * 0.5

    for _, line in ipairs(lines) do
        local line_root = self._richchat_root:AddChild(Widget("richchat_line"))
        table.insert(self._richchat_nodes, line_root)

        local x = -290

        for _, item in ipairs(line.items) do
            if item.type == "text" then
                local txt = line_root:AddChild(Text(self._richchat_font, CHAT_SIZE))
                txt:SetHAlign(GLOBAL.ANCHOR_LEFT)
                txt:SetString(item.value)
                txt:SetColour(unpack(colour))
                txt:SetPosition(x + item.width * 0.5, y)
                x = x + item.width
            else
                local def = _registry[MakeRegistryKey(item.group, item.name)]
                if def ~= nil then
                    local img = line_root:AddChild(Image(def.atlas, def.tex))
                    img:ScaleToSize(def.width, def.height)
                    img:SetPosition(x + def.width * 0.5, GetImageCenterY(y, def))
                    img:SetHoverText(MakeEmoticonCode(def.group, def.name), { offset_y = -40 })

                    if def.tint ~= nil then
                        img:SetTint(unpack(def.tint))
                    end

                    x = x + def.width
                end
            end
        end

        y = y - line.height
    end
end

local function InstallChatLine(self, chat_font)
    if self._richchat_installed then
        return
    end
    self._richchat_installed = true

    self._richchat_font = chat_font or GLOBAL.TALKINGFONT
    self._richchat_root = self.root:AddChild(Widget("richchat_root"))
    self._richchat_measure = self.root:AddChild(Text(self._richchat_font, CHAT_SIZE))
    self._richchat_measure:Hide()
    self._richchat_nodes = {}
    self._richchat_content_height = CHAT_SIZE + CHAT_ROW_GAP

    local base_set_chat_data = self.SetChatData
    local base_update_alpha = self.UpdateAlpha

    function self:GetRichContentHeight()
        return self._richchat_content_height or (CHAT_SIZE + CHAT_ROW_GAP)
    end

    function self:UpdateAlpha(alpha)
        base_update_alpha(self, alpha)

        if alpha <= 0 then
            return
        end

        for _, node in ipairs(self._richchat_nodes) do
            if node.children ~= nil then
                for _, child in ipairs(node.children) do
                    if child.UpdateAlpha ~= nil then
                        child:UpdateAlpha(alpha)
                    elseif child.SetTint ~= nil then
                        child:SetTint(1, 1, 1, alpha)
                    end
                end
            end
        end
    end

    function self:SetChatData(type, alpha, message, m_colour, sender, s_colour, icondata, icondatabg)
        base_set_chat_data(self, type, alpha, "", m_colour, sender, s_colour, icondata, icondatabg)

        if alpha <= 0 then
            self._richchat_root:Hide()
            ClearRichNodes(self)
            return
        end

        if type == GLOBAL.ChatTypes.SkinAnnouncement then
            self._richchat_root:Hide()
            ClearRichNodes(self)
            return
        end

        self._richchat_root:Show()
        self.message:Hide()

        local r, g, b = unpack(m_colour)
        RenderRichMessage(self, message, { r, g, b, alpha })
    end
end

local function InstallChatQueue(self)
    if self._richchat_queue_installed then
        return
    end
    self._richchat_queue_installed = true

    function self:RelayoutRichChatRows()
        local y = CHAT_BOTTOM_Y

        for i = 1, CHAT_QUEUE_SIZE do
            local row = self.widget_rows[i]
            local height = row ~= nil and row.GetRichContentHeight ~= nil
                and row:GetRichContentHeight()
                or (self.chat_size + CHAT_ROW_GAP)

            row:SetPosition(0, y)
            y = y + height
        end
    end
    local _RefreshWidgets = self.RefreshWidgets
    function self:RefreshWidgets(full_update)
        _RefreshWidgets(self, full_update)
        if full_update then
            self:RelayoutRichChatRows()
        end
    end
end

local function InstallScrollableChatQueue(self)
    if self._richchat_scroll_installed then
        return
    end
    self._richchat_scroll_installed = true

    self._richchat_measure = self._richchat_measure or self:AddChild(Text(self.chat_font or GLOBAL.TALKINGFONT, CHAT_SIZE))
    self._richchat_measure:Hide()

    local function GetRichLayoutForMessage(message_data)
        if message_data == nil then
            return nil
        end

        local layout = message_data._richchat_layout
        if layout == nil
            or layout.registry_revision ~= _registry_revision
            or layout.message_width ~= self.message_width
            or layout.message ~= message_data.message then
            local items = BuildItems(self, message_data.message)
            local lines = BuildLines(self, items)
            layout =
            {
                message = message_data.message,
                message_width = self.message_width,
                registry_revision = _registry_revision,
                lines = lines,
            }
            message_data._richchat_layout = layout
        end

        return layout
    end

    local function GetHistoryMessage(history_index)
        if history_index == GLOBAL.ChatHistory.MAX_CHAT_HISTORY + 1 then
            return GLOBAL.ChatHistory:GetLastDeletedChatMessage()
        end
        return GLOBAL.ChatHistory:GetChatMessageAtIndex(history_index)
    end

    local base_get_chat_lines_for_message = self.GetChatLinesForMessage
    function self:GetChatLinesForMessage(history_index)
        local message_data = GetHistoryMessage(history_index)
        if message_data == nil then
            return base_get_chat_lines_for_message ~= nil and base_get_chat_lines_for_message(self, history_index) or nil
        end

        if not ContainsRichToken(message_data.message) then
            return base_get_chat_lines_for_message ~= nil and base_get_chat_lines_for_message(self, history_index) or nil
        end

        local layout = GetRichLayoutForMessage(message_data)
        return layout ~= nil and #layout.lines or nil
    end

    local function ApplyScrollRowLayout()
        if self.chat_scroll_list == nil then
            return
        end

        local row_height = math.max(self.chat_size + 2, _max_rich_line_height)
        local scissor_height = row_height * CHAT_SCROLL_VISUAL_SIZE + 6
        local chat_queue_offset = (CHAT_SCROLL_VISUAL_SIZE * row_height) / 2
        local chat_line_offset = -chat_queue_offset

        self.chat_scroll_list.row_height = row_height
        self.chat_scroll_list.scissor_height = scissor_height
        self.chat_scroll_list.scissored_root:SetScissor(-1050 / 2, -(scissor_height) / 2 - row_height * 0.5, 1050, scissor_height)
        self.chat_scroll_list:SetPosition(35, -624 + chat_queue_offset)

        for i, chatline in ipairs(self.widget_rows) do
            chatline:SetPosition(-35, chat_line_offset + (i - 1) * row_height)
        end
    end

    if self.chat_scroll_list ~= nil then
        local base_generate_data_fn = self.chat_scroll_list.generate_data_fn
        self.chat_scroll_list.generate_data_fn = function(current_scroll_pos)
            local function HasRichMessagesNearCurrentView()
                local minimum_line = math.abs(current_scroll_pos) + 1
                local current_line = 1
                local history_index = 1

                while current_line < minimum_line + CHAT_SCROLL_VISUAL_SIZE do
                    local message_data = GLOBAL.ChatHistory:GetChatMessageAtIndex(history_index)
                    if message_data == nil then
                        return false
                    end

                    if ContainsRichToken(message_data.message) then
                        return true
                    end

                    local next_message = base_get_chat_lines_for_message ~= nil and base_get_chat_lines_for_message(self, history_index) or nil
                    if not next_message then
                        return false
                    end

                    current_line = current_line + next_message
                    history_index = history_index + 1
                end

                return false
            end

            if not HasRichMessagesNearCurrentView() then
                return base_generate_data_fn ~= nil and base_generate_data_fn(current_scroll_pos) or nil
            end

            if self.last_scroll_pos == current_scroll_pos and not self.history_updated then
                return
            end
            self.last_scroll_pos = current_scroll_pos

            local current_chat_data = {}

            local minimum_line = math.abs(current_scroll_pos) + 1
            local current_line = 1
            local history_index = 1
            local chatlines_to_skip = 0

            while current_line < minimum_line do
                local next_message = self:GetChatLinesForMessage(history_index)
                if not next_message then
                    break
                end

                chatlines_to_skip = current_line - minimum_line
                current_line = current_line + next_message

                if current_line <= minimum_line then
                    history_index = history_index + 1
                end
            end

            if current_line < minimum_line then
                return current_chat_data
            elseif current_line == minimum_line then
                chatlines_to_skip = 0
            end

            local i = 1
            while i <= CHAT_SCROLL_VISUAL_SIZE + 1 do
                local message_data = GLOBAL.ChatHistory:GetChatMessageAtIndex(history_index)

                if message_data then
                    if not ContainsRichToken(message_data.message) then
                        local fallback = base_generate_data_fn ~= nil and base_generate_data_fn(current_scroll_pos) or nil
                        if fallback ~= nil then
                            return fallback
                        end
                    end

                    local layout = GetRichLayoutForMessage(message_data)
                    local lines = layout ~= nil and layout.lines or nil

                    if lines ~= nil then
                        for j = #lines + chatlines_to_skip, 1, -1 do
                            local first = j == 1
                            if i <= CHAT_SCROLL_VISUAL_SIZE + 1 then
                                current_chat_data[i] =
                                {
                                    history_index = history_index,
                                    type = message_data.type,
                                    message = { _richchat_lines = { lines[j] } },
                                    m_colour = message_data.m_colour,
                                    sender = first and message_data.sender or nil,
                                    s_colour = first and message_data.s_colour or nil,
                                    icondata = first and message_data.icondata or nil,
                                    icondatabg = first and message_data.icondatabg or nil,
                                }
                            end
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                else
                    i = i + 1
                end

                chatlines_to_skip = 0
                history_index = history_index + 1
            end

            return current_chat_data
        end
    end

    local base_refresh_widgets = self.RefreshWidgets
    function self:RefreshWidgets(force_update)
        ApplyScrollRowLayout()
        base_refresh_widgets(self, force_update)
    end

    self:RefreshWidgets(true)
end

local function InstallChatInputScreen(self)
    if self._richchat_input_installed then
        return
    end
    self._richchat_input_installed = true

    local base_on_become_active = self.OnBecomeActive
    function self:OnBecomeActive()
        base_on_become_active(self)
        if self.networkchatqueue ~= nil and self.networkchatqueue.RefreshWidgets ~= nil then
            self.networkchatqueue:RefreshWidgets(true)
        end
    end
end

local function GetTalkerMessage(script)
    if type(script) == "string" then
        return script
    end
    if type(script) == "table" then
        return script.message
    end
end

AddPlayerPostInit(function(inst)
    if inst._richchat_talker_say_hooked then
        return
    end

    local talker = inst.components.talker
    if talker == nil then
        return
    end

    inst._richchat_talker_say_hooked = true

    local base_say = talker.Say
    function talker:Say(script, ...)
        local message = GetTalkerMessage(script)
        if ContainsRichToken(message) then
            return
        end
        return base_say(self, script, ...)
    end
end)

local _OnSay = ChatHistory.OnSay
function ChatHistory:OnSay(guid, userid, netid, name, prefab, message, ...)
    local sound = FindFirstEmoticonSound(message)
    if sound ~= nil then
        TheFrontEnd:GetSound():PlaySound(sound)
    end
    _OnSay(self, guid, userid, netid, name, prefab, message, ...)
end

AddClassPostConstruct("widgets/redux/chatline", InstallChatLine)

AddClassPostConstruct("widgets/redux/chatqueue", InstallChatQueue)

AddClassPostConstruct("widgets/redux/scrollablechatqueue", InstallScrollableChatQueue)

AddClassPostConstruct("screens/chatinputscreen", InstallChatInputScreen)

local inner_emotions = require('emoticons')
for _, emotion in ipairs(inner_emotions) do
    RegisterChatEmoticon(emotion)
end
