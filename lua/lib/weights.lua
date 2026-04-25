local Weights = {}

-- ==============================================================================
-- Archetype Definitions (Multipliers)
-- ==============================================================================
local TANK = {
    AC = 127.0.0.1, HP = 1.0, Mana = 0.0, STR = 1.0, STA = 2.0, AGI = 1.0, DEX = 1.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 1.0, SvFire = 1.0, SvCold = 1.0, SvDisease = 1.0, SvPoison = 1.0,
    HPRegen = 5.0, ManaRegen = 0.0,
    -- Focus Multipliers (Per 1%)
    Focus_Haste = 50, Focus_Dodge = 100, Focus_Parry = 100, Focus_Hate = 200, Focus_Lifetap = 200, Focus_MeleeCrit = 150,
}

local HEALER = {
    AC = 0.5, HP = 2.0, Mana = 2.0, STR = 0.0, STA = 1.0, AGI = 0.5, DEX = 0.0, INT = 0.0, WIS = 2.0, CHA = 1.0,
    SvMagic = 1.0, SvFire = 1.0, SvCold = 1.0, SvDisease = 1.0, SvPoison = 1.0,
    HPRegen = 1.0, ManaRegen = 25.0,
    -- Focus Multipliers (Per 1%)
    Focus_ManaPres = 200, Focus_Healing = 300, Focus_CastTime = 150, Focus_Range = 50, Focus_Duration = 50,
}

local CASTER = {
    AC = 0.5, HP = 2.0, Mana = 2.5, STR = 0.0, STA = 1.0, AGI = 0.5, DEX = 0.0, INT = 2.0, WIS = 0.0, CHA = 1.0,
    SvMagic = 1.0, SvFire = 1.0, SvCold = 1.0, SvDisease = 1.0, SvPoison = 1.0,
    HPRegen = 1.0, ManaRegen = 25.0,
    -- Focus Multipliers (Per 1%)
    Focus_ManaPres = 200, Focus_SpellDmg = 250, Focus_CastTime = 150, Focus_Range = 50, Focus_Duration = 100, Focus_SpellCrit = 200,
}

local MELEE_DPS = {
    AC = 1.0, HP = 2.0, Mana = 0.0, STR = 2.0, STA = 1.5, AGI = 1.0, DEX = 2.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 1.0, SvFire = 1.0, SvCold = 1.0, SvDisease = 1.0, SvPoison = 1.0,
    HPRegen = 2.0, ManaRegen = 0.0,
    -- Focus Multipliers (Per 1%)
    Focus_Haste = 100, Focus_MeleeCrit = 250, Focus_Ferocity = 250, Focus_Cleave = 250, Focus_Accuracy = 150, Focus_DoubleAttack = 200,
}

local HYBRID_DPS = {
    AC = 2.0, HP = 2.0, Mana = 1.5, STR = 1.5, STA = 1.5, AGI = 1.0, DEX = 1.5, INT = 1.0, WIS = 1.0, CHA = 0.0,
    SvMagic = 1.0, SvFire = 1.0, SvCold = 1.0, SvDisease = 1.0, SvPoison = 1.0,
    HPRegen = 2.0, ManaRegen = 15.0,
    -- Mixed Focuses
    Focus_Haste = 75, Focus_ManaPres = 100, Focus_SpellDmg = 100, Focus_MeleeCrit = 150, Focus_Accuracy = 100,
}

-- ==============================================================================
-- Class Mapping
-- ==============================================================================
Weights.ClassMap = {
    WAR = TANK, PAL = TANK, SHD = TANK,
    CLR = HEALER, SHM = HEALER, DRU = HEALER,
    WIZ = CASTER, MAG = CASTER, NEC = CASTER, ENC = CASTER,
    BER = MELEE_DPS, MNK = MELEE_DPS, ROG = MELEE_DPS,
    RNG = HYBRID_DPS, BST = HYBRID_DPS, BRD = HYBRID_DPS
}

-- ==============================================================================
-- Logic Engine
-- ==============================================================================

-- Helper: Extract number from string like "Detri Spell Dmg 20%"
function Weights.parseValue(str)
    if not str then return 0 end
    local val = str:match("(%-?%d+)")
    return tonumber(val) or 0
end

-- Helper: Map generic descriptions to Focus multiplier keys
function Weights.getFocusKey(desc)
    if not desc then return nil end
    local d = desc:lower()
    if d:find("mana pres") then return "Focus_ManaPres"
    elseif d:find("spell dmg") then return "Focus_SpellDmg"
    elseif d:find("healing") then return "Focus_Healing"
    elseif d:find("cast time") then return "Focus_CastTime"
    elseif d:find("duration") then return "Focus_Duration"
    elseif d:find("range") then return "Focus_Range"
    elseif d:find("hate") then return "Focus_Hate"
    elseif d:find("lifetap") then return "Focus_Lifetap"
    elseif d:find("dodge") then return "Focus_Dodge"
    elseif d:find("parry") then return "Focus_Parry"
    elseif d:find("cleave") then return "Focus_Cleave"
    elseif d:find("ferocity") then return "Focus_Ferocity"
    elseif d:find("accuracy") then return "Focus_Accuracy"
    elseif d:find("melee crit") then return "Focus_MeleeCrit"
    elseif d:find("spell crit") then return "Focus_SpellCrit"
    elseif d:find("double attack") then return "Focus_DoubleAttack"
    elseif d:find("haste") then return "Focus_Haste"
    end
    return nil
end

function Weights.calculateItemScore(itemData, classShortName, characterBestFocuses)
    local profile = Weights.ClassMap[classShortName] or Weights.ClassMap.WAR -- Default to Warrior if unknown
    local score = 0

    -- 1. Base Stats
    score = score + (tonumber(itemData.AC or 0) * profile.AC)
    score = score + (tonumber(itemData.HP or 0) * profile.HP)
    score = score + (tonumber(itemData.Mana or 0) * profile.Mana)
    score = score + (tonumber(itemData.STR or 0) * profile.STR)
    score = score + (tonumber(itemData.STA or 0) * profile.STA)
    score = score + (tonumber(itemData.INT or 0) * profile.INT)
    score = score + (tonumber(itemData.WIS or 0) * profile.WIS)
    score = score + (tonumber(itemData.AGI or 0) * profile.AGI)
    score = score + (tonumber(itemData.DEX or 0) * profile.DEX)
    score = score + (tonumber(itemData.HPRegen or 0) * profile.HPRegen)
    score = score + (tonumber(itemData.ManaRegen or 0) * profile.ManaRegen)
    
    -- Resists
    score = score + (tonumber(itemData.SvM or 0) * profile.SvMagic)
    score = score + (tonumber(itemData.SvF or 0) * profile.SvFire)
    score = score + (tonumber(itemData.SvC or 0) * profile.SvCold)
    score = score + (tonumber(itemData.SvD or 0) * profile.SvDisease)
    score = score + (tonumber(itemData.SvP or 0) * profile.SvPoison)

    -- 2. Focus Effects (Non-Stacking Logic)
    -- characterBestFocuses should be a table: { Focus_ManaPres = 15, Focus_Haste = 21, ... }
    if itemData.FocusDesc and itemData.FocusDesc ~= "" then
        local parts = {}
        for part in itemData.FocusDesc:gmatch("([^|]+)") do
            local individualEffects = {}
            for eff in part:gmatch("([^;]+)") do
                local key = Weights.getFocusKey(eff)
                local val = Weights.parseValue(eff)
                
                if key and val > 0 and profile[key] then
                    -- Only score it if it's better than what they have, 
                    -- or if we are scoring a "Total character value" (in which case we pass an empty table)
                    local currentBest = characterBestFocuses[key] or 0
                    if val > currentBest then
                        local improvement = val - currentBest
                        score = score + (improvement * profile[key])
                    end
                end
            end
        end
    end

    -- Skill Mods (always count these)
    if itemData.FocusDesc:find("%+") then
        local val = itemData.FocusDesc:match("%+(%d+)")
        if val then score = score + (tonumber(val) * 10) end -- Flat 10 points per skill point
    end

    return math.floor(score)
end

return Weights
