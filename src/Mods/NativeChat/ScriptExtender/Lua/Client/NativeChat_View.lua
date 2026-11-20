local S = Ext.Require("Client/NativeChat_State.lua")
local F = Ext.Require("Client/NativeChat_Format.lua")
local CFG, T = S.CFG, S.T

local V = {
    messages_dirty = true,
}

local TYPE_VM = "NativeChat_ChatVM14"
local TYPE_MSG = "NativeChat_MessageVM7"
local TYPE_DICE_ITEM = "NativeChat_DiceItemVM3"
local WIDGET_NAME = "NativeChat"
local NATIVE_LOG_NAME = "CombatLog"

local function _get_root()
    local ok, root = pcall(function() return Ext.UI.GetRoot and Ext.UI.GetRoot() or nil end)
    if ok then return root end
    return nil
end

local function _prop(element, name)
    if not element then return nil end
    local ok, value = pcall(function() return element[name] end)
    if ok then return value end
    return nil
end

local function _xy(p)
    if p == nil then return nil, nil end
    for _, keys in ipairs({ {1, 2}, {"x", "y"}, {"X", "Y"} }) do
        local ok, x, y = pcall(function() return tonumber(p[keys[1]]), tonumber(p[keys[2]]) end)
        if ok and x and y then return x, y end
    end
    return nil, nil
end

local function _find_hud_widget(name)
    local root = _get_root()
    if not root then return nil end
    local content = root:Find("ContentRoot")
    if not content then return nil end
    for i = 1, content.ChildrenCount do
        local child = content:Child(i)
        if child and child.Name == name then return child end
    end
    return nil
end

local function _find_widget()
    return _find_hud_widget(WIDGET_NAME)
end

local function _our_vm(widget)
    local vm = widget and widget.DataContext
    if not vm then return nil end
    local ok, label = pcall(function() return vm.EditLabel end)
    if ok and type(label) == "string" then return vm end
    return nil
end

local function _current_vm()
    local ok, vm = pcall(function() return _our_vm(_find_widget()) end)
    if ok then return vm end
    return nil
end

do
    local function str() return { Type = "String", Notify = true } end
    local function dbl() return { Type = "Double", Notify = true } end
    local function bool() return { Type = "Bool", Notify = true } end

    Ext.UI.RegisterType(TYPE_MSG, {
        HeaderVisibility = str(),
        HeaderName = str(),
        Rich = str(),
    })
    Ext.UI.RegisterType(TYPE_DICE_ITEM, {
        Label = str(),
        RollCommand = { Type = "Command" },
    })
    Ext.UI.RegisterType(TYPE_VM, {
        RootVisibility = str(),
        PanelX = dbl(), PanelY = dbl(), PanelW = dbl(), PanelH = dbl(),
        SideX = dbl(), SideY = dbl(), SideW = dbl(), TabsY = dbl(), InputMaxH = dbl(),
        PanelOpacity = dbl(),
        DragOverlayVisibility = str(),

        ActiveTab = str(),
        ChatTabLabel = str(),
        LogTabLabel = str(),
        ChatContentVisibility = str(),
        LogContentVisibility = str(),

        DiceLabel = str(), DiceOpen = str(),
        EditLabel = str(),
        ChatFontSize = dbl(),

        AutoHideState = str(), OverheadState = str(),
        KeyIconVisibility = str(), KeyWaitVisibility = str(),
        FontLabel = str(), ActiveLabel = str(), IdleLabel = str(),

        TipAutoHide = str(), TipOverhead = str(), TipKey = str(),
        TipAutoHideValue = str(), TipOverheadValue = str(), TipKeyValue = str(),
        TipFontDown = str(), TipFontUp = str(),
        TipActiveDown = str(), TipActiveUp = str(), TipIdleDown = str(), TipIdleUp = str(),
        PlaceholderText = str(),
        PlaceholderVisibility = str(),
        TypingText = str(),

        Messages = { Type = "Collection" },

        DiceVisibility = str(),
        DiceX = dbl(), DiceY = dbl(), DiceW = dbl(), DiceH = dbl(),
        DiceActiveLabel = str(), DicePassiveLabel = str(), DiceAdvLabel = str(),
        DiceActiveState = str(), DicePassiveState = str(), DiceAdvState = str(),
        DiceDcValue = str(),
        Abilities = { Type = "Collection" },
        Skills = { Type = "Collection" },
        DiceActiveCommand = { Type = "Command" },
        DicePassiveCommand = { Type = "Command" },
        DiceAdvCommand = { Type = "Command" },
        DiceDcPrevCommand = { Type = "Command" },
        DiceDcNextCommand = { Type = "Command" },

        FocusInput = bool(),
        ReleaseFocus = bool(),

        InputText = { Type = "String", Notify = true, WriteCallback = function() V.on_input_written() end },

        SendCommand = { Type = "Command" },
        EditCommand = { Type = "Command" },
        DiceCommand = { Type = "Command" },
        AutoHideCommand = { Type = "Command" },
        OverheadCommand = { Type = "Command" },
        KeyCommand = { Type = "Command" },
        FontDownCommand = { Type = "Command" },
        FontUpCommand = { Type = "Command" },
        ActiveDownCommand = { Type = "Command" },
        ActiveUpCommand = { Type = "Command" },
        IdleDownCommand = { Type = "Command" },
        IdleUpCommand = { Type = "Command" },
        TabChatCommand = { Type = "Command" },
        TabLogCommand = { Type = "Command" },
    })
end

local pushed = {}
local rendered = {}
local pending_input_text = nil
local last_written_input = nil
local flush_pending = false
local drag = nil
local log_dc_set = false
local dice_lists_version = 0

local function _push(vm, field, value)
    if pushed[field] == value then return end
    vm[field] = value
    pushed[field] = value
end

local function _set_item(item, d)
    item.HeaderVisibility = d.headerVis
    item.HeaderName = d.headerName
    item.Rich = d.rich
end

local function _update_item(item, old, new)
    if old.headerVis ~= new.headerVis then item.HeaderVisibility = new.headerVis end
    if old.headerName ~= new.headerName then item.HeaderName = new.headerName end
    if old.rich ~= new.rich then item.Rich = new.rich end
end

local function _sync_messages(vm)
    local desired = F.desired_items()
    local list = vm.Messages
    local full = (#list ~= #rendered) or #desired == 0

    if not full and #rendered > 0 then
        local first, idx = desired[1].uid, nil
        for i = 1, #rendered do
            if rendered[i].uid == first then idx = i break end
        end
        if not idx then
            full = true
        else
            for _ = 1, idx - 1 do
                list[1] = nil
                table.remove(rendered, 1)
            end
        end
    end

    if not full then
        for i = 1, #rendered do
            local d = desired[i]
            if not d or d.uid ~= rendered[i].uid then full = true break end
            _update_item(list[i], rendered[i], d)
            rendered[i] = d
        end
    end

    if full then
        for i = #list, 1, -1 do list[i] = nil end
        rendered = {}
    end

    for i = #rendered + 1, #desired do
        local item = Ext.UI.Instantiate(TYPE_MSG)
        _set_item(item, desired[i])
        list[#list + 1] = item
        rendered[i] = desired[i]
    end
end

local function _layout_panel()
    local p = S.panel
    local min_w = math.max(CFG.MinPanelW, (S.bar_w or 0) + CFG.BarMarginW)
    local max_w = S.canvas_w - CFG.AnchorRight - CFG.DicePanelW - CFG.DicePanelGap
    p.w = math.max(min_w, math.min(p.w, max_w))
    local bar_h = S.bar_h or CFG.DefaultBarH
    local above = bar_h + CFG.SettingsBarGap - CFG.PanelBorderInset
    local anchor_bottom = CFG.AnchorBottom
    if S.hotbar_h and S.hotbar_h > 0 then
        anchor_bottom = S.hotbar_h + CFG.TabsH - CFG.TabsOverlap + CFG.HotbarGap
    end
    p.h = math.max(CFG.MinPanelH, math.min(p.h, S.canvas_h - anchor_bottom - above))
    p.x = S.canvas_w - CFG.AnchorRight - p.w
    p.y = S.canvas_h - anchor_bottom - p.h

    S.side_x = p.x
    S.side_w = p.w
    S.side_y = p.y - above

    S.tabs_y = p.y + p.h - CFG.TabsOverlap

    local d = S.dice_panel
    d.w = CFG.DicePanelW
    d.h = p.h
    d.x = math.max(0, p.x - d.w - CFG.DicePanelGap)
    d.y = p.y
end

local function _command(fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then S.log("Command error: " .. tostring(err)) end
    end
end

local function _fill_dice_list(list, entries)
    for i = #list, 1, -1 do list[i] = nil end
    for _, e in ipairs(entries) do
        local item = Ext.UI.Instantiate(TYPE_DICE_ITEM)
        item.Label = e.label
        local kind, id = e.kind, e.id
        item.RollCommand:SetHandler(_command(function() S.dice.roll(kind, id) end))
        list[#list + 1] = item
    end
end

local function _flush_dice(vm, show)
    local D = S.dice
    if not D then return end
    local d = S.dice_panel
    local on = function(b) return b and "on" or "off" end

    _push(vm, "DiceVisibility", (show and S.dice_visible) and "Visible" or "Collapsed")
    _push(vm, "DiceX", d.x)
    _push(vm, "DiceY", d.y)
    _push(vm, "DiceW", d.w)
    _push(vm, "DiceH", d.h)
    _push(vm, "DiceActiveLabel", T("dice.short.active"))
    _push(vm, "DicePassiveLabel", T("dice.short.passive"))
    _push(vm, "DiceAdvLabel", T("dice.advantageOption"))
    local roll_type = D.roll_type_id()
    _push(vm, "DiceActiveState", on(roll_type == "active"))
    _push(vm, "DicePassiveState", on(roll_type == "passive"))
    _push(vm, "DiceAdvState", on(D.advantage))
    _push(vm, "DiceDcValue", D.tier_label())
    if dice_lists_version ~= D.lists_version then
        dice_lists_version = D.lists_version
        _fill_dice_list(vm.Abilities, D.abilities())
        _fill_dice_list(vm.Skills, D.skills())
    end
end

local function _chat_tab_label()
    if S.unread > 0 then return T("tab.chatUnread", S.unread) end
    return T("tab.chat")
end

local function _flush(widget, vm)
    local show = S.show_chat()
    local vis = show and "Visible" or "Collapsed"
    _push(vm, "RootVisibility", vis)
    pcall(function() if tostring(widget.Visibility) ~= vis then widget.Visibility = vis end end)
    _layout_panel()
    _push(vm, "PanelX", S.panel.x)
    _push(vm, "PanelY", S.panel.y)
    _push(vm, "PanelW", S.panel.w)
    _push(vm, "PanelH", S.panel.h)
    _push(vm, "SideX", S.side_x or 0)
    _push(vm, "SideY", S.side_y or 0)
    _push(vm, "SideW", S.side_w or S.panel.w)
    _push(vm, "TabsY", S.tabs_y or S.panel.y)
    _push(vm, "InputMaxH", math.floor(S.panel.h * CFG.InputMaxShare))
    _push(vm, "PanelOpacity", S.input_active and S.settings.active_alpha or S.settings.inactive_alpha)
    _push(vm, "DragOverlayVisibility", drag and "Visible" or "Collapsed")
    local chat_tab = S.active_tab == "chat"
    _push(vm, "ActiveTab", S.active_tab)
    _push(vm, "ChatTabLabel", _chat_tab_label())
    _push(vm, "LogTabLabel", T("tab.log"))
    _push(vm, "ChatContentVisibility", chat_tab and "Visible" or "Collapsed")
    _push(vm, "LogContentVisibility", chat_tab and "Collapsed" or "Visible")
    local s = S.settings
    local on = function(b) return b and "on" or "off" end
    _push(vm, "DiceLabel", T("tab.dice"))
    _push(vm, "DiceOpen", on(S.dice_visible))
    _push(vm, "EditLabel", T(S.editing_message_id ~= nil and "input.cancel" or "input.edit"))
    _push(vm, "ChatFontSize", s.font_size)
    _push(vm, "AutoHideState", s.auto_hide and "slash" or "plain")
    _push(vm, "OverheadState", s.overhead_text and "plain" or "slash")
    _push(vm, "KeyIconVisibility", S.listening_for_open_key and "Collapsed" or "Visible")
    _push(vm, "KeyWaitVisibility", S.listening_for_open_key and "Visible" or "Collapsed")
    _push(vm, "FontLabel", tostring(math.floor(s.font_size + 0.5)))
    _push(vm, "ActiveLabel", tostring(math.floor(s.active_alpha * 100 + 0.5)))
    _push(vm, "IdleLabel", tostring(math.floor(s.inactive_alpha * 100 + 0.5)))
    local function on_off(v) return T(v and "tip.on" or "tip.off") end
    _push(vm, "TipAutoHide", T("tip.autoHide") .. " ")
    _push(vm, "TipAutoHideValue", on_off(s.auto_hide))
    _push(vm, "TipOverhead", T("tip.overhead") .. " ")
    _push(vm, "TipOverheadValue", on_off(s.overhead_text))
    if S.listening_for_open_key then
        _push(vm, "TipKey", T("tip.keyListening"))
        _push(vm, "TipKeyValue", "")
    else
        _push(vm, "TipKey", T("tip.key") .. " ")
        _push(vm, "TipKeyValue", S.settings_ui and S.settings_ui.key_label() or "")
    end
    _push(vm, "TipFontDown", T("tip.fontDown"))
    _push(vm, "TipFontUp", T("tip.fontUp"))
    _push(vm, "TipActiveDown", T("tip.activeDown"))
    _push(vm, "TipActiveUp", T("tip.activeUp"))
    _push(vm, "TipIdleDown", T("tip.idleDown"))
    _push(vm, "TipIdleUp", T("tip.idleUp"))
    _push(vm, "PlaceholderText", T("input.placeholder"))
    _push(vm, "TypingText", S.chat and S.chat.typing_text() or "")
    if pending_input_text ~= nil then
        local text = pending_input_text
        pending_input_text = nil
        last_written_input = text
        S.input_text = text
        vm.InputText = text
    end
    _push(vm, "PlaceholderVisibility", S.input_text == "" and "Visible" or "Collapsed")
    if V.messages_dirty then
        V.messages_dirty = false
        _sync_messages(vm)
    end

    _flush_dice(vm, show)
end

local function _do_flush()
    flush_pending = false
    local ok, err = pcall(function()
        local widget = _find_widget()
        local vm = _our_vm(widget)
        if vm then _flush(widget, vm) end
    end)

    if not ok then S.log("UI update error: " .. tostring(err)) end
end

function V.refresh()
    if flush_pending then return end
    flush_pending = true
    Ext.UI.Defer(_do_flush)
end

function V.set_input_text(text)
    pending_input_text = text or ""
    S.input_text = pending_input_text
    V.refresh()
end

function V.on_input_written()
    Ext.UI.Defer(function()
        local vm = _current_vm()
        if not vm then return end
        local ok, value = pcall(function() return vm.InputText end)
        if not ok then return end
        value = tostring(value or "")
        local own = last_written_input ~= nil and value == last_written_input
        last_written_input = nil
        if S.chat then S.chat.on_input_value(value, own) end
    end)
end

local function _pulse(field)
    Ext.Timer.WaitFor(40, function()
        Ext.UI.Defer(function()
            local vm = _current_vm()
            if not vm then return end
            vm[field] = true
            Ext.Timer.WaitFor(60, function()
                Ext.UI.Defer(function()
                    local v = _current_vm()
                    if v then v[field] = false end
                end)
            end)
        end)
    end)
end

function V.set_tab(tab)
    if S.active_tab == tab then return end
    S.active_tab = tab
    if tab == "chat" then S.unread = 0 end
    S.touch_activity()
    V.refresh()
end

function V.focus_input()
    S.chat_hidden_by_idle = false
    S.active_tab = "chat"
    S.unread = 0
    S.touch_activity()
    V.refresh()
    _pulse("FocusInput")
end

function V.release_focus()
    _pulse("ReleaseFocus")
end

local CTRL_KEYS = { Key_LeftCtrl = true, Key_RightCtrl = true }
local ctrl_down = false

local function _key_name(args)
    local key = ""
    pcall(function() key = tostring(args.Key) end)
    return key
end

local function _set_box_property(box, name, value)
    if pcall(function() box[name] = value end) then return true end
    return pcall(function() box:SetProperty(name, value) end)
end

local function _select_all(box)
    local text = S.input_text or ""
    local len = (utf8 and utf8.len(text)) or #text
    local ok = _set_box_property(box, "SelectionStart", 0) and _set_box_property(box, "SelectionLength", len)
    return ok
end

function V.select_all_in_input()
    Ext.UI.Defer(function()
        local widget = _find_widget()
        local box = widget and widget:Find("ChatInput")
        if box then _select_all(box) end
    end)
end

function V.ctrl_held()
    return ctrl_down
end

local function _on_input_key_down(args, box)
    local key = _key_name(args)
    local handled = false

    if CTRL_KEYS[key] then
        ctrl_down = true
    elseif key == "Key_A" and ctrl_down then
        handled = _select_all(box)
    elseif key == "Key_Up" and S.editing_message_id == nil and S.clean_input(S.input_text) == "" then
        S.chat.begin_edit_last_message(false)
        handled = S.editing_message_id ~= nil
    elseif key == "Key_Escape" and S.editing_message_id ~= nil then
        S.chat.cancel_edit()
        handled = true
    end

    if handled then pcall(function() args.Handled = true end) end
end

local function _on_input_key_up(args)
    if CTRL_KEYS[_key_name(args)] then ctrl_down = false end
end

local function _begin_resize(args)
    local mx, my = _xy(_prop(args, "Position"))
    if not mx then return end
    drag = { sx = mx, sy = my, w = S.panel.w, h = S.panel.h, upp = S.canvas_w / S.screen_w }
    pcall(function() args.Handled = true end)
    S.touch_activity()
    V.refresh()
end

local function _end_resize()
    if not drag then return end
    drag = nil
    V.refresh()
    S.on_main(S.save_settings)
end

local function _on_resize_move(args)
    if not drag then return end
    if tostring(_prop(args, "LeftButton")) == "Released" then return _end_resize() end

    local mx, my = _xy(_prop(args, "Position"))
    if not mx then return end
    S.panel.w = drag.w - (mx - drag.sx) * drag.upp
    S.panel.h = drag.h - (my - drag.sy) * drag.upp
    V.refresh()
end

function V.is_resizing()
    return drag ~= nil
end

local function _subscribe(widget, name, event, fn)
    local el = widget:Find(name)
    if not el then
        S.log("Element not found: " .. name)
        return
    end
    el:Subscribe(event, function(sender, args)
        local ok, err = pcall(fn, args, sender)
        if not ok then S.log(name .. "." .. event .. " error: " .. tostring(err)) end
    end)
end

local function _subscribe_events(widget)
    _subscribe(widget, "ChatInput", "PreviewKeyDown", _on_input_key_down)
    _subscribe(widget, "ChatInput", "PreviewKeyUp", _on_input_key_up)
    _subscribe(widget, "ChatInput", "GotKeyboardFocus", function()
        S.input_active = true
        S.touch_activity()
        V.refresh()
    end)

    _subscribe(widget, "ChatInput", "LostKeyboardFocus", function()
        S.input_active = false
        ctrl_down = false
        S.chat.send_typing(false)
        S.touch_activity()
        V.refresh()
    end)

    local function _enter() S.mouse_over_panel = true end
    local function _leave()
        S.mouse_over_panel = false
        S.touch_activity()
    end
    _subscribe(widget, "PanelRoot", "MouseEnter", _enter)
    _subscribe(widget, "PanelRoot", "MouseLeave", _leave)
    _subscribe(widget, "DicePanel", "MouseEnter", _enter)
    _subscribe(widget, "DicePanel", "MouseLeave", _leave)
    _subscribe(widget, "SideBar", "MouseEnter", _enter)
    _subscribe(widget, "SideBar", "MouseLeave", _leave)
    _subscribe(widget, "ResizeGrip", "MouseLeftButtonDown", _begin_resize)
    _subscribe(widget, "DragOverlay", "MouseMove", _on_resize_move)
    _subscribe(widget, "DragOverlay", "MouseLeftButtonUp", function() _end_resize() end)
end

local function _bind(widget)
    local vm = Ext.UI.Instantiate(TYPE_VM)
    widget.DataContext = vm

    pushed = {}
    rendered = {}
    log_dc_set = false
    dice_lists_version = 0
    V.messages_dirty = true
    pending_input_text = S.input_text or ""
    drag = nil

    vm.SendCommand:SetHandler(_command(function() S.chat.submit() end))
    vm.EditCommand:SetHandler(_command(function() S.chat.toggle_edit() end))
    vm.DiceCommand:SetHandler(_command(function() S.dice.toggle() end))
    local St = S.settings_ui
    vm.AutoHideCommand:SetHandler(_command(function() St.toggle_auto_hide() end))
    vm.OverheadCommand:SetHandler(_command(function() St.toggle_overhead() end))
    vm.KeyCommand:SetHandler(_command(function() St.start_key_listen() end))
    vm.FontDownCommand:SetHandler(_command(function() St.change_font_size(-1) end))
    vm.FontUpCommand:SetHandler(_command(function() St.change_font_size(1) end))
    vm.ActiveDownCommand:SetHandler(_command(function() St.change_alpha("active_alpha", -1) end))
    vm.ActiveUpCommand:SetHandler(_command(function() St.change_alpha("active_alpha", 1) end))
    vm.IdleDownCommand:SetHandler(_command(function() St.change_alpha("inactive_alpha", -1) end))
    vm.IdleUpCommand:SetHandler(_command(function() St.change_alpha("inactive_alpha", 1) end))
    vm.TabChatCommand:SetHandler(_command(function() V.set_tab("chat") end))
    vm.TabLogCommand:SetHandler(_command(function() V.set_tab("log") end))
    vm.DiceActiveCommand:SetHandler(_command(function() S.dice.set_roll_type("active") end))
    vm.DicePassiveCommand:SetHandler(_command(function() S.dice.set_roll_type("passive") end))
    vm.DiceAdvCommand:SetHandler(_command(function() S.dice.toggle_advantage() end))
    vm.DiceDcPrevCommand:SetHandler(_command(function() S.dice.step_tier(-1) end))
    vm.DiceDcNextCommand:SetHandler(_command(function() S.dice.step_tier(1) end))
    _subscribe_events(widget)
    _flush(widget, vm)
end

local _read_ui_state
local _read_hud_visible
local _read_dialog

local native_hidden = false
local native_reapply = 0

local function _sync_native_log(widget)
    local native = _find_hud_widget(NATIVE_LOG_NAME)
    if not native then
        log_dc_set = false
        return
    end
    _read_ui_state(native)
    _read_hud_visible(native)
    _read_dialog()
    native_reapply = native_reapply + 1
    if not native_hidden or native_reapply >= 8 then
        native_reapply = 0
        pcall(function() native.Opacity = 0 end)
        pcall(function() native.IsHitTestVisible = false end)
        pcall(function() native.Focusable = false end)
        native_hidden = true
    end

    local log_root = widget:Find("LogRoot")
    if not log_dc_set and log_root then
        local dc = native.DataContext
        if dc then
            log_root.DataContext = dc
            log_dc_set = true
        end
    end
end

_read_hud_visible = function(native)
    local vis = _prop(native, "IsVisible")
    if vis == nil then return end
    vis = vis and true or false
    if S.native_hud_visible ~= vis then
        S.native_hud_visible = vis
        V.refresh()
    end
end

_read_dialog = function()
    local found = nil
    local root = _get_root()
    local content = root and root:Find("ContentRoot")
    if content then
        for i = 1, content.ChildrenCount do
            local child = content:Child(i)
            local name = child and child.Name
            if name == "Dialogue" and _prop(child, "IsVisible") then
                found = name
                break
            end
        end
    end
    if not found and type(S.ui_state) == "string" and S.ui_state:find("Dialog") then
        found = "state " .. S.ui_state
    end
    local in_dialog = found ~= nil
    if (S.in_dialog or false) ~= in_dialog then
        S.in_dialog = in_dialog
        V.refresh()
    end
end

_read_ui_state = function(native)
    local ok, state = pcall(function() return tostring(native.DataContext.CurrentPlayer.UIData.ActiveState) end)
    if not ok or not state or state == "nil" then return end
    if S.ui_state ~= state then
        S.ui_state = state
        local hidden = false
        for _, pattern in ipairs(CFG.HiddenUIStates) do
            if state:find(pattern) then hidden = true break end
        end
        if hidden ~= S.ui_state_hidden then
            S.ui_state_hidden = hidden
            V.refresh()
        end
    end
end

local function _read_root_state()
    local root = _get_root()
    if not root then return end

    local okp, props = pcall(function() return root:GetAllProperties(root) end)
    if okp and props then
        local w, h = tonumber(props.ActualWidth), tonumber(props.ActualHeight)
        if w and w > 0 and h and h > 0 and (w ~= S.screen_w or h ~= S.screen_h) then
            S.screen_w, S.screen_h = w, h
        end
    end

    if S.in_game then
        local okv, vis = pcall(function() return root:GetProperty("IsVisible") end)
        if okv and vis ~= nil and S.game_ui_hidden ~= (not vis) then
            S.game_ui_hidden = not vis
            V.refresh()
        end
    end
end

local function _read_canvas_size(widget)
    local canvas = widget:Find("Root")
    local w = tonumber(_prop(canvas, "ActualWidth"))
    local h = tonumber(_prop(canvas, "ActualHeight"))
    if not w or w < 100 then w = S.DESIGN_W end
    if not h or h < 100 then h = S.DESIGN_H end
    if w ~= S.canvas_w or h ~= S.canvas_h then
        S.canvas_w, S.canvas_h = w, h
    end
end

local function _find_visual(root, name, max_depth)
    local level = { root }
    for _ = 1, max_depth do
        local next_level = {}
        for _, e in ipairs(level) do
            local n = 0
            pcall(function() n = e.VisualChildrenCount or 0 end)
            for i = 1, n do
                local ok_c, c = pcall(function() return e:VisualChild(i) end)
                if ok_c and c then
                    if _prop(c, "Name") == name then return c end
                    next_level[#next_level + 1] = c
                end
            end
        end
        level = next_level
        if #level == 0 then break end
    end
    return nil
end

local function _read_hotbar()
    local hb = _find_hud_widget("HotBar")
    local root = nil
    if hb then
        pcall(function() root = hb:Find("HotbarRoot") end)
        if not root then root = _find_visual(hb, "HotbarRoot", 4) end
    end
    local h = root and tonumber(_prop(root, "ActualHeight"))
    if not h or h <= 0 then h = nil end
    local changed = (h == nil) ~= (S.hotbar_h == nil) or (h and math.abs(h - S.hotbar_h) > 0.5)
    if changed then
        S.hotbar_h = h
        V.refresh()
    end
end

local watchdog_errors = {}
local function _watchdog()
    Ext.UI.Defer(function()
        local ok, err = pcall(function()
            _read_root_state()
            local widget = _find_widget()
            if not widget then return end
            _read_canvas_size(widget)
            local bar_w = tonumber(_prop(widget:Find("SettingsBar"), "ActualWidth"))
            if bar_w and bar_w > 0 and math.abs(bar_w - (S.bar_w or 0)) > 0.5 then
                S.bar_w = bar_w
                V.refresh()
            end
            local bar_h = tonumber(_prop(widget:Find("SettingsBar"), "ActualHeight"))
            if bar_h and bar_h > 0 and math.abs(bar_h - (S.bar_h or 0)) > 0.5 then
                S.bar_h = bar_h
                V.refresh()
            end

            if not _our_vm(widget) then
                _bind(widget)
            else
                V.refresh()
            end

            _sync_native_log(widget)
            _read_hotbar()
        end)

        if not ok then
            local msg = tostring(err)
            if not watchdog_errors[msg] then
                watchdog_errors[msg] = true
                S.log("Watchdog error: " .. msg)
            end
        end
    end)

    Ext.Timer.WaitFor(250, _watchdog)
end

local watchdog_started = false
function V.start()
    if watchdog_started then return end
    watchdog_started = true
    Ext.Timer.WaitFor(1000, _watchdog)
end

return V
