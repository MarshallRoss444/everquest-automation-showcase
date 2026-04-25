local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Lua Edition
-- ==============================================================================
-- Usage:
--   /lua run gearlog collect   <- Run this on your driver (e.g. ExampleTank)
--                                 It will clear the old CSV, listen for data,
--                                 and tell the army to send their gear.
--   /lua run gearlog send      <- The army runs this to send data to the driver.
-- ==============================================================================

local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank" -- Set default driver name here

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local isCollecting = false

-- The slots we care about (0 through 21 typically)
local INVENTORY_SLOTS = 21

-- ==============================================================================
-- MODE: COLLECT (Run on Driver)
-- ==============================================================================
local function startCollecting()
    printf("\ag[GearLog]\ax Starting collection. Clearing old %s", CSV_FILENAME)
    
    -- Open file to overwrite and write headers
    local file, err = io.open(CSV_FILENAME, "w")
    if not file then
        printf("\ar[GearLog]\ax Error opening file for writing: %s", err)
        return
    end
    
    -- Write header (Added Base Stats, Resists, Regen, and removed Heal/Spell dmg)
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus\n")
    file:close()
    
    isCollecting = true
    
    -- Bind a custom command to receive the data quietly
    mq.bind('/gearlog_add', function(...)
        local dataString = table.concat({...}, " ")
        if isCollecting then
            local f = io.open(CSV_FILENAME, "a")
            if f then
                f:write(dataString .. "\n")
                f:close()
            end
        end
    end)
    
    printf("\ag[GearLog]\ax Listening for data... Telling the army to send.")
    
    -- Broadcast to everyone else to send their data
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    
    -- Also send our own data
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    -- Keep the script alive for 15 seconds to catch all the DanNet messages
    local endTime = os.time() + 15
    while os.time() < endTime do
        mq.delay(100)
    end
    
    isCollecting = false
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Collection complete! File saved to: %s", CSV_FILENAME)
end

-- ==============================================================================
-- MODE: SEND (Run on Army)
-- ==============================================================================
local function sendData(targetDriver)
    if not targetDriver then
        printf("\ar[GearLog]\ax No target driver specified to send data to.")
        return
    end

    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    printf("\ay[GearLog]\ax Sending gear data to %s...", targetDriver)
    
    for i = 0, INVENTORY_SLOTS do
        local item = mq.TLO.Me.Inventory(i)
        if item() ~= nil then
            local slotName = string.format("%d-%s", i, mq.TLO.InvSlot(i).Name())
            local itemName = item.Name() or ""
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
            
            local svm = item.SVMagic() or 0
            local svf = item.SVFire() or 0
            local svc = item.SVCold() or 0
            local svd = item.SVDisease() or 0
            local svp = item.SVPoison() or 0
            
            local hpregen = item.HPRegen() or 0
            local manaregen = item.ManaRegen() or 0
            
            local focus = item.Focus() or ""
            
            -- Format: Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus
            -- Note: ItemName and Focus are wrapped in quotes to prevent commas from shifting CSV columns
            local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\"",
                me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focus)
            
            -- Send the line via DanNet
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(10) -- Tiny delay to avoid network flooding
            
            -- Process Augs (Sockets 1 through 6)
            for b = 1, 6 do
                local aug = item.AugSlot(b)
                if aug() ~= nil and aug.Item() ~= nil then
                    local aName = aug.Item.Name() or ""
                    local aAc = aug.Item.AC() or 0
                    local aHp = aug.Item.HP() or 0
                    local aMana = aug.Item.Mana() or 0
                    
                    local aStr = aug.Item.STR() or 0
                    local aSta = aug.Item.STA() or 0
                    local aInt = aug.Item.INT() or 0
                    local aWis = aug.Item.WIS() or 0
                    local aAgi = aug.Item.AGI() or 0
                    local aDex = aug.Item.DEX() or 0
                    local aCha = aug.Item.CHA() or 0
                    
                    local aSvm = aug.Item.SVMagic() or 0
                    local aSvf = aug.Item.SVFire() or 0
                    local aSvc = aug.Item.SVCold() or 0
                    local aSvd = aug.Item.SVDisease() or 0
                    local aSvp = aug.Item.SVPoison() or 0
                    
                    local aHpregen = aug.Item.HPRegen() or 0
                    local aManaregen = aug.Item.ManaRegen() or 0
                    
                    local aFocus = aug.Item.Focus() or ""
                    
                    local aDataLine = string.format("%s,%s,Aug,%s,%d,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\"",
                        me, myClass, slotName, b, aName, aAc, aHp, aMana, aStr, aSta, aInt, aWis, aAgi, aDex, aCha, aSvm, aSvf, aSvc, aSvd, aSvp, aHpregen, aManaregen, aFocus)
                    
                    mq.cmdf("/dex %s /gearlog_add %s", targetDriver, aDataLine)
                    mq.delay(10)
                end
            end
        end
    end
end

-- ==============================================================================
-- MAIN LOGIC
-- ==============================================================================
if mode == "collect" then
    startCollecting()
elseif mode == "send" then
    local target = args[2] or DRIVER_NAME
    sendData(target)
else
    printf("\ag[GearLog]\ax Usage:")
    printf("  \ay/lua run gearlog collect\ax : Run on driver to collect data from army.")
    printf("  \ay/lua run gearlog send\ax    : Run manually to send data to driver (Army does this automatically).")
end