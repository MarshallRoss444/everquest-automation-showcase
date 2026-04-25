local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Version 13 (Brute Force ROF2 Build)
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Clean strings
local function clean(str)
    if not str then return "" end
    local s = tostring(str)
    s = s:gsub(",", ""):gsub("\"", ""):gsub("'", "")
    return s:match("^%s*(.-)%s*$") or ""
end

-- Helper: Brute Force Focus Parser
local function parseFocus(sName)
    local name = tostring(sName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = nil
    
    -- Brute force scan of the first 6 slots (where 99% of focuses live)
    for i = 1, 6 do
        local spa = 0
        local val = 0
        
        -- Try every possible property name for SPA/Attrib
        pcall(function() spa = tonumber(s.SPA(i)()) or tonumber(s.Attrib(i)()) or 0 end)
        
        -- Try every possible property name for Value
        pcall(function() 
            local b = math.abs(tonumber(s.Base(i)()) or 0)
            local m = math.abs(tonumber(s.Max(i)()) or 0)
            local legacy = math.abs(tonumber(s["Base"..i]()) or 0)
            val = math.max(b, m, legacy)
        end)

        if spa == 138 then
            local raw = tonumber(s.Base(i)()) or 0
            if raw == 1 then isBene = true elseif raw == 0 then isBene = false end
        elseif spa > 0 and val > 1 then
            local prefix = ""
            if isBene == true then prefix = "Bene " elseif isBene == false then prefix = "Detri " end
            
            if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
            elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
            elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
            elseif spa == 105 or spa == 125 then desc = desc .. string.format("Healing %d%%; ", val)
            elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
            elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
            end
        end
    end
    
    if desc == "" then
        -- Diagnostics: If we found a focus but couldn't parse it, tell the user why
        printf("\ar[GearLog]\ax Found focus '%s' (ID: %d) but SPAs were empty.", name, s.ID())
    end
    
    return clean(desc:len() > 0 and desc:sub(1, -3) or "")
end

-- MODE: COLLECT
local function startCollecting()
    printf("\ag[GearLog]\ax Starting collection loop...")
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
    printf("\ag[GearLog]\ax Complete!")
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
            
            -- Core Stats
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
            
            -- Focus Logic
            local focusName = ""
            local focusDesc = ""
            
            -- Try Spell first (Original macro match)
            local s = tostring(item.Spell)
            if s ~= "NULL" and s ~= "nil" then
                focusName = clean(s)
                focusDesc = parseFocus(s)
            else
                -- Fallback to Focus
                local f = tostring(item.Focus)
                if f ~= "NULL" and f ~= "nil" then
                    focusName = clean(f)
                    focusDesc = parseFocus(f)
                end
            end
            
            if focusDesc ~= "" then
                printf("\ag[GearLog]\ax %s: %s", focusName, focusDesc)
            end
            
            local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(25)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
