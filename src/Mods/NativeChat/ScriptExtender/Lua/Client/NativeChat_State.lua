if _G.__NATIVECHAT_STATE then
    return _G.__NATIVECHAT_STATE
end

local CFG = Ext.Require("Shared/NativeChat_Config.lua")
local Lang = Ext.Require("Shared/NativeChat_Lang.lua")

local S = {
    CFG = CFG,
    T = Lang.T,

    DESIGN_W = 3840,
    DESIGN_H = 2160,

    settings = {
        active_alpha = CFG.DefaultActiveAlpha,
        inactive_alpha = CFG.DefaultInactiveAlpha,
        font_size = CFG.DefaultFontSize,
        open_key = CFG.DefaultOpenKey,
        auto_hide = CFG.DefaultAutoHideEnabled,
        overhead_text = CFG.DefaultOverheadTextEnabled,
    },
    settings_loaded = false,

    in_game = false,
    game_ui_hidden = false,
    chat_hidden_by_idle = false,
    dice_visible = false,
    listening_for_open_key = false,

    panel = { x = 0, y = 0, w = CFG.DefaultPanelW, h = CFG.DefaultPanelH },
    dice_panel = { x = 0, y = 0, w = CFG.DicePanelW, h = CFG.DefaultPanelH },
    active_tab = "chat",
    unread = 0,

    input_active = false,
    input_text = "",
    mouse_over_panel = false,
    editing_message_id = nil,
    my_last_message = nil,
    cached_draft_text = nil,

    chat_messages = {},
    chat_messages_by_id = {},
    next_uid = 1,
    typing_users = {},
    last_activity_ms = 0,

    screen_w = 1920,
    screen_h = 1080,
    canvas_w = 3840,
    canvas_h = 2160,

    main_queue = {},
}

function S.log(text)
    Ext.Utils.Print("[Native Chat] " .. tostring(text))
end

function S.on_main(fn)
    table.insert(S.main_queue, fn)
end

function S.run_main_queue()
    if #S.main_queue == 0 then return end
    local queue = S.main_queue
    S.main_queue = {}
    for _, fn in ipairs(queue) do
        local ok, err = pcall(fn)
        if not ok then S.log("Main thread task error: " .. tostring(err)) end
    end
end

function S.refresh()
    if S.view then S.view.refresh() end
end

function S.show_chat()
    local hud = (S.native_hud_visible ~= false) or S.in_dialog
    return S.in_game and hud and (not S.game_ui_hidden) and (not S.ui_state_hidden) and (not S.chat_hidden_by_idle)
end

function S.touch_activity()
    S.last_activity_ms = Ext.Utils.MonotonicTime()
    if S.chat_hidden_by_idle then
        S.chat_hidden_by_idle = false
        S.refresh()
    end
end

function S.clean_input(text)
    return ((text or ""):gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function S.save_settings()
    if not S.settings_loaded then return end
    local s = S.settings
    NC_SaveWindowSettings({
        PanelW = S.panel.w,
        PanelH = S.panel.h,
        FontSize = s.font_size,
        ActiveAlpha = s.active_alpha,
        InactiveAlpha = s.inactive_alpha,
        OpenKey = s.open_key,
        AutoHideEnabled = s.auto_hide,
        OverheadTextEnabled = s.overhead_text,
    })
end

function S.load_settings()
    local saved = NC_LoadWindowSettings() or {}
    local s = S.settings

    S.panel.w = tonumber(saved.PanelW) or CFG.DefaultPanelW
    S.panel.h = tonumber(saved.PanelH) or CFG.DefaultPanelH

    s.font_size = tonumber(saved.FontSize) or CFG.DefaultFontSize
    s.active_alpha = tonumber(saved.ActiveAlpha) or CFG.DefaultActiveAlpha
    s.inactive_alpha = tonumber(saved.InactiveAlpha) or CFG.DefaultInactiveAlpha
    s.open_key = tostring(saved.OpenKey or CFG.DefaultOpenKey):upper()
    if saved.AutoHideEnabled ~= nil then s.auto_hide = saved.AutoHideEnabled end
    if saved.OverheadTextEnabled ~= nil then s.overhead_text = saved.OverheadTextEnabled end
end

_G.__NATIVECHAT_STATE = S

return S
