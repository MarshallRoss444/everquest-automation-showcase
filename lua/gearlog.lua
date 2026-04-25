local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - CRASH-PROOF ROF2 BUILD
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Clean strings for safe network transfer
local function clean(str)
    if not str then return "" end
    local s = tostring(str)
    if s == "NULL" or s == "nil" then return "" end
    s = s:gsub(",", ""):gsub("\"", "")
    return s:match("^%s*(.-)%s*$") or ""
end

-- Helper: Robust Focus Parsing
local function parseFocus(focusName)
    local name = tostring(focusName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = false
    
    -- Check for SPA 138 (Bene/Detri)
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = s.SPA(i)() or s.Attrib(i)() or 0 end)
        local base = 0
        pcall(function() base = s.Base(i)() or s.Base1() or 0 end)
        if spa == 138 and base == 1 then isBene = true end
    end
    
    local prefix = isBene and "Bene " or "Detri "

    -- Extract Focus Values using every possible property name
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = s.SPA(i)() or s.Attrib(i)() or 0 end)
        
        local val = 0
        pcall(function()
            local b = math.abs(s.Base(i)() or 0)
            local m = math.abs(s.Max(i)() or 0)
            -- Check legacy Base1, Base2 style properties
            local lName = "Base" .. i
            local lVal = s[lName] and math.abs(s[lName]() or 0) or 0
            val = math.max(b, m, lVal)
        end)

        if spa > 0 and val > 1 then
            if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
            elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
            elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
            elseif spa == 105 or spa == 125 then desc = desc .. "Healing " .. val .. "%; "
            elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
            elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
            end
        end
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return clean(desc)
end

-- MODE: COLLECT
local function startCollecting()
    printf("\ag[GearLog]\ax Clearing CSV and starting collection loop...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local line = table.concat({...}, " ")
        if line and line ~= "" then
            local f = io.open(CSV_FILENAME, "a")
            if f then f:write(line .. "\n") f:close() end
        end
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    local endTime = os.time() + 45
    while os.time() < endTime do
        mq.doevents()
        mq.delay(100)
    end
    
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete! Check Logs/MyGearLog.csv")
end

-- MODE: SEND
local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item and item() then
            local iName = clean(item.Name())
            local sName = clean(mq.TLO.InvSlot(i).Name() or "unknown")
            
            -- Stats (Using direct evaluation)
            local ac = item.AC() or 0
            local hp = item.HP() or 0
            local mana = item.Mana() or 0
            local str = item.STR() or 0
            local sta = item.STA() or 0
            local int = item.INT() or 0
            local wis = item.WIS() or 0
            local agi = item.AGI() or 0
            local dex = item.DEX() or 0
            local cha = item.CHA() or 0
            local hpregen = item.HPRegen() or 0
            local manaregen = item.ManaRegen() or 0
            
            -- RESISTS: THE CRASH-PROOF WAY
            local svm = 0
            if item.MR then svm = item.MR() or 0 elseif item.SvMagic then svm = item.SvMagic() or 0 end
            local svf = 0
            if item.FR then svf = item.FR() or 0 elseif item.SvFire then svf = item.SvFire() or 0 end
            local svc = 0
            if item.CR then svc = item.CR() or 0 elseif item.SvCold then svc = item.SvCold() or 0 end
            local svd = 0
            if item.DR then svd = item.DR() or 0 elseif item.SvDisease then svd = item.SvDisease() or 0 end
            local svp = 0
            if item.PR then svp = item.PR() or 0 elseif item.SvPoison then svp = item.SvPoison() or 0 end
            
            -- Focus Logic
            local focusName = clean(item.Spell())
            local focusDesc = ""
            
            if focusName ~= "" then 
                focusDesc = parseFocus(focusName)
                printf("\ay[GearLog]\ax Found: \aw%s\ax (\ag%s\ax)", focusName, focusDesc)
            end
            
            local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(20)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
