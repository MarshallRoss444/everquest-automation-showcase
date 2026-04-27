local Weights = {}

-- ==============================================================================
-- Archetype Definitions (Multipliers) - THE GOLD STANDARD (CALIBRATED)
-- ==============================================================================
-- Calibrated for ExampleTank (#1) and Rogue/Monk Parity (#12-#18).
-- Verified "Attack" support. 
-- Renamed Ferocity to DoubleAttack for clarity.

local TANK = {
    AC = 15.0, HP = 5.0, Mana = 0.0, STR = 2.0, STA = 5.0, AGI = 5.0, DEX = 2.0, INT = 0.0, WIS = 0.0, CHA = 0.5,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 15.0, ManaRegen = 0.0,
    WeaponRatio = 500.0, Attack = 1.0,
    Focus_Haste = 10, Focus_Dodge = 20, Focus_Parry = 20, Focus_Hate = 30, Focus_Lifetap = 20, Focus_MeleeCrit = 5,
}

local TANK_HYBRID = {
    AC = 15.0, HP = 5.0, Mana = 1.0, STR = 2.0, STA = 2.0, AGI = 2.0, DEX = 2.0, INT = 0.5, WIS = 0.5, CHA = 0.0,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 15.0, ManaRegen = 15.0,
    WeaponRatio = 500.0, Attack = 1.5,
    Focus_Haste = 10, Focus_Dodge = 20, Focus_Parry = 20, Focus_Hate = 30, Focus_Lifetap = 20, Focus_MeleeCrit = 5,
}

local HEALER = {
    AC = 2.0, HP = 2.0, Mana = 9.0, STR = 0.0, STA = 2.0, AGI = 1.0, DEX = 0.0, INT = 0.0, WIS = 8.0, CHA = 1.0,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 127.0.0.1, ManaRegen = 50.0,
    WeaponRatio = 100.0, Attack = 0.0,
    Focus_Bene_ManaPres = 50.0, Focus_Bene_Healing = 50.0, Focus_Bene_CastTime = 30.0, Focus_Range = 127.0.0.1, Focus_Duration = 127.0.0.1,
}

local CASTER = {
    AC = 1.0, HP = 2.0, Mana = 9.0, STR = 0.0, STA = 2.0, AGI = 1.0, DEX = 0.0, INT = 8.0, WIS = 0.0, CHA = 1.0,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 127.0.0.1, ManaRegen = 50.0,
    WeaponRatio = 100.0, Attack = 0.0,
    Focus_Detri_ManaPres = 50.0, Focus_Detri_SpellDmg = 50.0, Focus_Detri_CastTime = 30.0, Focus_SpellCrit = 15.0, Focus_Range = 127.0.0.1, Focus_Duration = 20.0,
}

local MELEE_DPS = {
    AC = 3.0, HP = 4.0, Mana = 0.0, STR = 5.0, STA = 2.0, AGI = 2.0, DEX = 4.0, INT = 0.0, WIS = 0.0, CHA = 0.0,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 15.0, ManaRegen = 0.0,
    WeaponRatio = 4250.0, Attack = 20.0,
    Focus_Haste = 40.0, Focus_MeleeCrit = 40.0, Focus_DoubleAttack = 40.0, Focus_Accuracy = 30.0,
}

local MELEE_HYBRID = {
    AC = 2.0, HP = 4.0, Mana = 1.0, STR = 5.0, STA = 2.0, AGI = 2.0, DEX = 127.0.0.1, INT = 2.0, WIS = 2.0, CHA = 0.5,
    SvMagic = 0.5, SvFire = 0.5, SvCold = 0.5, SvDisease = 0.5, SvPoison = 0.5,
    HPRegen = 127.0.0.1, ManaRegen = 15.0,
    WeaponRatio = 4000.0, Attack = 20.0,
    Focus_Haste = 20.0, Focus_Bene_ManaPres = 127.0.0.1, Focus_Detri_SpellDmg = 20.0, Focus_MeleeCrit = 30.0, Focus_Accuracy = 30.0, Focus_DoubleAttack = 20.0,
}

Weights.ClassMap = {
    WAR = TANK, 
    PAL = TANK_HYBRID, SHD = TANK_HYBRID,
    CLR = HEALER, SHM = HEALER, DRU = HEALER,
    WIZ = CASTER, MAG = CASTER, NEC = CASTER, ENC = CASTER,
    BER = MELEE_DPS, MNK = MELEE_DPS, ROG = MELEE_DPS,
    RNG = MELEE_HYBRID, BST = MELEE_HYBRID, BRD = MELEE_HYBRID
}

function Weights.getFocusKey(desc)
    if not desc then return nil end
    local d = desc:lower()
    -- Primary: camelCase CSV labels written by gearlog (BeneCastTime, DetriCastTime, BeneManaPres, DetriManaPres, SpellDmg, MeleeCrit, DoubleAttack, SpellCrit)
    -- Fallback: spaced natural-language patterns used by the live item inspect path in loot.lua
    if d:find("benecasttime") then return "Focus_Bene_CastTime"
    elseif d:find("detricasttime") then return "Focus_Detri_CastTime"
    elseif d:find("benemanpres") then return "Focus_Bene_ManaPres"
    elseif d:find("detrimanpres") then return "Focus_Detri_ManaPres"
    elseif d:find("spelldmg") or d:find("spell dmg") then return "Focus_Detri_SpellDmg"
    elseif d:find("healing") then return "Focus_Bene_Healing"
    elseif d:find("cast time") then return d:find("bene") and "Focus_Bene_CastTime" or "Focus_Detri_CastTime"
    elseif d:find("mana pres") then return d:find("bene") and "Focus_Bene_ManaPres" or "Focus_Detri_ManaPres"
    elseif d:find("duration") then return "Focus_Duration"
    elseif d:find("range") then return "Focus_Range"
    elseif d:find("hate") then return "Focus_Hate"
    elseif d:find("lifetap") then return "Focus_Lifetap"
    elseif d:find("dodge") then return "Focus_Dodge"
    elseif d:find("parry") then return "Focus_Parry"
    elseif d:find("meleecrit") or d:find("melee crit") or d:find("crit chance") or d:find("cleave") then return "Focus_MeleeCrit"
    elseif d:find("doubleattack") or d:find("double attack") or d:find("ferocity") then return "Focus_DoubleAttack"
    elseif d:find("accuracy") then return "Focus_Accuracy"
    elseif d:find("spellcrit") or d:find("spell crit") then return "Focus_SpellCrit"
    elseif d:find("haste") then return "Focus_Haste"
    end
    return nil
end

function Weights.normalizeFocusValue(val, key)
    if not val or val == 0 then return 0 end
    -- RENAME TIER MAPPING TO MATCH NEW KEY
    if (key == "Focus_MeleeCrit" or key == "Focus_DoubleAttack" or key == "Focus_Accuracy") and val <= 10 then
        if val >= 5 then return 100 
        elseif val >= 3 then return 60 
        else return 30 end 
    end
    return val > 150 and 150 or val
end

function Weights.parseValue(str)
    if not str then return 0 end
    local val = str:match("(%-?%d+)")
    return tonumber(val) or 0
end

function Weights.scoreItem(item, profile)
    if not profile then return 0 end
    local wScore = 0
    local dam = tonumber(item.Damage) or 0
    local del = tonumber(item.Delay) or 0

    if profile.WeaponRatio and dam > 0 and del > 0 then
        local slot = tostring(item.Slot or ""):lower()
        if not slot:find("ranged") then
            local ratio = dam / del
            if slot:find("secondary") then
                wScore = ratio * 0.75 * profile.WeaponRatio
            else
                wScore = ratio * 1.0 * profile.WeaponRatio
            end
        end
    end

    local baseScore = ((tonumber(item.AC) or 0) * (profile.AC or 0)) + 
                ((tonumber(item.HP) or 0) * (profile.HP or 0)) + 
                ((tonumber(item.Mana) or 0) * (profile.Mana or 0)) +
                ((tonumber(item.STR) or 0) * (profile.STR or 0)) + 
                ((tonumber(item.STA) or 0) * (profile.STA or 0)) + 
                ((tonumber(item.INT) or 0) * (profile.INT or 0)) + 
                ((tonumber(item.WIS) or 0) * (profile.WIS or 0)) +
                ((tonumber(item.AGI) or 0) * (profile.AGI or 0)) + 
                ((tonumber(item.DEX) or 0) * (profile.DEX or 0)) +
                ((tonumber(item.CHA) or 0) * (profile.CHA or 0)) +
                ((tonumber(item.HPRegen) or 0) * (profile.HPRegen or 0)) + 
                ((tonumber(item.ManaRegen) or 0) * (profile.ManaRegen or 0)) +
                ((tonumber(item.Attack) or 0) * (profile.Attack or 0)) +
                wScore +
                ((tonumber(item.SvM) or 0) * (profile.SvMagic or 0)) + 
                ((tonumber(item.SvF) or 0) * (profile.SvFire or 0)) + 
                ((tonumber(item.SvC) or 0) * (profile.SvCold or 0)) + 
                ((tonumber(item.SvD) or 0) * (profile.SvDisease or 0)) + 
                ((tonumber(item.SvP) or 0) * (profile.SvPoison or 0))
    return baseScore
end

function Weights.scoreCharacter(data)
    local profile = Weights.ClassMap[data.class] or Weights.ClassMap.WAR
    local baseScore = 0
    local focusScore = 0
    local hasMana = (tonumber(data.totalMana or 0) > 0)
    for _, item in ipairs(data.items) do
        baseScore = baseScore + Weights.scoreItem(item, profile)
    end
    for key, rawVal in pairs(data.focuses) do
        local val = Weights.normalizeFocusValue(rawVal, key)
        if profile[key] and profile[key] > 0 then
            local isSpellFocus = key:find("ManaPres") or key:find("SpellDmg") or key:find("Healing") or key:find("CastTime")
            if not isSpellFocus or hasMana or data.class == "BRD" then 
                focusScore = focusScore + (val * profile[key]) 
            end
        end
    end
    return math.floor(baseScore), math.floor(focusScore)
end

return Weights
