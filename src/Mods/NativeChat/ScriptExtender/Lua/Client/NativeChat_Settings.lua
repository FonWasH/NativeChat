local S = Ext.Require("Client/NativeChat_State.lua")
local CFG = S.CFG

local St = {}

local function _changed()
    S.touch_activity()
    S.refresh()
    S.save_settings()
end

function St.toggle_auto_hide()
    S.settings.auto_hide = not S.settings.auto_hide
    _changed()
end

function St.toggle_overhead()
    S.settings.overhead_text = not S.settings.overhead_text
    if not S.settings.overhead_text then
        pcall(function() Ext.Loca.UpdateTranslatedString(MSG_BUFFER_HANDLE, " ") end)
    end
    _changed()
end

function St.change_font_size(steps)
    local s = S.settings
    s.font_size = math.max(CFG.MinFontSize, math.min(CFG.MaxFontSize, s.font_size + steps * CFG.FontSizeStep))
    _changed()
end

function St.change_alpha(which, steps)
    local s = S.settings
    local v = (tonumber(s[which]) or 1) + steps * CFG.AlphaStep
    v = math.floor(v / CFG.AlphaStep + 0.5) * CFG.AlphaStep
    s[which] = math.max(CFG.MinAlpha, math.min(1.0, v))
    _changed()
end

function St.start_key_listen()
    S.listening_for_open_key = not S.listening_for_open_key
    if S.listening_for_open_key and S.input_active and S.view then S.view.release_focus() end
    S.touch_activity()
    S.refresh()
end

function St.set_open_key(key)
    S.listening_for_open_key = false
    if key and key ~= "" and key ~= "ESCAPE" then
        S.settings.open_key = key
    end
    _changed()
end

local KEY_NAMES = {
    RETURN = "Enter", KP_ENTER = "Num Enter", SPACE = "Space", TAB = "Tab",
    BACKSPACE = "Backspace", GRAVE = "`", SLASH = "/", BACKSLASH = "\\",
    SEMICOLON = ";", APOSTROPHE = "'", COMMA = ",", PERIOD = ".",
}

function St.key_label()
    local key = tostring(S.settings.open_key or "")
    return KEY_NAMES[key] or key
end

return St
