if not Ext.IsClient() then
    return
end

if _G.__NATIVECHAT_MAIN_LOADED then
    return
end

local ok_init, init_err = pcall(function()
    local S = Ext.Require("Client/NativeChat_State.lua")
    S.chat = Ext.Require("Client/NativeChat_Chat.lua")
    S.view = Ext.Require("Client/NativeChat_View.lua")
    S.dice = Ext.Require("Client/NativeChat_Dice.lua")
    S.settings_ui = Ext.Require("Client/NativeChat_Settings.lua")
    local CFG = S.CFG

    Ext.Events.Tick:Subscribe(function(_)
        S.run_main_queue()
        if S.chat.prune_typing_users() then S.refresh() end

        local s = S.settings
        local can_hide = S.in_game and not S.game_ui_hidden and s.auto_hide and S.active_tab == "chat"
            and not S.dice_visible and not S.listening_for_open_key and next(S.typing_users) == nil
            and not S.view.is_resizing()
        if can_hide then
            local idle_seconds = (Ext.Utils.MonotonicTime() - S.last_activity_ms) / 1000.0
            local should_hide = (not S.input_active) and (not S.mouse_over_panel)
                and S.clean_input(S.input_text) == "" and (idle_seconds > CFG.AutoHideDelaySeconds)
            if should_hide and not S.chat_hidden_by_idle then
                S.chat_hidden_by_idle = true
                S.refresh()
            end
        elseif S.chat_hidden_by_idle then
            S.chat_hidden_by_idle = false
            S.refresh()
        end
    end)

    Ext.Events.MouseButtonInput:Subscribe(function(event)
        if event.Pressed and S.input_active and not S.mouse_over_panel and not S.view.is_resizing() then
            S.view.release_focus()
        end
    end)

    local se_ctrl_down = false
    local SE_CTRL = { LCTRL = true, RCTRL = true }
    local SELECT_ALL_KEYS = { A = true, Q = true }

    Ext.Events.KeyInput:Subscribe(function(event)
        local keyName = tostring(event.Key)
        if SE_CTRL[keyName] then se_ctrl_down = event.Pressed and true or false end

        if event.Pressed and S.input_active and SELECT_ALL_KEYS[keyName] and (se_ctrl_down or S.view.ctrl_held()) then
            S.view.select_all_in_input()
            return
        end

        if not S.in_game or S.game_ui_hidden then return end
        if not event.Pressed or event.Repeat then return end

        if S.listening_for_open_key then
            S.settings_ui.set_open_key(keyName)
            return
        end

        if keyName == S.settings.open_key and not S.input_active then
            S.view.focus_input()
        end
    end)

    local Net = Ext.Require("Shared/NativeChat_Net.lua")
    local function relay(kind)
        return function(data)
            if type(data) ~= "table" then return end
            data.t = kind
            S.chat.on_net_message(data)
        end
    end
    Net.Message:SetHandler(relay("msg"))
    Net.Edit:SetHandler(relay("edit"))
    Net.Ack:SetHandler(relay("ack"))
    Net.System:SetHandler(relay("system"))
    Net.Typing:SetHandler(relay("typing"))
    Net.Overhead:SetHandler(relay("oht"))
    Ext.Events.GameStateChanged:Subscribe(function(event)
        if event.ToState == "PrepareRunning" then
            S.load_settings()
            S.game_ui_hidden = false
            S.settings_loaded = true
            S.dice.on_language()
            S.chat.mark_dirty()
        elseif event.ToState == "Running" then
            if not S.in_game then
                S.in_game = true
                S.touch_activity()
                NC_RequestHistory(function(items) S.chat.load_history(items) end)
            end
        elseif event.ToState == "UnloadLevel" then
            S.in_game = false
            if S.settings_loaded then S.save_settings() end
            S.dice_visible = false
            S.listening_for_open_key = false
            S.input_active = false
            S.mouse_over_panel = false
            S.game_ui_hidden = true
            S.editing_message_id = nil
            S.cached_draft_text = nil
            S.typing_users = {}
            S.refresh()
        end
    end)

    Ext.Events.SessionLoaded:Subscribe(function()
        S.view.start()
    end)
end)

if not ok_init then
    Ext.Utils.Print("[Native Chat] Init failed: " .. tostring(init_err))
    return
end

_G.__NATIVECHAT_MAIN_LOADED = true
