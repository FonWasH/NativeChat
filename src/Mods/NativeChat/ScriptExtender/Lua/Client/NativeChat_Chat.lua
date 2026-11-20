local S = Ext.Require("Client/NativeChat_State.lua")
local CFG = S.CFG

local C = {}

local function _trim_old_messages()
    local overflow = #S.chat_messages - CFG.MaxKeptMessages
    for _ = 1, overflow do
        local rec = table.remove(S.chat_messages, 1)
        if rec and rec.id ~= nil then S.chat_messages_by_id[rec.id] = nil end
    end
end

function C.mark_dirty()
    if S.view then S.view.messages_dirty = true end
    S.refresh()
end

function C.add_entry(id, name, rawBody, kind, extra)
    local rec = {
        uid = S.next_uid,
        id = id, name = name, raw = rawBody, kind = kind, edited = false,
        addedAtMs = Ext.Utils.MonotonicTime(),
    }
    S.next_uid = S.next_uid + 1
    if extra then
        for k, v in pairs(extra) do rec[k] = v end
    end
    table.insert(S.chat_messages, rec)
    if id ~= nil then S.chat_messages_by_id[id] = rec end

    if S.active_tab ~= "chat" then S.unread = S.unread + 1 end

    _trim_old_messages()
    S.touch_activity()
    C.mark_dirty()
    return rec
end

function C.load_history(items)
    if type(items) ~= "table" or #items == 0 then return end
    local older = {}
    for _, item in ipairs(items) do
        local id = tonumber(item.id)
        if id and not S.chat_messages_by_id[id] and type(item.body) == "string" then
            local rec = {
                uid = S.next_uid,
                id = id, name = item.name, raw = item.body, kind = "msg", edited = item.edited == true,
                addedAtMs = 0,
            }
            S.next_uid = S.next_uid + 1
            table.insert(older, rec)
            S.chat_messages_by_id[id] = rec
        end
    end
    if #older == 0 then return end
    for i = #older, 1, -1 do table.insert(S.chat_messages, 1, older[i]) end
    _trim_old_messages()
    C.mark_dirty()
end

function C.edit_entry(id, newBody)
    local rec = S.chat_messages_by_id[id]
    if not rec then return end
    rec.raw = newBody
    rec.edited = true
    S.touch_activity()
    C.mark_dirty()
end

local last_typing_sent_ms = -999999
local last_typing_state_sent = false

local function _send_typing_now(on)
    if on then
        local now = Ext.Utils.MonotonicTime()
        if (now - last_typing_sent_ms) > (CFG.TypingBroadcastThrottleSeconds * 1000) or not last_typing_state_sent then
            NC_SendTyping(true)
            last_typing_sent_ms = now
            last_typing_state_sent = true
        end
    elseif last_typing_state_sent then
        NC_SendTyping(false)
        last_typing_state_sent = false
    end
end

function C.send_typing(on)
    S.on_main(function() _send_typing_now(on) end)
end

function C.prune_typing_users()
    local now = Ext.Utils.MonotonicTime()
    local changed = false
    for name, expiry in pairs(S.typing_users) do
        if now > expiry then
            S.typing_users[name] = nil
            changed = true
        end
    end
    if changed and next(S.typing_users) == nil then S.touch_activity() end
    return changed
end

function C.typing_text()
    local names = {}
    for name, _ in pairs(S.typing_users) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then return "" end
    if #names == 1 then return S.T("status.typing", names[1]) end
    return S.T("status.several")
end

function C.on_input_value(value, own)
    S.input_text = tostring(value or "")
    if not own then
        S.touch_activity()
        C.send_typing(S.input_text ~= "")
    end
    S.refresh()
end

local function _set_input(text)
    if S.view then S.view.set_input_text(text) else S.input_text = text or "" end
end

local function _set_editing(id)
    S.editing_message_id = id
    S.refresh()
end

function C.cancel_edit()
    if S.editing_message_id == nil then return end
    _set_editing(nil)
    local restored = S.cached_draft_text or ""
    S.cached_draft_text = nil
    _set_input(restored)
    C.send_typing(false)
    S.touch_activity()
end

function C.begin_edit_last_message(force)
    local last = S.my_last_message
    if not (last and last.id) then return end

    local current = S.input_text or ""
    if not force then
        if S.clean_input(current) ~= "" then return end
    elseif S.editing_message_id == nil and S.clean_input(current) ~= "" then
        S.cached_draft_text = current
    end

    _set_editing(last.id)
    _set_input(last.text)
    S.touch_activity()
    if force and S.view then S.view.focus_input() end
end

function C.toggle_edit()
    if S.editing_message_id ~= nil then C.cancel_edit() else C.begin_edit_last_message(true) end
end

function C.submit()
    local text = S.clean_input(S.input_text)
    local release = function() if S.view then S.view.release_focus() end end

    if S.editing_message_id ~= nil then
        if text == "" or (S.my_last_message and text == S.my_last_message.text) then
            C.cancel_edit()
            if S.clean_input(S.input_text) == "" then release() end
            return
        end
        NC_SendEdit(S.editing_message_id, text)
        _set_editing(nil)
    else
        if text == "" then
            _set_input("")
            release()
            return
        end
        NC_SendMessage(text)
    end

    local restored = S.cached_draft_text
    S.cached_draft_text = nil
    _set_input(restored or "")
    if not restored then release() end

    C.send_typing(false)
    S.touch_activity()
end

function C.on_net_message(data)
    if data.t == "msg" then
        C.add_entry(data.id, data.name, data.body, "msg")
    elseif data.t == "edit" then
        C.edit_entry(data.id, data.body)
        if S.my_last_message and S.my_last_message.id == data.id then
            S.my_last_message = { id = data.id, text = data.body }
        end
    elseif data.t == "system" then
        if data.key then
            C.add_entry(nil, nil, nil, "system", { key = data.key, arg = data.name })
        end
    elseif data.t == "ack" then
        S.my_last_message = { id = data.id, text = data.body }
    elseif data.t == "typing" then
        if data.name and data.name ~= "" then
            if data.on then
                if S.typing_users[data.name] == nil then S.touch_activity() end
                S.typing_users[data.name] = Ext.Utils.MonotonicTime() + (CFG.TypingIndicatorTimeoutSeconds * 1000)
            else
                S.typing_users[data.name] = nil
                if next(S.typing_users) == nil then S.touch_activity() end
            end
            S.refresh()
        end
    elseif data.t == "oht" then
        local body = data.body or ""
        if type(data.roll) == "table" then body = NC_FormatRollOverhead(data.roll) end
        local text = S.settings.overhead_text and body or " "
        if text == "" then text = " " end
        pcall(function() Ext.Loca.UpdateTranslatedString(MSG_BUFFER_HANDLE, text) end)
    end
end

return C
