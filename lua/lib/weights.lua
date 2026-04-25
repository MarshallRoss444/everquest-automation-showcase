local Weights = {}

-- ==============================================================================
-- Archetype Definitions (Multipliers) - STRICT ROLE-BASED
-- ==============================================================================
local TANK = {
    AC = 12.0, HP = 2.0, Mana = 0.0, STR = 2.0, STA = 4.0, AGI = 1.5, DEX = 1.5, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 127.0.0.1, ManaRegen = 0.0,
    Damage = 0.0, Delay = 0.0,
    Focus_Haste = 10, Focus_Dodge = 20, Focus_Parry = 20, Focus_Hate = 30, Focus_Lifetap = 30, Focus_MeleeCrit = 30,
    Focus_Bene_ManaPres = 0, Focus_Detri_ManaPres = 0, Focus_Bene_Healing = 0, Focus_Detri_SpellDmg = 0
}

local HEALER = {
    AC = 1.0, HP = 3.0, Mana = 3.0, STR = 0.0, STA = 2.0, AGI = 0.5, DEX = 0.0, INT = 0.0, WIS = 4.0, CHA = 1.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 1.0, ManaRegen = 50.0,
    Damage = 0.0, Delay = 0.0,
    Focus_Bene_ManaPres = 30, Focus_Bene_Healing = 40, Focus_Bene_CastTime = 30, Focus_Range = 10, Focus_Duration = 10,
    Focus_Hate = 0, Focus_MeleeCrit = 0, Focus_Detri_SpellDmg = 0
}

local CASTER = {
    AC = 1.0, HP = 3.0, Mana = 4.0, STR = 0.0, STA = 2.0, AGI = 0.5, DEX = 0.0, INT = 5.0, WIS = 0.0, CHA = 1.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 2.0, ManaRegen = 50.0,
    Damage = 0.0, Delay = 0.0,
    Focus_Detri_ManaPres = 25, Focus_Detri_SpellDmg = 35, Focus_Detri_CastTime = 25, Focus_SpellCrit = 30, Focus_Range = 10, Focus_Duration = 15,
    Focus_Bene_Healing = 0
}

local MELEE_DPS = {
    AC = 2.0, HP = 3.0, Mana = 0.0, STR = 5.0, STA = 3.0, AGI = 2.0, DEX = 5.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 5.0, ManaRegen = 0.0,
    Damage = 100.0, Delay = -50.0,
    Focus_Haste = 30, Focus_MeleeCrit = 40, Focus_Ferocity = 40, Focus_Accuracy = 30, Focus_DoubleAttack = 30,
    Focus_Bene_Healing = 0, Focus_Bene_ManaPres = 0
}

local HYBRID_DPS = {
    AC = 5.0, HP = 3.0, Mana = 2.0, STR = 4.0, STA = 3.0, AGI = 2.0, DEX = 4.0, INT = 3.0, WIS = 3.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 5.0, ManaRegen = 25.0,
    Damage = 75.0, Delay = -30.0,
    Focus_Haste = 20, Focus_Bene_ManaPres = 15, Focus_Detri_SpellDmg = 20, Focus_MeleeCrit = 30, Focus_Accuracy = 20
}

Weights.ClassMap = {
    WAR = TANK, PAL = TANK, SHD = TANK,
    CLR = HEALER, SHM = HEALER, DRU = HEALER,
    WIZ = CASTER, MAG = CASTER, NEC = CASTER, ENC = CASTER,
    BER = MELEE_DPS, MNK = MELEE_DPS, ROG = MELEE_DPS,
    RNG = HYBRID_DPS, BST = HYBRID_DPS, BRD = HYBRID_DPS
}

-- Helper: Map generic descriptions to Focus multiplier keys
function Weights.getFocusKey(desc)
    if not desc then return nil end
    local d = desc:lower()
    local isBene = d:find("bene")

    if d:find("mana pres") then return isBene and "Focus_Bene_ManaPres" or "Focus_Detri_ManaPres"
    elseif d:find("spell dmg") then return "Focus_Detri_SpellDmg"
    elseif d:find("healing") then return "Focus_Bene_Healing"
    elseif d:find("cast time") then return isBene and "Focus_Bene_CastTime" or "Focus_Detri_CastTime"
    elseif d:find("duration") then return "Focus_Duration"
    elseif d:find("range") then return "Focus_Range"
    elseif d:find("hate") then return "Focus_Hate"
    elseif d:find("lifetap") then return "Focus_Lifetap"
    elseif d:find("dodge") then return "Focus_Dodge"
    elseif d:find("parry") then return "Focus_Parry"
    elseif d:find("melee crit") or d:find("crit chance") or d:find("cleave") then return "Focus_MeleeCrit"
    elseif d:find("ferocity") then return "Focus_Ferocity"
    elseif d:find("accuracy") then return "Focus_Accuracy"
    elseif d:find("spell crit") then return "Focus_SpellCrit"
    elseif d:find("double attack") then return "Focus_DoubleAttack"
    elseif d:find("haste") then return "Focus_Haste"
    end
    return nil
end

function Weights.parseValue(str)
    if not str then return 0 end
    local val = str:match("(%-?%d+)")
    return tonumber(val) or 0
end

-- Normalizes focus values to prevent skill IDs (like 77) from being counted as percentages
function Weights.normalizeValue(val, key)
    if not val or val == 0 then return 0 end
    
    -- Melee Crit Chance (SPA 169) normalization
    if key == "Focus_MeleeCrit" then
        if val > 100 then return 40 -- Normalized to Max Tier
        elseif val > 50 then return 30 -- High Tier (e.g. Madness Sigil 65%)
        elseif val > 20 then return 20 -- Mid Tier
        elseif val > 0 then return 15  -- Low Tier (e.g. Sleeves 16%)
        end
    end

    -- Accuracy/Ferocity fixes
    if key == "Focus_Accuracy" or key == "Focus_Ferocity" then
        if val > 50 then return 25 + math.floor(val / 10) end
    end

    -- General Cap for standard percentages
    if val > 50 and not key:find("Haste") then return 40 end
    
    return val
end

-- Central Scoring logic - Shared by Console and Report
function Weights.scoreCharacter(data)
    local profile = Weights.ClassMap[data.class] or Weights.ClassMap.WAR
    local baseScore = 0
    local focusScore = 0
    local hasMana = (tonumber(data.totalMana or 0) > 0)

    -- 1. Base Stats
    for _, item in ipairs(data.items) do
        baseScore = baseScore + (item.AC * profile.AC) + (item.HP * profile.HP) + (item.Mana * profile.Mana) +
                    (item.STR * profile.STR) + (item.STA * profile.STA) + (item.INT * profile.INT) + (item.WIS * profile.WIS) +
                    (item.HPRegen * profile.HPRegen) + (item.ManaRegen * profile.ManaRegen) +
                    (item.Damage * profile.Damage) + (item.Delay * profile.Delay) +
                    (item.SvM * profile.SvMagic) + (item.SvF * profile.SvFire) + (item.SvC * profile.SvCold) + (item.SvD * profile.SvDisease) + (item.SvP * profile.SvPoison)
    end

    -- 2. Focuses (Character Wide)
    for key, rawVal in pairs(data.focuses) do
        local val = Weights.normalizeValue(rawVal, key)
        if profile[key] and profile[key] > 0 then
            local isSpellFocus = key:find("ManaPres") or key:find("SpellDmg") or key:find("Healing") or key:find("CastTime")
            if not isSpellFocus or hasMana then
                focusScore = focusScore + (val * profile[key])
            end
        end
    end

    return math.floor(baseScore), math.floor(focusScore)
end

return Weights
