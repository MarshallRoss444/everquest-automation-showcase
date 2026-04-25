local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Lua Edition
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local isCollecting = false
local INVENTORY_SLOTS = 21

-- HELPER: Log to console with color
local function log(msg) printf("\ag[GearLog]\ax %s", msg) end
local function error(msg) printf("\ar[GearLog]\ax %s", msg) end

-- Helper function to parse focus effect SPAs into readable strings
local function parseFocus(spellName)
    if not spellName or spellName == "" or spellName == "NULL" then return "" end
    
    local spell = mq.TLO.Spell(spellName)
    if not spell() or spell.ID() == 0 then return "" end
    
    local desc = ""
    local isBeneficial = nil
    
    -- Check for SPA 138 (Beneficial/Detrimental restriction)
    -- In older MQ2, we might need to check if .SPA exists or use .Attrib
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = spell.SPA(i)() or 0 end)
        local base = 0
        pcall(function() base = spell.Base(i)() or 0 end)

        if spa == 138 then
            if base == 1 then isBeneficial = true
            elseif base == 0 then isBeneficial = false end
        end
    end
    
    local prefix = ""
    if isBeneficial == true then prefix = "Bene "
    elseif isBeneficial == false then prefix = "Detri " end

    -- find the actual effect
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = spell.SPA(i)() or 0 end)
        local base = 0
        pcall(function() base = spell.Base(i)() or 0 end)
        
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
    
    if desc:len() > 0 then desc = desc:sub(1, -3) end
    return desc
end

-- ==============================================================================
-- MODE: COLLECT (Run on Driver)
-- ==============================================================================
local function startCollecting()
    log("Starting collection. Clearing old " .. CSV_FILENAME)
    local file, err = io.open(CSV_FILENAME, "w")
    if not file then error("Error opening file: " .. (err or "unknown")) return end
    
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    isCollecting = true
    mq.bind('/gearlog_add', function(...)
        local dataString = table.concat({...}, " ")
        if isCollecting then
            local f = io.open(CSV_FILENAME, "a")
            if f then f:write(dataString .. "\n") f:close() end
        end
    end)
    
    log("Listening for data (45s)... Telling army to send.")
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    local endTime = os.time() + 45
    while os.time() < endTime do mq.delay(100) end
    
    isCollecting = false
    mq.unbind('/gearlog_add')
    log("Collection complete!")
end

-- ==============================================================================
-- MODE: SEND (Run on Army)
-- ==============================================================================
local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item() ~= nil then
            local slotName = string.format("%d-%s", i, mq.TLO.InvSlot(i).Name())
            local itemName = item.Name() or ""
            
            -- Safe stat extraction
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
            local svm = item.svMagic and item.svMagic() or item.MR and item.MR() or 0
            local svf = item.svFire and item.svFire() or item.FR and item.FR() or 0
            local svc = item.svCold and item.svCold() or item.CR and item.CR() or 0
            local svd = item.svDisease and item.svDisease() or item.DR and item.DR() or 0
            local svp = item.svPoison and item.svPoison() or item.PR and item.PR() or 0
            local hpregen = item.HPRegen and item.HPRegen() or 0
            local manaregen = item.ManaRegen and item.ManaRegen() or 0
            
            -- Focus Extraction
            local focus = ""
            local f = item.Focus and item.Focus()
            if f and tostring(f) ~= "NULL" then
                focus = tostring(f)
            else
                local s = item.Spell and item.Spell()
                if s and tostring(s) ~= "NULL" then focus = tostring(s) end
            end
            
            local focusDesc = parseFocus(focus)
            
            local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\",\"%s\"",
                me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focus, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(20)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
