local S = Ext.Require("Client/NativeChat_State.lua")
local CFG, T = S.CFG, S.T

local D = {
    roll_type = 1,
    advantage = false,
    tier = CFG.DiceDefaultTierIndex,
    lists_version = 1,
}

function D.roll_type_id()
    return CFG.DiceRollTypes[D.roll_type] or "active"
end

function D.set_roll_type(id)
    for i, t in ipairs(CFG.DiceRollTypes) do
        if t == id then D.roll_type = i end
    end
    S.touch_activity()
    S.refresh()
end

function D.toggle_advantage()
    D.advantage = not D.advantage
    S.touch_activity()
    S.refresh()
end

function D.step_tier(delta)
    D.tier = math.max(1, math.min(#CFG.DiceDifficultyTiers, D.tier + delta))
    S.touch_activity()
    S.refresh()
end

function D.tier_label()
    local tier = CFG.DiceDifficultyTiers[D.tier]
    if not tier then return "" end
    return T("dice.tierLabel", T("dice.tier." .. tier.id), tier.dc)
end

function D.abilities()
    local out = {}
    for _, a in ipairs(CFG.DiceAbilities) do
        table.insert(out, { kind = "ability", id = a.id, label = T("ability.short." .. a.id) })
    end
    return out
end

function D.skills()
    local out = {}
    for _, sk in ipairs(NC_GetSortedSkills()) do
        table.insert(out, { kind = "skill", id = sk.id, label = T("skill." .. sk.id) })
    end
    return out
end

function D.roll(kind, id)
    local tier = CFG.DiceDifficultyTiers[D.tier]
    if not tier then return end
    S.touch_activity()
    NC_SendRoll(kind, id, D.roll_type_id(), tier.id, D.advantage)
end

function D.on_language()
    D.lists_version = D.lists_version + 1
    S.refresh()
end

function D.toggle()
    S.dice_visible = not S.dice_visible
    if S.dice_visible then
        S.listening_for_open_key = false
    else
        S.touch_activity()
    end
    S.refresh()
end

return D
