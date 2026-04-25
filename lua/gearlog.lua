local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - THE CLAUDE-STYLE "BACK TO BASICS" FIX
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Match exactly what worked in your old macro
local function clean(str)
    if not str then return "" end
    local s = tostring(str)
    if s == "NULL" or s == "nil" then return "" end
    return s:gsub(",", ""):gsub("\"", ""):match("^%s*(.-)%s*$") or ""
end

-- Helper: Rebuilt Focus Parser using ID lookup and Slot iteration
local function parseFocus(focusName)
    local name = tostring(focusName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    -- Ask the game for the spell object
    local s = mq.TLO.Spell(name)
    if not s() then return "" end
    
    local desc = ""
    local isBene = false
    
    -- Check first for SPA 138 (Beneficial/Detrimental)
    for i = 1, 12 do
        local spa = s.SPA(i)() or s.Attrib(i)() or 0
        local base = s.Base(i)() or 0
        if spa == 138 and base == 1 then isBene = true end
    end
    
    local prefix = isBene and "Bene " or "Detri "

    -- Extract Focus Values
    for i = 1, 12 do
        local spa = s.SPA(i)() or s.Attrib(i)() or 0
        local base = math.abs(s.Base(i)() or 0)
        local maxVal = math.abs(s.Max(i)() or 0)
        local finalVal = math.max(base, maxVal)

        -- Skip internal flags/counters
        if spa > 0 and finalVal > 1 then
            if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, finalVal)
            elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, finalVal)
            elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, finalVal)
            elseif spa == 105 or spa == 125 then desc = desc .. "Healing " .. finalVal .. "%; "
            elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, finalVal)
            elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, finalVal)
            end
        end
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return clean(desc)
end

local function startCollecting()
    printf("\ag[GearLog]\ax Initializing Centralized Collection...")
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

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item() then
            local iName = clean(item.Name())
            local sName = clean(mq.TLO.InvSlot(i).Name())
            
            -- Direct TLO access for stats
            local ac = item.AC() or 0
            local hp = item.HP() or 0
            local mana = item.Mana() or 0
            local str = item.STR() or 0
            local sta = item.STA() or 0
            local int = item.INT() or 0
            local hpregen = item.HPRegen() or 0
            local manaregen = item.ManaRegen() or 0
            
            -- RESISTS: Check multiple names
            local svm = item.SvMagic() or item.MR() or 0
            local svf = item.SvFire() or item.FR() or 0
            local svc = item.SvCold() or item.CR() or 0
            local svd = item.SvDisease() or item.DR() or 0
            local svp = item.SvPoison() or item.PR() or 0
            
            -- FOCUS: The "Original Macro" Pattern
            local focusName = clean(item.Spell())
            local focusDesc = ""
            
            if focusName ~= "" then
                focusDesc = parseFocus(focusName)
                printf("\ag[GearLog]\ax Local Found: \ay%s\ax (\ag%s\ax)", focusName, focusDesc)
            end
            
            local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, 0, 0, 0, 0, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(20)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
