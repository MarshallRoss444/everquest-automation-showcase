local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - THE FINAL PEACE TREATY (ROF2 Edition)
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Clean strings for safe network transfer (No commas or quotes!)
local function clean(str)
    if not str then return "" end
    local s = tostring(str)
    s = s:gsub(",", "")   -- Remove commas
    s = s:gsub("\"", "")  -- Remove double quotes
    s = s:gsub("'", "")   -- Remove single quotes
    return s:match("^%s*(.-)%s*$") -- Trim whitespace
end

-- Helper: Parse Focus Math (Absolute Max logic)
local function parseFocus(fName)
    local name = clean(fName)
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = nil
    local effects = {}

    for i=1, 12 do
        local spa = s.SPA(i)() or s.Attrib(i)() or 0
        local val = math.max(math.abs(s.Base(i)() or 0), math.abs(s.Max(i)() or 0))
        
        if spa == 138 then
            if s.Base(i)() == 1 then isBene = true elseif s.Base(i)() == 0 then isBene = false end
        elseif spa > 0 and val > 0 then
            if not effects[spa] or val > effects[spa] then
                effects[spa] = val
            end
        end
    end
    
    local prefix = ""
    if isBene == true then prefix = "Bene " elseif isBene == false then prefix = "Detri " end

    for spa, val in pairs(effects) do
        if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
        elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
        elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
        elseif spa == 105 or spa == 125 then desc = desc .. string.format("Healing %d%%; ", val)
        elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
        elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
        end
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return desc
end

-- MODE: COLLECT
local function startCollecting()
    printf("\ag[GearLog]\ax Starting 45s collection loop...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local line = table.concat({...}, " ")
        if not line or line == "" then return end
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
    printf("\ag[GearLog]\ax Complete! Check Logs/MyGearLog.csv")
end

-- MODE: SEND
local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item and item() then
            local itemName = clean(item.Name())
            local slotName = clean(mq.TLO.InvSlot(i).Name() or "unknown")
            
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
            local svm = item.svMagic() or item.MR() or 0
            local svf = item.svFire() or item.FR() or 0
            local svc = item.svCold() or item.CR() or 0
            local svd = item.svDisease() or item.DR() or 0
            local svp = item.svPoison() or item.PR() or 0
            local hpregen = item.HPRegen() or 0
            local manaregen = item.ManaRegen() or 0
            
            local focusName = ""
            local fRaw = tostring(item.Spell)
            local fRaw2 = tostring(item.Focus)
            if fRaw ~= "NULL" and fRaw ~= "nil" then focusName = clean(fRaw)
            elseif fRaw2 ~= "NULL" and fRaw2 ~= "nil" then focusName = clean(fRaw2) end
            
            local focusDesc = ""
            if focusName ~= "" then 
                focusDesc = parseFocus(focusName)
                printf("\ay[GearLog]\ax Found: \aw%s\ax (\ag%s\ax)", focusName, focusDesc)
            end
            
            -- No quotes in the dataLine anymore! Completely safe for network.
            local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                me, myClass, i, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(20)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
