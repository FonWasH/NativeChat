local WINDOW_SETTINGS_PATH = "Data/NativeChat_Settings.json"

MSG_BUFFER_HANDLE = "h320893b3g50a1g47cfg99a1ge5d15edb94e8"

local CFG = Ext.Require("Shared/NativeChat_Config.lua")
local Lang = Ext.Require("Shared/NativeChat_Lang.lua")
local Net = Ext.Require("Shared/NativeChat_Net.lua")

local function _safe_number(v, default)
    v = tonumber(v)
    if v == nil then return default end
    return v
end

local function _safe_bool(v, default)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        v = v:lower()
        if v == "true" or v == "1" then return true end
        if v == "false" or v == "0" then return false end
    end
    return default
end

local function _safe_string(v, default)
    if type(v) == "string" and v ~= "" then return v end
    return default
end

function NC_SaveWindowSettings(save_data)
    local cached_settings = {
        PanelW = _safe_number(save_data.PanelW, CFG.DefaultPanelW),
        PanelH = _safe_number(save_data.PanelH, CFG.DefaultPanelH),
        FontSize = _safe_number(save_data.FontSize, CFG.DefaultFontSize),

        ActiveAlpha = _safe_number(save_data.ActiveAlpha, CFG.DefaultActiveAlpha),
        InactiveAlpha = _safe_number(save_data.InactiveAlpha, CFG.DefaultInactiveAlpha),

        OpenKey = _safe_string(save_data.OpenKey, CFG.DefaultOpenKey),
        AutoHideEnabled = _safe_bool(save_data.AutoHideEnabled, CFG.DefaultAutoHideEnabled),
        OverheadTextEnabled = _safe_bool(save_data.OverheadTextEnabled, CFG.DefaultOverheadTextEnabled),
    }

    Ext.IO.SaveFile(WINDOW_SETTINGS_PATH, Ext.Json.Stringify(cached_settings))
end

function NC_LoadWindowSettings()
    local raw = Ext.IO.LoadFile(WINDOW_SETTINGS_PATH)
    local save_data = Ext.Json.Parse(raw or "{}")
    if type(save_data) ~= "table" then save_data = {} end

    save_data.PanelW = _safe_number(save_data.PanelW, CFG.DefaultPanelW)
    save_data.PanelH = _safe_number(save_data.PanelH, CFG.DefaultPanelH)
    save_data.FontSize = _safe_number(save_data.FontSize, CFG.DefaultFontSize)
    save_data.ActiveAlpha = _safe_number(save_data.ActiveAlpha, CFG.DefaultActiveAlpha)
    save_data.InactiveAlpha = _safe_number(save_data.InactiveAlpha, CFG.DefaultInactiveAlpha)
    save_data.OpenKey = _safe_string(save_data.OpenKey, CFG.DefaultOpenKey)
    save_data.AutoHideEnabled = _safe_bool(save_data.AutoHideEnabled, CFG.DefaultAutoHideEnabled)
    save_data.OverheadTextEnabled = _safe_bool(save_data.OverheadTextEnabled, CFG.DefaultOverheadTextEnabled)
    return save_data
end

function NC_SendMessage(message)
    if type(message) ~= "string" or message == "" then return end
    Net.Message:SendToServer({ body = message })
end

function NC_SendEdit(id, message)
    if id == nil or type(message) ~= "string" or message == "" then return end
    Net.Edit:SendToServer({ id = id, body = message })
end

function NC_SendTyping(isTyping)
    Net.Typing:SendToServer({ on = isTyping and true or false })
end

function NC_SendRoll(kind, id, roll_type, tier, advantage)
    if not kind or not id or not tier then return end
    Net.Roll:SendToServer({
        kind = kind, id = id, rollType = roll_type or "active", tier = tier,
        adv = advantage and true or false,
    })
end

function NC_RequestHistory(on_reply)
    Net.History:RequestToServer({}, function(reply)
        on_reply(type(reply) == "table" and reply.items or {})
    end)
end

local UTF8_CHAR = "[\1-\127\194-\244][\128-\191]*"

local ACCENT_FOLD = {}
for base, accented in pairs({
    a = "àáâãäåā", c = "çćč", e = "èéêëēėę", i = "ìíîïī", n = "ñń", o = "òóôõöøō",
    u = "ùúûüū", y = "ýÿ", s = "śš", z = "źżž", l = "ł",
}) do
    for ch in accented:gmatch(UTF8_CHAR) do
        ACCENT_FOLD[ch] = base
    end
end

local function _sort_key(text)
    return (text:lower():gsub(UTF8_CHAR, function(ch) return ACCENT_FOLD[ch] or ch end))
end

function NC_GetSortedSkills()
    local T = Lang.T
    local sorted = {}
    for _, s in ipairs(CFG.DiceSkills) do table.insert(sorted, s) end
    table.sort(sorted, function(a, b) return _sort_key(T("skill." .. a.id)) < _sort_key(T("skill." .. b.id)) end)
    return sorted
end

local function _roll_result_text(r)
    local T = Lang.T
    local result = tonumber(r.result) or 0
    local crit = tonumber(r.crit) or 0
    if result == 2 then return T("dice.cancelled") end
    if crit == 1 then return T("dice.criticalSuccess") end
    if crit == 2 then return T("dice.criticalFailure") end
    return T(result == 1 and "dice.success" or "dice.failure")
end

function NC_FormatRollOverhead(r)
    if type(r) ~= "table" then return "" end
    local T = Lang.T
    local label = T((r.kind == "ability" and "ability." or "skill.") .. tostring(r.id))
    return T("dice.overhead", label, _roll_result_text(r))
end

Ext.Events.SessionLoaded:Subscribe(function() CFG.ResolveDiceDifficultyClasses() end)
