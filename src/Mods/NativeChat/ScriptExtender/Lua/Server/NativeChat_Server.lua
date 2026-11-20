local CFG = Ext.Require("Shared/NativeChat_Config.lua")
local Net = Ext.Require("Shared/NativeChat_Net.lua")

local MSG_RECEIVED_EVENT = "NC_MessageReceived"

local users = {}

local function _user_id(user)
    local n = tonumber(user)
    if n and n % 65536 == 0 then return n + 1 end
    return n
end

local last_message_by_user = {}

local function _current_character(user)
    local ok, character = pcall(function() return Osi.GetCurrentCharacter(user) end)
    if ok then return character end
    return nil
end

local function _character_name(character)
    local name = nil
    pcall(function()
        local entity = Ext.Entity.Get(character)
        local names = entity and entity.ServerDisplayNameList and entity.ServerDisplayNameList.Names
        if names and #names >= 2 and names[2].Name then
            name = names[2].Name
        elseif names and #names >= 1 and names[1].NameKey then
            local translated = Ext.Loca.GetTranslatedString(names[1].NameKey.Handle.Handle)
            if translated ~= "" and translated ~= "Player" and translated ~= "Dummy" then
                name = translated
            end
        end
    end)

    return name
end

local name_cache = {}

local function _speaker(user)
    local character = _current_character(user)
    local cached = name_cache[user]
    if cached and cached.character == character then
        return cached.name, character
    end
    local name = character and _character_name(character)
    if not name or name == "" then name = GetUserName(user) end
    name = tostring(name or "")
    name_cache[user] = { character = character, name = name }
    return name, character
end

local function _text_length(text)
    if utf8 and utf8.len then
        local n = utf8.len(text)
        if n then return n end
    end
    return #text
end

local function _load_history()
    local vars = Ext.Vars.GetModVariables(ModuleUUID)
    local history = vars[Net.HISTORY_VAR]
    if type(history) ~= "table" or type(history.items) ~= "table" then
        history = { next_id = 1, items = {} }
    end
    history.next_id = tonumber(history.next_id) or 1
    return history, vars
end

local function _store_history(history, vars)
    local items = history.items
    local total = 0
    for _, item in ipairs(items) do total = total + _text_length(item.body or "") end
    while #items > 0 and (#items > CFG.HistoryMaxMessages or total > CFG.HistoryMaxChars) do
        local removed = table.remove(items, 1)
        total = total - _text_length(removed.body or "")
    end
    vars[Net.HISTORY_VAR] = history
end

local function _show_overhead(character, body, roll)
    if not character then return end
    Net.Overhead:Broadcast({ body = tostring(body or ""), roll = roll })
    Ext.Timer.WaitForRealtime(200, function()
        pcall(function() Osi.ApplyStatus(character, "NATIVECHAT_MESSAGE", 0) end)
    end)
end

local function _strip_ooc(body)
    return (body:gsub("%b()", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

Net.Message:SetHandler(function(data, user)
    user = _user_id(user)
    users[user] = true
    local body = data and data.body
    if type(body) ~= "string" or body == "" then return end

    local name, character = _speaker(user)
    local history, vars = _load_history()
    local id = history.next_id
    history.next_id = id + 1
    local message = { id = id, name = name, body = body }
    table.insert(history.items, message)
    _store_history(history, vars)
    Net.Message:Broadcast(message)
    Net.Ack:SendToClient({ id = id, body = body }, user)
    last_message_by_user[user] = id

    local overhead = _strip_ooc(body)
    if overhead ~= "" then _show_overhead(character, overhead) end

    IteratePlayerCharacters(MSG_RECEIVED_EVENT, "")
end)

Net.Edit:SetHandler(function(data, user)
    user = _user_id(user)
    users[user] = true
    local id = tonumber(data and data.id)
    local body = data and data.body
    if not id or type(body) ~= "string" or body == "" then return end
    if last_message_by_user[user] ~= id then return end

    local history, vars = _load_history()
    for i = #history.items, 1, -1 do
        local item = history.items[i]
        if item.id == id then
            item.body = body
            item.edited = true
            _store_history(history, vars)
            break
        end
    end

    Net.Edit:Broadcast({ id = id, body = body })
end)

Net.Typing:SetHandler(function(data, user)
    user = _user_id(user)
    users[user] = true
    local name = _speaker(user)
    local payload = { name = name, on = (data and data.on) and true or false }
    for other in pairs(users) do
        if other ~= user then
            pcall(function() Net.Typing:SendToClient(payload, other) end)
        end
    end
end)

Net.History:SetRequestHandler(function(_, user)
    user = _user_id(user)
    users[user] = true
    local history = _load_history()
    return { items = history.items }
end)

local ROLL_EVENT_PREFIX = "NC_DiceRoll_"
local pending_rolls = {}
local next_roll_id = 1

Net.Roll:SetHandler(function(data, user)
    user = _user_id(user)
    users[user] = true
    if type(data) ~= "table" then return end
    local _, character = _speaker(user)
    if not character then return end

    local def
    if data.kind == "skill" then
        def = CFG.DiceSkillById[data.id]
    elseif data.kind == "ability" then
        def = CFG.DiceAbilityById[data.id]
    end
    local tier = CFG.DiceTierById[data.tier]
    local roll_type = CFG.DiceRollTypeSet[data.rollType] and data.rollType or "active"
    if not def or not tier then return end

    if not tier.guid then CFG.ResolveDiceDifficultyClasses() end
    if not tier.guid then
        Ext.Utils.PrintWarning("[Native Chat] Dice: no DifficultyClass available for DC " .. tostring(tier.dc))
        Net.System:SendToClient({ key = "dice.noDifficultyClass" }, user)
        return
    end

    local event_name = ROLL_EVENT_PREFIX .. tostring(next_roll_id)
    next_roll_id = next_roll_id + 1

    local advantage = data.adv and 1 or 0
    local osi_roll_type = (data.kind == "skill") and "SkillCheck" or "RawAbility"

    pending_rolls[event_name] = {
        character = character,
        kind = data.kind,
        id = def.id,
        active = roll_type == "active",
    }

    local ok, err = pcall(function()
        if roll_type == "active" then
            Osi.RequestActiveRoll(character, character, osi_roll_type, def.id, tier.guid, advantage, event_name)
        else
            Osi.RequestPassiveRoll(character, character, osi_roll_type, def.id, tier.guid, advantage, event_name)
        end
    end)

    if not ok then
        pending_rolls[event_name] = nil
        Ext.Utils.PrintWarning("[Native Chat] Dice: roll request failed: " .. tostring(err))
        return
    end

    Ext.Timer.WaitForRealtime(CFG.DicePendingRollTimeoutMs, function()
        pending_rolls[event_name] = nil
    end)
end)

local function _on_roll_result(event_name, roller, roll_subject, result_type, is_active_roll, criticality)
    local p = pending_rolls[event_name]
    if not p then return end
    pending_rolls[event_name] = nil

    local result = tonumber(result_type) or 0
    if p.active and result ~= 2 then
        _show_overhead(p.character, nil, {
            kind = p.kind, id = p.id, result = result, crit = tonumber(criticality) or 0,
        })
    end
end

local function _on_user_connected(user, user_name)
    users[user] = true
    Net.System:Broadcast({ key = "chat.joined", name = tostring(user_name) })
end

local function _on_user_disconnected(user, user_name)
    users[user] = nil
    name_cache[user] = nil
    last_message_by_user[user] = nil
    Net.System:Broadcast({ key = "chat.left", name = tostring(user_name) })
end

local function _on_entity_event(object, event)
    if event == MSG_RECEIVED_EVENT and IsCharacter(object) ~= 0 then
        PlayHUDSound(object, "UI_HUD_SplitItem_Cancel_Press")
    end
end

Ext.Events.SessionLoaded:Subscribe(function() CFG.ResolveDiceDifficultyClasses() end)

Ext.Osiris.RegisterListener("RollResult", 6, "after", _on_roll_result)
Ext.Osiris.RegisterListener("EntityEvent", 2, "after", _on_entity_event)
Ext.Osiris.RegisterListener("UserConnected", 3, "after", _on_user_connected)
Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", _on_user_disconnected)
