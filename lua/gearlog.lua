local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Version 15.2 (STABILIZED SAFETY)
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Parse Focus Math
local function parseFocus(fName)
    local name = tostring(fName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = false
    local effects = {}
    local slot1Attrib = 0

    for i=1, 12 do
        local attrib = 0
        pcall(function() attrib = s.Attrib(i)() or 0 end)
        if i == 1 then slot1Attrib = attrib end
        local val = 0
        pcall(function()
            local b1 = math.abs(s.Base(i)() or 0)
            local b2 = math.abs(s.Base2(i)() or 0)
            val = math.max(b1, b2)
        end)
        if attrib == 138 and s.Base(i)() == 1 then isBene = true
        elseif attrib > 0 and val >= 1 then
            if not effects[attrib] or val > effects[attrib] then effects[attrib] = val end
        end
    end
    
    local prefix = isBene and "Bene " or "Detri "
    for attrib, val in pairs(effects) do
        if attrib == 15 or attrib == 127 then desc = desc .. string.format("%sCast Time %d%% - ", prefix, val)
        elseif attrib == 108 or attrib == 132 then desc = desc .. string.format("%sMana Pres %d%% - ", prefix, val)
        elseif attrib == 104 or attrib == 124 then desc = desc .. string.format("%sSpell Dmg %d%% - ", prefix, val)
        elseif attrib == 105 or attrib == 125 then desc = desc .. "Healing " .. val .. "% - "
        elseif attrib == 128 then desc = desc .. string.format("%sDuration %d%% - ", prefix, val)
        elseif attrib == 129 then desc = desc .. string.format("%sRange %d%% - ", prefix, val)
        elseif attrib == 114 then desc = desc .. "Hate " .. val .. "% - "
        elseif attrib == 178 then desc = desc .. "Melee Lifetap " .. val .. "% - "
        elseif attrib == 174 then desc = desc .. "Dodge " .. val .. "% - "
        elseif attrib == 175 then desc = desc .. "Parry " .. val .. "% - "
        elseif attrib == 168 then desc = desc .. "Melee Crit " .. val .. "% - "
        elseif attrib == 192 then desc = desc .. "Spell Crit " .. val .. "% - "
        elseif attrib == 169 or attrib == 168 then desc = desc .. "Melee Crit Chance " .. val .. "% - "
        elseif attrib == 100 then desc = desc .. "Ferocity " .. val .. " - "
        elseif attrib == 4 or attrib == 216 or attrib == 184 then desc = desc .. "Accuracy " .. val .. " - "
        elseif attrib == 177 then desc = desc .. "Double Attack " .. val .. "% - "
        elseif attrib == 294 then desc = desc .. "Spell Crit Chance " .. val .. "% - "
        elseif attrib == 273 then desc = desc .. "Melee Crit Chance " .. val .. "% - "
        elseif attrib == 296 then desc = desc .. "Inc Spell Dmg " .. val .. "% - "
        elseif attrib == 297 then desc = desc .. "Inc Melee Dmg " .. val .. "% - "
        elseif attrib == 85 then 
            if val > 1000 then
                local procSpell = mq.TLO.Spell(val)
                desc = desc .. string.format("Proc: %s - ", procSpell() or "Unknown")
            else desc = desc .. "Proc Rate " .. val .. "% - " end
        elseif attrib == 13 then desc = desc .. "See Invis - "
        elseif attrib == 66 then desc = desc .. "Ultravision - "
        elseif attrib == 14 then desc = desc .. "Enduring Breath - "
        elseif attrib == 46 then desc = desc .. "Poison Resist " .. val .. " - "
        elseif attrib == 47 then desc = desc .. "Magic Resist " .. val .. " - "
        elseif attrib == 48 then desc = desc .. "Fire Resist " .. val .. " - "
        elseif attrib == 50 then desc = desc .. "Cold Resist " .. val .. " - "
        elseif attrib == 49 then desc = desc .. "Disease Resist " .. val .. " - "
        elseif attrib == 383 then desc = desc .. "Sympathetic Proc - "
        elseif attrib == 348 then desc = desc .. "Mana Proc (" .. val .. ") - "
        elseif attrib == 142 and val > 10 then desc = desc .. "Max HP " .. val .. " - "
        elseif attrib == 10 then desc = desc .. "Proc/Direct Dmg (" .. val .. ") - "
        elseif attrib == 11 then desc = desc .. "Hate " .. (val-100) .. "% - "
        end
    end
    
    if desc == "" or slot1Attrib == 296 or slot1Attrib == 297 then
        local sDesc = s.Description()
        if sDesc and sDesc ~= "NULL" and sDesc ~= "" and not sDesc:find("Unknown DB String") then
            for k,v in pairs(effects) do sDesc = sDesc:gsub("#" .. k, v):gsub("@" .. k, v) end
            local s1 = tostring(s.Base(1)() or "?")
            sDesc = sDesc:gsub("#1", s1):gsub("@1", s1):gsub(";", " -"):gsub(",", " ")
            if desc == "" then desc = sDesc else desc = desc .. " | " .. sDesc end
        end
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -4) end
    return desc:gsub(",", " "):gsub("|", "-") 
end

local function writeLine(line)
    local f = io.open(CSV_FILENAME, "a")
    if f then
        f:write(line:gsub("|", ",") .. "\n")
        f:close()
    end
end

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    local count = 0

    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item and item() then
            count = count + 1
            local iName = tostring(item.Name()):gsub(",", ""):gsub("|", "")
            local sName = tostring(mq.TLO.InvSlot(i).Name() or "Unknown"):gsub(",", ""):gsub("|", "")
            
            -- Safe Stat Extraction Logic
            local ac = (item.AC and item.AC()) or 0
            local hp = (item.HP and item.HP()) or 0
            local mana = (item.Mana and item.Mana()) or 0
            local str = (item.STR and item.STR()) or 0
            local sta = (item.STA and item.STA()) or 0
            local int = (item.INT and item.INT()) or 0
            local wis = (item.WIS and item.WIS()) or 0
            local agi = (item.AGI and item.AGI()) or 0
            local dex = (item.DEX and item.DEX()) or 0
            local cha = (item.CHA and item.CHA()) or 0
            local hpr = (item.HPRegen and item.HPRegen()) or 0
            local mnr = (item.ManaRegen and item.ManaRegen()) or 0
            
            -- Damage and Delay (Fixed for ROF2)
            local dam = (item.Damage and item.Damage()) or 0
            local del = (item.ItemDelay and item.ItemDelay()) or (item.Delay and item.Delay()) or 0
            
            -- Resists (using dual lookup for compatibility)
            local svm = (item.MR and item.MR()) or (item.SvMagic and item.SvMagic()) or 0
            local svf = (item.FR and item.FR()) or (item.SvFire and item.SvFire()) or 0
            local svc = (item.CR and item.CR()) or (item.SvCold and item.SvCold()) or 0
            local svd = (item.DR and item.DR()) or (item.SvDisease and item.SvDisease()) or 0
            local svp = (item.PR and item.PR()) or (item.SvPoison and item.SvPoison()) or 0
            
            local focusNames, focusDescs, focusTypes = {}, {}, {}
            local seen = {}
            
            local sm, sa = "", 0
            pcall(function() 
                sm = tostring(item.SkillModifier() or item.SkillModType() or "")
                sa = item.SkillModifierAmount() or item.SkillModValue() or 0
            end)
            if sm ~= "" and sm ~= "NULL" and sa > 0 then
                table.insert(focusNames, sm .. " Mod")
                table.insert(focusDescs, "+" .. sa)
                table.insert(focusTypes, "SkillMod")
            end

            local possible = { "Focus", "Worn", "Spell", "Clicky", "Proc" }
            for _, t in ipairs(possible) do
                local v = tostring(item[t])
                if v ~= "NULL" and v ~= "nil" and v ~= "" and not seen[v] then
                    table.insert(focusNames, v)
                    table.insert(focusTypes, t)
                    local d = parseFocus(v)
                    table.insert(focusDescs, d ~= "" and d or (t == "Clicky" and "[Clicky]" or "Utility"))
                    seen[v] = true
                end
            end
            
            local data = string.format("%s|%s|Item|%d-%s||%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha,
                svm, svf, svc, svd, svp, hpr, mnr, dam, del,
                table.concat(focusNames, " - "), table.concat(focusTypes, " - "), table.concat(focusDescs, " - "))

            if targetDriver == "local" then
                writeLine(data)
            else
                mq.cmdf("/dex %s /gearlog_add %s", targetDriver, data)
            end
            mq.delay(20)
        end
    end
    if targetDriver ~= "local" then
        printf("\ay[GearLog:Send]\ax Sent %d items to %s", count, targetDriver)
    end
end

local function startCollecting()
    printf("\ag[GearLog]\ax Initializing Robust Collection (v15.2)...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Damage,Delay,Focus,FocusType,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local data = table.concat({...}, " ")
        if not data or data == "" then return end
        writeLine(data)
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    sendData("local")
    
    local endTime = os.time() + 30
    while os.time() < endTime do
        mq.doevents()
        mq.delay(100)
    end
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete!")
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME) end
