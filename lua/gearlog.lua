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
    
    -- Keep the script alive for 45 seconds to catch all the DanNet messages
    -- A 54-man army sending ~50 items each takes longer than 15 seconds to fully process over the network
    local endTime = os.time() + 45
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
            
            local focus = item.Focus() or ""
            
            -- Format: Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus
            -- Note: ItemName and Focus are wrapped in quotes to prevent commas from shifting CSV columns
            local dataLine = string.format("%s,%s,Item,%s,,\"%s\",%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\"",
                me, myClass, slotName, itemName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focus)
            
            -- Send the line via DanNet
            mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
            mq.delay(10) -- Tiny delay to avoid network flooding
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