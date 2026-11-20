local S = Ext.Require("Client/NativeChat_State.lua")
local CFG, T = S.CFG, S.T

local F = {}

local function _hex(color)
    local function c(v) return math.max(0, math.min(255, math.floor((tonumber(v) or 1) * 255 + 0.5))) end
    return string.format("#%02X%02X%02X", c(color[1]), c(color[2]), c(color[3]))
end

local COLORS = {
    EMOTE = _hex(CFG.EmoteColor),
    OOC = _hex(CFG.OocColor),
    EDITED = _hex(CFG.EditedColor),
}

function F.esc(text)
    return (tostring(text or ""):gsub("<([%a/!?])", "‹%1"))
end

local function _font(hex, text)
    return '<font color="' .. hex .. '">' .. text .. '</font>'
end

function F.system_text(rec)
    if rec.key then
        if rec.arg ~= nil then return T(rec.key, rec.arg) end
        return T(rec.key)
    end
    return rec.raw or ""
end

local function _split_segments(text)
    local out, pos = {}, 1
    while pos <= #text do
        local es, ee = text:find("%*[^*]+%*", pos)
        local os, oe = text:find("%b()", pos)
        local s, e, kind
        if es and (not os or es < os) then s, e, kind = es, ee, "emote"
        elseif os then s, e, kind = os, oe, "ooc" end
        if not s then
            table.insert(out, { kind = "text", text = text:sub(pos) })
            break
        end
        if s > pos then table.insert(out, { kind = "text", text = text:sub(pos, s - 1) }) end
        table.insert(out, { kind = kind, text = text:sub(s, e) })
        pos = e + 1
    end
    return out
end

function F.rich_body(raw, edited)
    local parts = {}
    local after_ooc = false

    local function _has_content()
        for _, p in ipairs(parts) do
            if p:find("%S") then return true end
        end
        return false
    end

    for _, seg in ipairs(_split_segments((raw or ""):gsub("\r", ""))) do
        if seg.kind == "ooc" then
            if #parts > 0 then parts[#parts] = parts[#parts]:gsub("%s+$", "") end
            if _has_content() then table.insert(parts, "\n") end
            table.insert(parts, _font(COLORS.OOC, F.esc(seg.text)))
            after_ooc = true
        else
            local text = seg.text
            if after_ooc then
                text = text:gsub("^%s+", "")
                if text ~= "" then
                    table.insert(parts, "\n")
                    after_ooc = false
                end
            end
            if text ~= "" then
                if seg.kind == "emote" then
                    table.insert(parts, "<i>" .. _font(COLORS.EMOTE, F.esc(text)) .. "</i>")
                else
                    table.insert(parts, F.esc(text))
                end
            end
        end
    end

    if edited then
        table.insert(parts, " " .. _font(COLORS.EDITED, F.esc(T("chat.edited"))))
    end

    return (table.concat(parts):gsub("\n", "<br>"))
end

local function _build_item(rec, showName)
    if rec.kind == "system" then
        return { uid = rec.uid, headerVis = "Collapsed", headerName = "", rich = F.esc(F.system_text(rec)) }
    end

    local item = { uid = rec.uid, headerVis = "Collapsed", headerName = "", rich = F.rich_body(rec.raw, rec.edited) }
    if showName then
        item.headerName = tostring(rec.name)
        item.headerVis = "Visible"
    end
    return item
end

function F.desired_items()
    local items = {}
    local prevName, prevTimestampMs = nil, nil

    for _, rec in ipairs(S.chat_messages) do
        local showName = false
        if rec.kind == "system" then
            prevName, prevTimestampMs = nil, nil
        else
            local tooLongSince = prevTimestampMs ~= nil
                and (rec.addedAtMs - prevTimestampMs) > (CFG.NameRepeatDelaySeconds * 1000)
            showName = (rec.name ~= prevName) or tooLongSince
            prevName = rec.name
            prevTimestampMs = rec.addedAtMs
        end
        table.insert(items, _build_item(rec, showName))
    end

    return items
end

return F
