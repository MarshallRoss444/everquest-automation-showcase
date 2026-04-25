local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Lua Edition (ID-Based Focus Parsing)
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper function to parse focus effect by ID
local function parseFocusByID(spellID)
    if not spellID or spellID == 0 then return "" end
    
    local spell = mq.TLO.Spell(spellID)
    if not spell() then return "" end
    
    local desc = ""
    local isBeneficial = nil
    
    -- Check for SPA 138 (Beneficial/Detrimental restriction)
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = spell.SPA(i)() or 0 end)
        -- Fallback for very old builds
        if spa == 0 then pcall(function() spa = spell.Attrib(i)() or 0 end) end
        
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

    -- Find the actual effect
    for i=1, 12 do
        local spa = 0
        pcall(function() spa = spell.SPA(i)() or 0 end)
        if spa == 0 then pcall(function() spa = spell.Attrib(i)() or 0 end) end
        
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
-- MODE: COLLECT
-- ==============================================================================
local function startCollecting()
    printf("\ag[GearLog]\ax Starting collection...")
    local file, err = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local f = io.open(CSV_FILENAME, "a")
        if f then f:write(table.concat({...}, " ") .. "\n") f:close() end
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    mq.delay(45000) -- Listen for 45s
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete!")
end

-- ==============================================================================
-- MODE: SEND
-- ==============================================================================
local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item() ~= nil then
            local slotName = string.format("%d-%s", i, mq.TLO.InvSlot(i).Name())
            local itemName = item.Name() or ""
            
            -- Stats
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
            
            -- Focus by ID
            local focusName = ""
            local focusID = 0
            local f = item.Focus and item.Focus()
            if f and f.ID() > 0 then
                focusID = f.ID()
                focusName = f.Name()
            else
                local s = item.Spell and item.Spell()
                if s and s.ID() > 0 then
                    focusID = s.ID()
                    focusName = s.Name()
                end
            end
            
            local focusDesc = parseFocusByID(focusID)
            
            local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\",\"%s\"",
                me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
            
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(20)
        end
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
