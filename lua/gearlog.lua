local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Final Absolute Value ROF2 Build
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Final Focus Parser - Uses absolute values to fix the 1% and negative value bugs
local function parseFocus(focusName)
    if not focusName or focusName == "" or focusName == "NULL" then return "" end
    
    local desc = ""
    pcall(function()
        local s = mq.TLO.Spell(focusName)
        if not s or not s() or s.ID() == 0 then return end
        
        local isBene = nil
        local spas = {}
        local values = {}
        
        for i=1, 12 do
            local spa = 0
            pcall(function() spa = s.SPA(i)() or s.Attrib(i)() or 0 end)
            spas[i] = spa
            
            local v = 0
            pcall(function()
                -- Grab all possible value columns
                local b = s.Base(i)() or 0
                local m = s.Max(i)() or 0
                local l = 0
                if s.Limit then l = s.Limit(i)() or 0 end
                
                -- Use math.abs to handle negative mana pres/haste values
                -- We take the largest absolute value that isn't the '1' flag
                local potential = {math.abs(b), math.abs(m), math.abs(l)}
                local high = 0
                for _, val in ipairs(potential) do
                    if val > high then high = val end
                end
                v = high
            end)
            values[i] = v
            
            -- SPA 138 check for Bene/Detri
            if spa == 138 then
                local rawVal = s.Base(i)() or 0
                if rawVal == 1 then isBene = true elseif rawVal == 0 then isBene = false end
            end
        end
        
        local prefix = ""
        if isBene == true then prefix = "Bene " elseif isBene == false then prefix = "Detri " end

        for i=1, 12 do
            local spa = spas[i]
            local val = values[i]
            
            -- Filter: Focus SPAs usually have values > 1 (1 is just a flag)
            if spa > 0 and val > 1 then
                if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
                elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
                elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
                elseif spa == 105 or spa == 125 then desc = desc .. string.format("Healing %d%%; ", val)
                elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
                elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
                end
            end
        end
    end)
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return desc
end

local function startCollecting()
    printf("\ag[GearLog]\ax Starting centralized collection...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local f = io.open(CSV_FILENAME, "a")
        if f then f:write(table.concat({...}, " ") .. "\n") f:close() end
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    local endTime = os.time() + 45
    while os.time() < endTime do
        mq.doevents()
        mq.delay(100)
    end
    
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete! File: Logs/MyGearLog.csv")
end

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        pcall(function()
            local item = mq.TLO.Me.Inventory(i)
            if item and item() then
                local slotName = string.format("%d-%s", i, mq.TLO.InvSlot(i).Name() or "unknown")
                local itemName = item.Name() or "Unknown"
                
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
                local fRaw = item.Spell() or item.Focus() or ""
                if tostring(fRaw) ~= "NULL" then focusName = tostring(fRaw) end
                local focusDesc = parseFocus(focusName)
                
                local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\",\"%s\"",
                    me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
                
                mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
                mq.delay(20)
            end
        end)
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end