local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Version 14 (RESTORED & STABILIZED)
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Parse Focus Math (Fixed for ROF2: Uses Attrib and Base2)
local function parseFocus(fName)
    local name = tostring(fName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = false
    local effects = {}

    for i=1, 12 do
        local attrib = 0
        pcall(function() attrib = s.Attrib(i)() or 0 end)
        
        local val = 0
        pcall(function()
            -- ROF2 focus values can be in Base1 or Base2
            local b1 = math.abs(s.Base(i)() or 0)
            local b2 = math.abs(s.Base2(i)() or 0)
            val = math.max(b1, b2)
        end)
        
        -- Attrib 138 is Limit: Spell Type (0=Detrimental, 1=Beneficial)
        if attrib == 138 and s.Base(i)() == 1 then isBene = true
        elseif attrib > 0 and val >= 1 then
            if not effects[attrib] or val > effects[attrib] then
                effects[attrib] = val
            end
        end
    end
    
    local prefix = isBene and "Bene " or "Detri "
    for attrib, val in pairs(effects) do
        -- Mapping based on ROF2 Attrib/SPA IDs
        if attrib == 15 or attrib == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
        elseif attrib == 108 or attrib == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
        elseif attrib == 104 or attrib == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
        elseif attrib == 105 or attrib == 125 then desc = desc .. "Healing " .. val .. "%; "
        elseif attrib == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
        elseif attrib == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
        elseif attrib == 114 then desc = desc .. "Hate " .. val .. "%; "
        elseif attrib == 178 then desc = desc .. "Melee Lifetap " .. val .. "%; "
        elseif attrib == 174 then desc = desc .. "Dodge " .. val .. "%; "
        elseif attrib == 175 then desc = desc .. "Parry " .. val .. "%; "
        elseif attrib == 168 then desc = desc .. "Melee Crit " .. val .. "%; "
        elseif attrib == 192 then desc = desc .. "Spell Crit " .. val .. "%; "
        elseif attrib == 169 then desc = desc .. "Cleave " .. val .. "; "
        elseif attrib == 100 then desc = desc .. "Ferocity " .. val .. "; "
        elseif attrib == 4 or attrib == 216 or attrib == 184 then desc = desc .. "Accuracy " .. val .. "; "
        elseif attrib == 177 then desc = desc .. "Double Attack " .. val .. "%; "
        elseif attrib == 294 then desc = desc .. "Spell Crit Chance " .. val .. "%; "
        elseif attrib == 273 then desc = desc .. "Melee Crit Chance " .. val .. "%; "
        elseif attrib == 85 then desc = desc .. "Proc Rate " .. val .. "%; "
        elseif attrib == 13 then desc = desc .. "See Invis; "
        elseif attrib == 66 then desc = desc .. "Ultravision; "
        elseif attrib == 14 then desc = desc .. "Enduring Breath; "
        elseif attrib == 46 then desc = desc .. "Poison Resist " .. val .. "; "
        elseif attrib == 47 then desc = desc .. "Magic Resist " .. val .. "; "
        elseif attrib == 48 then desc = desc .. "Fire Resist " .. val .. "; "
        elseif attrib == 50 then desc = desc .. "Cold Resist " .. val .. "; "
        elseif attrib == 49 then desc = desc .. "Disease Resist " .. val .. "; "
        elseif attrib == 383 then desc = desc .. "Sympathetic Proc; "
        elseif attrib == 348 then desc = desc .. "Mana Proc (" .. val .. "); "
        elseif attrib == 142 then desc = desc .. "Max HP " .. val .. "; "
        elseif attrib == 10 then desc = desc .. "Proc/Direct Dmg (" .. val .. "); "
        end
    end
    
    -- Fallback: If we have effects but no mapping, use the spell description
    if desc == "" and next(effects) then
        local sDesc = s.Description()
        if sDesc and sDesc ~= "NULL" and sDesc ~= "" then
            desc = sDesc:gsub("#1", effects[10] or effects[1] or "?"):gsub("@1", effects[10] or effects[1] or "?")
        end
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return desc:gsub(",", "")
end

local function startCollecting()
    printf("\ag[GearLog]\ax Initializing Collection loop...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local line = table.concat({...}, " ")
        local f = io.open(CSV_FILENAME, "a")
        if f then f:write(line .. "\n") f:close() end
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    local endTime = os.time() + 45
    while os.time() < endTime do
        mq.doevents()
        mq.delay(100)
    end
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete!")
end

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item and item() then
            local iName = tostring(item.Name()):gsub(",", "")
            local sName = tostring(mq.TLO.InvSlot(i).Name()):gsub(",", "")
            
            -- Safe Stat Extraction
            local ac = item.AC() or 0
            local hp = item.HP() or 0
            local mana = item.Mana() or 0
            local str = item.STR and item.STR() or 0
            local sta = item.STA and item.STA() or 0
            local int = item.INT and item.INT() or 0
            local wis = item.WIS and item.WIS() or 0
            local agi = item.AGI and item.AGI() or 0
            local dex = item.DEX and item.DEX() or 0
            local cha = item.CHA and item.CHA() or 0
            local hpregen = item.HPRegen and item.HPRegen() or 0
            local manaregen = item.ManaRegen and item.ManaRegen() or 0
            
            -- Safe Resists
            local svm = item.MR and item.MR() or item.SvMagic and item.SvMagic() or 0
            local svf = item.FR and item.FR() or item.SvFire and item.SvFire() or 0
            local svc = item.CR and item.CR() or item.SvCold and item.SvCold() or 0
            local svd = item.DR and item.DR() or item.SvDisease and item.SvDisease() or 0
            local svp = item.PR and item.PR() or item.SvPoison and item.SvPoison() or 0
            
            -- Focus Collection (Multiple slots)
            local focusNames = {}
            local focusDescs = {}
            local seen = {}
            
            -- Check for Skill Mods (e.g. Singing, Stringed, etc)
            local skillMod = ""
            local skillAmt = 0
            pcall(function()
                if item.SkillModifier then skillMod = tostring(item.SkillModifier()) end
                if item.SkillModifierAmount then skillAmt = item.SkillModifierAmount() end
                
                -- ROF2 backup naming
                if skillMod == "" or skillMod == "nil" then
                    if item.SkillModType then skillMod = tostring(item.SkillModType()) end
                    if item.SkillModValue then skillAmt = item.SkillModValue() end
                end
            end)

            if skillMod ~= "" and skillMod ~= "nil" and skillMod ~= "NULL" and skillAmt > 0 then
                table.insert(focusNames, skillMod .. " Mod")
                table.insert(focusDescs, "+" .. skillAmt)
            end

            local possibleEffects = { "Focus", "Worn", "Spell", "Clicky", "Proc" }
            for _, effType in ipairs(possibleEffects) do
                local val = tostring(item[effType])
                if val ~= "NULL" and val ~= "nil" and val ~= "" and not seen[val] then
                    table.insert(focusNames, val)
                    local d = parseFocus(val)
                    if d ~= "" then 
                        table.insert(focusDescs, d) 
                    else
                        -- If it's a Clicky or Proc with no numeric focus data, at least mark it
                        if effType == "Clicky" or effType == "Proc" then
                            table.insert(focusDescs, "[" .. effType .. "]")
                        end
                    end
                    seen[val] = true
                end
            end
            
            local finalFocusName = table.concat(focusNames, " | ")
            local finalFocusDesc = table.concat(focusDescs, " | ")
            
            local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, finalFocusName, finalFocusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(30)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
