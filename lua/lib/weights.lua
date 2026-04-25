local Weights = {}

-- ==============================================================================
-- Archetype Definitions (Multipliers) - STRICT ROLE-BASED
-- ==============================================================================
local TANK = {
    AC = 12.0, HP = 2.0, Mana = 0.0, STR = 1.0, STA = 3.0, AGI = 1.0, DEX = 1.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 127.0.0.1, ManaRegen = 0.0,
    Damage = 0.0, Delay = 0.0,
    -- Tanks ONLY care about Defense and Aggro
    Focus_Haste = 20, 
    Focus_Dodge = 100, 
    Focus_Parry = 100, 
    Focus_Hate = 150, 
    Focus_Lifetap = 100, 
    Focus_MeleeCrit = 100,
    -- Spell focuses are EXPLICITLY 0 for tanks
    Focus_Bene_ManaPres = 0, Focus_Detri_ManaPres = 0, Focus_Bene_Healing = 0, Focus_Detri_SpellDmg = 0
}

local HEALER = {
    AC = 0.5, HP = 2.0, Mana = 2.0, STR = 0.0, STA = 1.0, AGI = 0.5, DEX = 0.0, INT = 0.0, WIS = 3.0, CHA = 1.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 1.0, ManaRegen = 50.0,
    Damage = 0.0, Delay = 0.0,
    -- Healers ONLY care about Beneficial spell modifiers
    Focus_Bene_ManaPres = 100, 
    Focus_Bene_Healing = 150, 
    Focus_Bene_CastTime = 100, 
    Focus_Range = 50, 
    Focus_Duration = 50,
    -- Melee/Aggro/Detri stats are 0
    Focus_Hate = 0, Focus_MeleeCrit = 0, Focus_Detri_SpellDmg = 0
}

local CASTER = {
    AC = 0.5, HP = 2.0, Mana = 3.0, STR = 0.0, STA = 1.0, AGI = 0.5, DEX = 0.0, INT = 3.0, WIS = 0.0, CHA = 1.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 2.0, ManaRegen = 50.0,
    Damage = 0.0, Delay = 0.0,
    -- Casters care about Detrimental (Damage) and General Utility
    Focus_Detri_ManaPres = 80, 
    Focus_Detri_SpellDmg = 120, 
    Focus_Detri_CastTime = 80, 
    Focus_SpellCrit = 100, 
    Focus_Range = 50, 
    Focus_Duration = 80,
    -- Healing is 0
    Focus_Bene_Healing = 0
}

local MELEE_DPS = {
    AC = 2.0, HP = 2.0, Mana = 0.0, STR = 3.0, STA = 2.0, AGI = 1.5, DEX = 3.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 5.0, ManaRegen = 0.0,
    Damage = 100.0, Delay = -50.0,
    -- Melee care about Speed and Crits
    Focus_Haste = 100, 
    Focus_MeleeCrit = 150, 
    Focus_Ferocity = 150, 
    Focus_Cleave = 150, 
    Focus_Accuracy = 100, 
    Focus_DoubleAttack = 100,
    -- All spell focuses are 0
    Focus_Bene_Healing = 0, Focus_Bene_ManaPres = 0
}

local HYBRID_DPS = {
    AC = 4.0, HP = 2.0, Mana = 2.0, STR = 2.0, STA = 2.0, AGI = 1.5, DEX = 2.0, INT = 2.0, WIS = 2.0, CHA = 0.0,
    SvMagic = 2.0, SvFire = 2.0, SvCold = 2.0, SvDisease = 2.0, SvPoison = 2.0,
    HPRegen = 5.0, ManaRegen = 25.0,
    Damage = 75.0, Delay = -30.0,
    -- Hybrids get a mix but weighted lower
    Focus_Haste = 50, Focus_Bene_ManaPres = 50, Focus_Detri_SpellDmg = 50, Focus_MeleeCrit = 100, Focus_Accuracy = 50
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

-- Helper: Map generic descriptions to Focus multiplier keys with BENE/DETRI support
function Weights.getFocusKey(desc)
    if not desc then return nil end
    local d = desc:lower()
    local isBene = d:find("bene")
    local isDetri = d:find("detri")

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

function Weights.parseValue(str)
    if not str then return 0 end
    local val = str:match("(%-?%d+)")
    return tonumber(val) or 0
end

-- Helper: Normalize and Cap focus values to prevent "Cleave 77" from breaking math
function Weights.normalizeValue(val, key)
    if not val or val == 0 then return 0 end
    
    -- Cleave, Accuracy, Ferocity usually use raw numbers (e.g. 77, 100)
    -- Percentages (Mana Pres, etc) usually top out at 30-50%.
    if val > 50 then
        -- For Cleave 77, treat it as a high-tier (e.g. Tier 8 = 40 pts)
        return 20 + math.floor(val / 5) 
    end
    return val
end

function Weights.calculateItemScore(itemData, classShortName, characterBestFocuses, characterMana)
    local profile = Weights.ClassMap[classShortName] or Weights.ClassMap.WAR 
    local score = 0
    local hasMana = (tonumber(characterMana or 0) > 0)

    -- 1. Base Stats (Primary Driver)
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
    score = score + (tonumber(itemData.Damage or 0) * profile.Damage)
    score = score + (tonumber(itemData.Delay or 0) * profile.Delay)
    score = score + (tonumber(itemData.SvM or 0) * profile.SvMagic)
    score = score + (tonumber(itemData.SvF or 0) * profile.SvFire)
    score = score + (tonumber(itemData.SvC or 0) * profile.SvCold)
    score = score + (tonumber(itemData.SvD or 0) * profile.SvDisease)
    score = score + (tonumber(itemData.SvP or 0) * profile.SvPoison)

    -- 2. Focus Effects (Secondary Driver)
    if itemData.FocusDesc and itemData.FocusDesc ~= "" then
        for part in itemData.FocusDesc:gmatch("([^|;%-]+)") do
            local key = Weights.getFocusKey(part)
            local rawVal = Weights.parseValue(part)
            local val = Weights.normalizeValue(rawVal, key)
            
            if key and val > 0 and (profile[key] or 0) > 0 then
                -- ROLE PROTECTION: Strip spell focuses from non-mana users
                local isSpellFocus = key:find("ManaPres") or key:find("SpellDmg") or key:find("Healing") or key:find("CastTime")
                if not isSpellFocus or hasMana then
                    local currentBest = characterBestFocuses[key] or 0
                    if val > currentBest then
                        local improvement = val - currentBest
                        score = score + (improvement * profile[key])
                    end
                end
            end
        end
    end

    if itemData.FocusDesc:find("%+") then
        local val = itemData.FocusDesc:match("%+(%d+)")
        if val then score = score + (tonumber(val) * 10) end
    end

    return math.floor(score)
end

return Weights
