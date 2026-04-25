local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Bulletproof ROF2 Build
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Bulletproof Focus Parser
local function parseFocus(focusName)
    if not focusName or focusName == "" or focusName == "NULL" then return "" end
    
    local desc = ""
    local success, err = pcall(function()
        local s = mq.TLO.Spell(focusName)
        if not s or not s() or s.ID() == 0 then return end
        
        local isBene = nil
        
        -- Safely extract SPA and Base arrays
        local spas = {}
        local bases = {}
        for i=1, 12 do
            local spa = 0
            pcall(function() spa = s.SPA(i)() end)
            if not spa or spa == 0 then pcall(function() spa = s.Attrib(i)() end) end
            spas[i] = spa or 0
            
            local base = 0
            pcall(function() base = s.Base(i)() end)
            if not base or base == 0 then pcall(function() base = s["Base"..i]() end) end
            bases[i] = base or 0
            
            -- Check for SPA 138 (Bene/Detri)
            if spas[i] == 138 then
                if bases[i] == 1 then isBene = true elseif bases[i] == 0 then isBene = false end
            end
        end
        
        local prefix = ""
        if isBene == true then prefix = "Bene " elseif isBene == false then prefix = "Detri " end

        -- Map SPAs
        for i=1, 12 do
            local spa = spas[i]
            local base = bases[i]
            
            if spa > 0 and base ~= 0 then
                if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, base)
                elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, base)
                elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, base)
                elseif spa == 105 or spa == 125 then desc = desc .. string.format("Healing %d%%; ", base)
                elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, base)
                elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, base)
                end
            end
        end
    end)
    
    if not success then
        printf("\ar[GearLog]\ax Parse Error on '%s': %s", focusName, tostring(err))
    end
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return desc
end

-- ==============================================================================
-- MODE: COLLECT
-- ==============================================================================
local function startCollecting()
    printf("\ag[GearLog]\ax Clearing CSV and listening for data...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local data = table.concat({...}, " ")
        local f = io.open(CSV_FILENAME, "a")
        if f then f:write(data .. "\n") f:close() end
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

-- ==============================================================================
-- MODE: SEND
-- ==============================================================================
local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local success, err = pcall(function()
            local item = mq.TLO.Me.Inventory(i)
            if item and item() then
                local slotName = string.format("%d-%s", i, mq.TLO.InvSlot(i).Name() or "unknown")
                local itemName = item.Name() or "Unknown"
                
                -- Stats (Evaluated directly but protected by outer pcall)
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
                
                -- Bulletproof Focus Search
                local focusName = ""
                pcall(function()
                    if item.Spell and item.Spell() then
                        focusName = item.Spell.Name() or ""
                    elseif item.Focus and item.Focus() then
                        focusName = item.Focus.Name() or ""
                    end
                end)
                
                local focusDesc = parseFocus(focusName)
                
                local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\",\"%s\"",
                    me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
                
                mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
                mq.delay(20)
            end
        end)
        
        -- If an item catastrophically fails, log the error but keep the script running!
        if not success then
            printf("\ar[GearLog]\ax Skipped slot %d due to error: %s", i, tostring(err))
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end