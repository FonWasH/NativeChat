if _G.__NATIVECHAT_LANG then
    return _G.__NATIVECHAT_LANG
end

local Lang = {}

local HANDLES = {
    ["input.edit"] = "hdf187a1egcb6cg5cb9gbd70g02e02467634e",
    ["input.cancel"] = "he66f3941g684ag53cdg87d4g3830a9c6b2ce",
    ["input.placeholder"] = "ha71da956g1ca9g5e96g98a7gdde0665b4254",
    ["status.typing"] = "hd562c7f8g0eb9g57e9gae9eg607e6ec59f79",
    ["status.several"] = "h6a7171f7gd575g566fgb56dga9cd9560c294",
    ["chat.joined"] = "h9367f92bgdd52g5eb7gafbbg097d0b0b0e98",
    ["chat.left"] = "h08dbffb1gaae2g55b1g925cg93b7876b4928",
    ["chat.edited"] = "ha3ac1308g4884g510agb8afgcd5223c3c63a",
    ["tab.chat"] = "hd4b1ce98g71e5g5800gb444gd241a588fcf1",
    ["tab.chatUnread"] = "hfa6e4610g18f7g5da2gb830g8f81fbebd7ca",
    ["tab.log"] = "h35694ed3g3c3fg5330gaf47gab89ba6c0b24",
    ["tab.dice"] = "hf20680dbgf28eg5588g8b84g880464e95319",
    ["tip.key"] = "h252e52a7g9285g5312g837bg1e166b9dc1a8",
    ["tip.autoHide"] = "hffd52627g60b2g52cfg92d7g2c4baaa752eb",
    ["tip.overhead"] = "h2c5cee9agb3c8g5af1ga3feg6a8ef703edc8",
    ["tip.on"] = "h9d5f7f01gabdag541agb338gac12079a645f",
    ["tip.off"] = "hb1c8285bg9394g5b3bga9aag7c765b85a9ab",
    ["tip.keyListening"] = "h2ef3c06agb03fg5ca1g84c1g314d65430622",
    ["tip.fontDown"] = "h3a41a560g9399g51cbgaf64g049d062d2aac",
    ["tip.fontUp"] = "ha4e38c53ga60bg59a1gabb2g28643f5922d1",
    ["tip.activeDown"] = "haa59c958ge2deg563fg99ccg1f1b000e12df",
    ["tip.activeUp"] = "h6a4fb167gda09g5ef0g9b6eg6edebc787abf",
    ["tip.idleDown"] = "hbb7f4d7fg12e4g540eg8e32gf6b2fd2e44f1",
    ["tip.idleUp"] = "hc60d8934g7ca4g5cb7gaaafg355b4bc0b877",
    ["dice.short.active"] = "h5d067f52g7569g5db2ga7e9g3c2ae719a702",
    ["dice.short.passive"] = "h296272dbge0e5g5660ga24cg9e73471bcf1a",
    ["dice.advantageOption"] = "hdb2330e5gfbc0g5105ga519g1e44bf5e372d",
    ["dice.tierLabel"] = "h7f29fd97g9444g5d0bgb9bag8d5d625a8c1f",
    ["dice.tier.VeryEasy"] = "h41f900c8gb17dg515fg965ag06eaa8035fc4",
    ["dice.tier.Easy"] = "h46226090gccd7g5669gb115g5b517f889542",
    ["dice.tier.Medium"] = "h5786403agaea1g5fcdga37cgeb62f64a4a70",
    ["dice.tier.Hard"] = "hbd71ec63g658bg53c9g8394gee5f97be9ae8",
    ["dice.tier.VeryHard"] = "h83efd87bgf730g5f78g892dg0a768adb0283",
    ["dice.tier.NearlyImpossible"] = "hfa859373g130dg521cg9162gb26cebe92f41",
    ["dice.success"] = "h3651eebfg0979g5b15gb3e0g7d208e69b236",
    ["dice.failure"] = "hbf91aa44g9438g5805g8b1dga9f0b839f775",
    ["dice.criticalSuccess"] = "h0377ae50gd94dg580agacb5g586edc761395",
    ["dice.criticalFailure"] = "h3db97463g4f43g572fgab8dg603f60f63c4d",
    ["dice.cancelled"] = "h6101b5c5g5866g5541g98b3g63ffc63d6bff",
    ["dice.overhead"] = "h0361674dg6eb5g5447g81ccg3d3641a99350",
    ["dice.noDifficultyClass"] = "h938bdf64g5779g5710g9701g53b1970af23b",
}

local GAME = {
    ["ability.short.Strength"]     = "h1579d774gdbcdg4a97gb3fage409138d104d",
    ["ability.short.Dexterity"]    = "h8d7356d7g4c37g41e4gb8a2gef3459e12b97",
    ["ability.short.Constitution"] = "h20676a9ag9216g47dbgba3ag82bd734cfd53",
    ["ability.short.Intelligence"] = "ha1a41e74g2804g4a70g9a85g6235163d41da",
    ["ability.short.Wisdom"]       = "h2e9f1067g2dceg4640g8816gc6394e9f0303",
    ["ability.short.Charisma"]     = "ha2fc9b3dg3305g404eg9256gf25a06d0b2aa",
    ["ability.Strength"]     = "hc8c67074g3c19g44d1g8b7bg9e5a8d06d87f",
    ["ability.Dexterity"]    = "hc30ef867gedecg4c22ga387g648ea8224248",
    ["ability.Constitution"] = "hcd19f46ag85bcg41f2gb8fbg1dc69843d250",
    ["ability.Intelligence"] = "h33d41553g12cag401eg8c71g640d3d654054",
    ["ability.Wisdom"]       = "hfb735304g4b35g49e2gbabeg05b183cb6de1",
    ["ability.Charisma"]     = "habf9df38g5018g44c4gbb6fga77177a64218",
    ["skill.Acrobatics"]     = "hf18eb9a0g33a1g481fg9646g5ddeaa7e2156",
    ["skill.AnimalHandling"] = "hab871a76g3541g4045ga1c1gbb9b5d13ee36",
    ["skill.Arcana"]         = "h22b7e6b6g8c55g49c6gba43gd16c8e399fea",
    ["skill.Athletics"]      = "h06f7e4d9g1d7eg42aagb745g2e08ebeb9de2",
    ["skill.Deception"]      = "hcaeb4d5fg8b57g4520g912fg4fae8267b844",
    ["skill.History"]        = "hab026295g69b7g4013g9b14g807992eb1a22",
    ["skill.Insight"]        = "h64f8e22agf0eeg4a0bga9abgb0178dd5e670",
    ["skill.Intimidation"]   = "h6efd5166g9073g439fgb814gcd9186cb8e61",
    ["skill.Investigation"]  = "hfd00683fg1522g4f04g91c4g9bef52cda3d0",
    ["skill.Medicine"]       = "h23dfa632g875dg4081ga2abg950b7f7adc13",
    ["skill.Nature"]         = "h63548a6ag0bc9g4e87g8d62gd6e7b8771333",
    ["skill.Perception"]     = "h153612e7g6e83g48fbg855ag7088e7eea89e",
    ["skill.Performance"]    = "hc632dc67g7806g436fg9a73gb80b4d6f5e7c",
    ["skill.Persuasion"]     = "h257372d3g6f98g4450g813bg190e19aecce4",
    ["skill.Religion"]       = "h9eab2802gb592g4c23g87b9g165135e307a1",
    ["skill.SleightOfHand"]  = "hba2e587ag00b7g4f75ga38bg8754bcaa7b6b",
    ["skill.Stealth"]        = "h49c7514bg504dg4445g915cgb9562d8585ac",
    ["skill.Survival"]       = "ha479d52eg60c5g4f9eg88ddg43e201dae0d3",
}

local ENGLISH = {
    ["input.edit"] = "Edit",
    ["input.cancel"] = "Cancel",
    ["input.placeholder"] = "Write a message...",
    ["status.typing"] = "%s is typing...",
    ["status.several"] = "Several people are typing...",
    ["chat.joined"] = "~ %s joined the chat ~",
    ["chat.left"] = "~ %s left the chat ~",
    ["chat.edited"] = "(edited)",
    ["tab.chat"] = "Chat",
    ["tab.chatUnread"] = "Chat (%d)",
    ["tab.log"] = "Log",
    ["tab.dice"] = "Dice",
    ["tip.key"] = "Open key:",
    ["tip.autoHide"] = "Auto-hide:",
    ["tip.overhead"] = "Text above your character:",
    ["tip.on"] = "on",
    ["tip.off"] = "off",
    ["tip.keyListening"] = "Press the new open key...",
    ["tip.fontDown"] = "Smaller text",
    ["tip.fontUp"] = "Bigger text",
    ["tip.activeDown"] = "Lower opacity while typing",
    ["tip.activeUp"] = "Higher opacity while typing",
    ["tip.idleDown"] = "Lower opacity when idle",
    ["tip.idleUp"] = "Higher opacity when idle",
    ["dice.short.active"] = "Active",
    ["dice.short.passive"] = "Passive",
    ["dice.advantageOption"] = "Advantage",
    ["dice.tierLabel"] = "%s (DC %d)",
    ["dice.tier.VeryEasy"] = "Very easy",
    ["dice.tier.Easy"] = "Easy",
    ["dice.tier.Medium"] = "Medium",
    ["dice.tier.Hard"] = "Hard",
    ["dice.tier.VeryHard"] = "Very hard",
    ["dice.tier.NearlyImpossible"] = "Nearly impossible",
    ["dice.success"] = "success",
    ["dice.failure"] = "failure",
    ["dice.criticalSuccess"] = "critical success!",
    ["dice.criticalFailure"] = "critical failure!",
    ["dice.cancelled"] = "roll cancelled",
    ["dice.overhead"] = "%s : %s",
    ["dice.noDifficultyClass"] = "~ This DC is not available, the roll could not be made ~",
    ["ability.short.Strength"]     = "STR",
    ["ability.short.Dexterity"]    = "DEX",
    ["ability.short.Constitution"] = "CON",
    ["ability.short.Intelligence"] = "INT",
    ["ability.short.Wisdom"]       = "WIS",
    ["ability.short.Charisma"]     = "CHA",
    ["ability.Strength"]     = "Strength",
    ["ability.Dexterity"]    = "Dexterity",
    ["ability.Constitution"] = "Constitution",
    ["ability.Intelligence"] = "Intelligence",
    ["ability.Wisdom"]       = "Wisdom",
    ["ability.Charisma"]     = "Charisma",
    ["skill.Acrobatics"]     = "Acrobatics",
    ["skill.AnimalHandling"] = "Animal Handling",
    ["skill.Arcana"]         = "Arcana",
    ["skill.Athletics"]      = "Athletics",
    ["skill.Deception"]      = "Deception",
    ["skill.History"]        = "History",
    ["skill.Insight"]        = "Insight",
    ["skill.Intimidation"]   = "Intimidation",
    ["skill.Investigation"]  = "Investigation",
    ["skill.Medicine"]       = "Medicine",
    ["skill.Nature"]         = "Nature",
    ["skill.Perception"]     = "Perception",
    ["skill.Performance"]    = "Performance",
    ["skill.Persuasion"]     = "Persuasion",
    ["skill.Religion"]       = "Religion",
    ["skill.SleightOfHand"]  = "Sleight of Hand",
    ["skill.Stealth"]        = "Stealth",
    ["skill.Survival"]       = "Survival",
}

local function _text(key)
    local fallback = ENGLISH[key]
    local handle = HANDLES[key] or GAME[key]
    if handle then
        local ok, s = pcall(Ext.Loca.GetTranslatedString, handle, fallback or key)
        if ok and type(s) == "string" and s ~= "" and s ~= handle then return s end
    end
    return fallback or key
end

function Lang.T(key, ...)
    local s = _text(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, s, ...)
        if ok then return formatted end
    end
    return s
end

_G.__NATIVECHAT_LANG = Lang

return Lang
