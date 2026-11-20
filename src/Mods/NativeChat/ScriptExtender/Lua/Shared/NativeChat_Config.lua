local NativeChat_Config = {
    DefaultPanelW = 758,
    DefaultPanelH = 950,
    MinPanelW = 640,
    MinPanelH = 380,
    AnchorRight = 0,
    AnchorBottom = 580,
    InputMaxShare = 0.5,
    HotbarGap = 10,
    TabsH = 78,
    DicePanelW = 700,
    DicePanelGap = -21,
    SettingsBarGap = 2,
    TabsOverlap = 12,
    BarMarginW = 80,
    DefaultBarH = 66,
    PanelBorderInset = 21,

    HiddenUIStates = { "CharacterCreation", "Cinematic", "Cutscene", "Movie", "Video", "Loading", "MainMenu", "Credits", "Mirror" },

    DefaultActiveAlpha = 1.0,
    DefaultInactiveAlpha = 0.8,
    MinAlpha = 0.1,
    AlphaStep = 0.1,

    DefaultFontSize = 30,
    MinFontSize = 18,
    MaxFontSize = 40,
    FontSizeStep = 2,

    DefaultOpenKey = "RETURN",

    AutoHideDelaySeconds = 5,
    DefaultAutoHideEnabled = true,

    TypingIndicatorTimeoutSeconds = 4,

    NameRepeatDelaySeconds = 5 * 60,

    TypingBroadcastThrottleSeconds = 1.0,

    DefaultOverheadTextEnabled = true,

    EmoteColor = {0.62, 0.62, 0.68, 1.0},

    EditedColor = {0.45, 0.45, 0.45, 1.0},
    OocColor = {0.45, 0.45, 0.45, 1.0},

    MaxKeptMessages = 300,

    HistoryMaxMessages = 200,
    HistoryMaxChars = 100000,

    DiceAbilities = {
        { id = "Strength" },
        { id = "Dexterity" },
        { id = "Constitution" },
        { id = "Intelligence" },
        { id = "Wisdom" },
        { id = "Charisma" },
    },

    DiceSkills = {
        { id = "Deception" },
        { id = "Intimidation" },
        { id = "Performance" },
        { id = "Persuasion" },
        { id = "Acrobatics" },
        { id = "SleightOfHand" },
        { id = "Stealth" },
        { id = "Arcana" },
        { id = "History" },
        { id = "Investigation" },
        { id = "Nature" },
        { id = "Religion" },
        { id = "Athletics" },
        { id = "AnimalHandling" },
        { id = "Insight" },
        { id = "Medicine" },
        { id = "Perception" },
        { id = "Survival" },
    },

    DiceRollTypes = { "active", "passive" },

    DiceDifficultyTiers = {
        { id = "VeryEasy",         dc = 5,  uuid = "202194c2-0752-4897-9e35-8f035091289c" },
        { id = "Easy",             dc = 10, uuid = "40071305-b281-44d4-bd76-16e235a8d7ad" },
        { id = "Medium",           dc = 15, uuid = "6fd062ac-ed43-4e2b-b3e7-d8fa9f9ddc17" },
        { id = "Hard",             dc = 20, uuid = "f6b79ed8-7947-4e4a-ab75-4c2414f8b26a" },
        { id = "VeryHard",         dc = 25, uuid = "de96ee4a-c5b3-437f-9cb4-45dfa2f2ca28" },
        { id = "NearlyImpossible", dc = 30, uuid = "5d7868ab-b4e5-414d-9f91-e4a32623d60b" },
    },
    DiceDefaultTierIndex = 3,

    DicePendingRollTimeoutMs = 10 * 60 * 1000,
}

NativeChat_Config.DiceAbilityById = {}
for _, a in ipairs(NativeChat_Config.DiceAbilities) do NativeChat_Config.DiceAbilityById[a.id] = a end

NativeChat_Config.DiceSkillById = {}
for _, s in ipairs(NativeChat_Config.DiceSkills) do NativeChat_Config.DiceSkillById[s.id] = s end

NativeChat_Config.DiceRollTypeSet = {}
for _, t in ipairs(NativeChat_Config.DiceRollTypes) do NativeChat_Config.DiceRollTypeSet[t] = true end

NativeChat_Config.DiceTierById = {}
for _, t in ipairs(NativeChat_Config.DiceDifficultyTiers) do NativeChat_Config.DiceTierById[t.id] = t end

local function _single_difficulty(res)
    local ok, value = pcall(function()
        if res.Difficulties and #res.Difficulties == 1 then return res.Difficulties[1] end
        return nil
    end)

    if ok then return value end
    return nil
end

function NativeChat_Config.ResolveDiceDifficultyClasses()
    if not (Ext.StaticData and Ext.StaticData.Get) then return end

    local vanilla_by_dc = nil
    local function _vanilla(dc)
        if vanilla_by_dc == nil then
            vanilla_by_dc = {}
            pcall(function()
                for _, guid in ipairs(Ext.StaticData.GetAll("DifficultyClass")) do
                    local res = Ext.StaticData.Get(guid, "DifficultyClass")
                    local value = res and _single_difficulty(res)
                    if value and vanilla_by_dc[value] == nil then vanilla_by_dc[value] = guid end
                end
            end)
        end
        return vanilla_by_dc[dc]
    end

    for _, tier in ipairs(NativeChat_Config.DiceDifficultyTiers) do
        local ok = pcall(function()
            local res = Ext.StaticData.Get(tier.uuid, "DifficultyClass")
            if not res then res = Ext.StaticData.Create("DifficultyClass", tier.uuid) end
            if not res then error("create failed") end
            res.Name = "NativeChat_DC" .. tier.dc
            res.Difficulties = { tier.dc }
            if _single_difficulty(Ext.StaticData.Get(tier.uuid, "DifficultyClass")) ~= tier.dc then
                error("value not applied")
            end
        end)

        if ok then
            tier.guid = tier.uuid
        else
            tier.guid = _vanilla(tier.dc)
        end
    end
end

return NativeChat_Config
