-- =================================================================================================
-- Lua Script: FoodDistribute.lua
-- Description: This script distributes a specified quantity of "Misty Thicket Picnic" from the
--              person running the script to all connected bots in range.
--
-- HOW TO RUN:
--   1. Place your "Misty Thicket Picnic" stack in a main inventory slot (not in a bag).
--   2. /lua run FoodDistribute <quantity>
--   Example: /lua run FoodDistribute 20
-- =================================================================================================

local mq = require('mq')

-- This function is from your working plattrade.lua to ensure compatibility
local function getCharNameFromPeerString(peer_string)
    local parts = {}
    for part in string.gmatch(peer_string, "[^_]+") do
        table.insert(parts, part)
    end
    -- The character's name should be the last part of the string.
    local char_name = parts[#parts]
    return char_name
end

-- =========================================================================
-- Simplified function to find an item ONLY in main inventory
-- =========================================================================
local function findItemLocation(itemName)
    local lowerItemName = string.lower(itemName)

    -- Only check the 10 main inventory slots (23-32)
    for i = 23, 32 do
        local currentItemName = mq.TLO.Me.Inventory(i).Name()
        if currentItemName and string.lower(currentItemName) == lowerItemName then
            return i -- Return the main inventory slot number
        end
    end

    return nil -- Return nil if not found
end


-- =========================================================================
-- MAIN SCRIPT LOGIC
-- =========================================================================

local args = { ... }
local tradeQuantity = tonumber(args[1])
if not tradeQuantity or tradeQuantity < 1 then
    mq.cmdf('/dgt \\arERROR:\\ax Please specify a quantity to trade. Example: /lua run FoodDistribute 20')
    return
end

local itemName = "Misty Thicket Picnic"
local MainChar = string.lower(mq.TLO.Me.Name())
local peerlist = {}

mq.cmdf('/dgt \\ay--- Initiating "%s" Distribution (x%d) ---', itemName, tradeQuantity)

-- Bot discovery loop from your working script
mq.cmdf('/dgt Finding bots...')
local peerstr = mq.TLO.DanNet.Peers()
for peer_name_raw in string.gmatch(peerstr, "([^|]+)") do
    local name = getCharNameFromPeerString(peer_name_raw)

    if name and string.lower(name) ~= MainChar then
        local botspawn = mq.TLO.Spawn(name)
        if botspawn.ID() and botspawn.Distance() and botspawn.Distance() < 25 then
            table.insert(peerlist, name)
            mq.cmdf('/dgt Adding %s to trade list.', name)
        end
    end
end

if #peerlist == 0 then
    mq.cmdf('/dgt \\arERROR:\\ax No eligible bots found in range. Aborting.')
    return
end

-- Open inventory once at the start
mq.cmdf('/if (!${Window[InventoryWindow].Open}) /keypress i')
mq.delay(500, function() return mq.TLO.Window("InventoryWindow").Open() end)

-- =========================================================================
-- DISTRIBUTION LOOP
-- =========================================================================

for _, bot_name in ipairs(peerlist) do
    mq.cmdf('/dgt \\ayPreparing to trade with %s...', bot_name)

    -- Step 1: Find the item and pick up the correct quantity
    local invSlot = findItemLocation(itemName)

    if not invSlot then
        mq.cmdf('/dgt \\arERROR:\\ax Cannot find "%s" in your main inventory slots. Please move the stack and try again.', itemName)
        return
    end

    -- --- CORRECTED: Using a simple click with no modifiers to pick up the stack ---
    mq.cmdf('/itemnotify %d leftmouseup', invSlot)


    -- Increased delay to reliably detect the quantity window
    mq.delay(2500, function() return mq.TLO.Window("QuantityWnd").Open() end)

    if (mq.TLO.Window("QuantityWnd").Open()) then
        mq.cmdf("/notify QuantityWnd QTYW_Slider newvalue %d", tradeQuantity)
        mq.delay(200)
        mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
        mq.delay(1000, function() return mq.TLO.Cursor.ID() end)
    else
        mq.cmdf('/dgt \\arERROR:\\ax Script could not detect QuantityWnd. Skipping trade with %s.', bot_name)
        goto next_bot
    end

    -- Check if item is on cursor before trading
    if not mq.TLO.Cursor.ID() then
        mq.cmdf('/dgt \\arERROR:\\ax Failed to pick up "%s". Skipping trade with %s.', itemName, bot_name)
        goto next_bot
    end

    -- Step 2: Initiate and complete the trade
    mq.cmdf('/dgt Initiating trade with %s.', bot_name)
    mq.cmdf('/target "%s"', bot_name)
    mq.delay(500, function() return mq.TLO.Target.Name() and string.lower(mq.TLO.Target.Name()) == string.lower(bot_name) end)
    mq.cmdf('/click left target')
    mq.delay(2000, function() return mq.TLO.Window("TradeWnd").Open() end)

    if (mq.TLO.Window('TradeWnd').Open()) then
        mq.cmdf('/dgt Trade window open. Finalizing.')
        mq.cmdf('/notify TradeWnd TRDW_Trade_Button leftmouseup')
        mq.delay(300)
        mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', bot_name)
        mq.delay(2000, function() return not mq.TLO.Window("TradeWnd").Open() end)
        mq.cmdf('/dgt \\agTrade with %s complete.', bot_name)
    else
        mq.cmdf('/dgt \\arERROR:\\ax Failed to open trade window with %s. Putting item back.', bot_name)
        mq.cmdf('/autoinventory') -- This will clear the cursor if the trade failed
    end

    ::next_bot::
    mq.delay(1000) -- Pause before trading with the next bot
end

mq.cmdf('/dgt \\ay--- Food distribution script finished. ---')
