-- =================================================================================================
-- Lua Script: PotionDistribute.lua
-- Description: Tops off "Distillate of Divine Healing IX" for all DanNet peers in range.
--              Queries each character's current count, calculates the delta to 100 (max stack),
--              and trades only the needed quantity. Characters already at 100 are skipped.
--
-- HOW TO RUN (from ExampleChar38):
--   /lua run PotionDistribute
--
-- REQUIREMENTS:
--   - Run from ExampleChar38 (or any character holding the potion stacks)
--   - Potion stacks must be in MAIN inventory slots (not inside bags)
--   - All target characters must have MQ2AutoAccept active
--   - All targets must be within 200 units
-- =================================================================================================

local mq = require('mq')

local ITEM_NAME  = "Distillate of Divine Healing IX"
local MAX_COUNT  = 100
local RANGE      = 200

-- =========================================================================
-- Parse character name from DanNet peer string (e.g. "server_charname")
-- =========================================================================
local function getCharNameFromPeerString(peer_string)
    local parts = {}
    for part in string.gmatch(peer_string, "[^_]+") do
        table.insert(parts, part)
    end
    return parts[#parts]
end

-- =========================================================================
-- Find item in main inventory slots (23-32) or inside bags
-- Returns: { packnum=N, bagslot=N } for bag items
--          { packnum=N, bagslot=nil } for main inventory items
-- packnum is 1-10 (slot 23 = pack1)
-- =========================================================================
local function findItem(itemName)
    local lower = string.lower(itemName)
    for i = 23, 32 do
        local slot = mq.TLO.Me.Inventory(i)
        local slotName = slot.Name()
        -- Check main slot directly
        if slotName and string.lower(slotName) == lower then
            return { packnum = i - 22, bagslot = nil }
        end
        -- Check inside containers
        local containerSize = slot.Container()
        if containerSize and containerSize > 0 then
            for b = 1, containerSize do
                local bagItem = slot.Item(b)
                local bagName = bagItem and bagItem.Name()
                if bagName and string.lower(bagName) == lower then
                    return { packnum = i - 22, bagslot = b }
                end
            end
        end
    end
    return nil
end

-- =========================================================================
-- MAIN SCRIPT LOGIC
-- =========================================================================

local MainChar = string.lower(mq.TLO.Me.Name())
local peerlist = {}

mq.cmdf('/dgt \\ay--- Initiating "%s" Top-Off (max %d per character) ---', ITEM_NAME, MAX_COUNT)

-- Discover peers in range
local peerstr = mq.TLO.DanNet.Peers()
for peer_name_raw in string.gmatch(peerstr, "([^|]+)") do
    local name = getCharNameFromPeerString(peer_name_raw)
    if name and string.lower(name) ~= MainChar then
        local botspawn = mq.TLO.Spawn(name)
        if botspawn.ID() and botspawn.Distance() and botspawn.Distance() < RANGE then
            table.insert(peerlist, name)
            mq.cmdf('/dgt Adding %s to list.', name)
        end
    end
end

if #peerlist == 0 then
    mq.cmdf('/dgt \\arERROR:\\ax No eligible peers found within %d units. Aborting.', RANGE)
    return
end

-- Open inventory once at the start
mq.cmdf('/if (!${Window[InventoryWindow].Open}) /keypress i')
mq.delay(500, function() return mq.TLO.Window("InventoryWindow").Open() end)

-- =========================================================================
-- DISTRIBUTION LOOP
-- =========================================================================

for _, bot_name in ipairs(peerlist) do

    -- Query how many potions this character currently has (FindItemCount is a global TLO, not Me.)
    local queryKey = string.format('FindItemCount[%s]', ITEM_NAME)
    mq.cmdf('/dquery %s -q "%s"', bot_name, queryKey)
    mq.delay(500)
    local current = tonumber(mq.TLO.DanNet(bot_name).Q(queryKey)()) or 0
    local needed  = MAX_COUNT - current

    if needed <= 0 then
        mq.cmdf('/dgt \\ag%s already has %d/%d. Skipping.', bot_name, current, MAX_COUNT)
    else
        mq.cmdf('/dgt \\ay%s has %d/%d. Trading %d potions...', bot_name, current, MAX_COUNT, needed)

        -- Find a stack in inventory (main slots or inside bags)
        local loc = findItem(ITEM_NAME)
        if not loc then
            mq.cmdf('/dgt \\arERROR:\\ax "%s" not found anywhere in inventory. Aborting.', ITEM_NAME)
            return
        end

        -- Pick up the needed quantity via QuantityWnd
        if loc.bagslot then
            mq.cmdf('/itemnotify in pack%d %d leftmouseup', loc.packnum, loc.bagslot)
        else
            mq.cmdf('/itemnotify pack%d leftmouseup', loc.packnum)
        end
        mq.delay(2500, function() return mq.TLO.Window("QuantityWnd").Open() end)

        local qty_ok = false
        if mq.TLO.Window("QuantityWnd").Open() then
            mq.cmdf("/notify QuantityWnd QTYW_Slider newvalue %d", needed)
            mq.delay(200)
            mq.cmdf("/notify QuantityWnd QTYW_Accept_Button leftmouseup")
            mq.delay(1000, function() return mq.TLO.Cursor.ID() end)
            qty_ok = true
        else
            mq.cmdf('/dgt \\arERROR:\\ax QuantityWnd did not open for %s. Skipping.', bot_name)
        end

        if qty_ok and mq.TLO.Cursor.ID() then
            -- Target and open trade window
            mq.cmdf('/target "%s"', bot_name)
            mq.delay(500, function() return mq.TLO.Target.Name() and string.lower(mq.TLO.Target.Name()) == string.lower(bot_name) end)
            mq.cmdf('/click left target')
            mq.delay(2000, function() return mq.TLO.Window("TradeWnd").Open() end)

            if mq.TLO.Window("TradeWnd").Open() then
                mq.cmdf('/dgt Trade window open. Finalizing with %s.', bot_name)
                mq.cmdf('/notify TradeWnd TRDW_Trade_Button leftmouseup')
                mq.delay(300)
                mq.cmdf('/dex %s /notify TradeWnd TRDW_Trade_Button leftmouseup', bot_name)
                mq.delay(2000, function() return not mq.TLO.Window("TradeWnd").Open() end)
                mq.cmdf('/dgt \\agTrade with %s complete. (+%d potions)', bot_name, needed)
            else
                mq.cmdf('/dgt \\arERROR:\\ax Trade window failed for %s. Returning item to inventory.', bot_name)
                mq.cmdf('/autoinventory')
            end
        elseif qty_ok then
            mq.cmdf('/dgt \\arERROR:\\ax Failed to pick up item for %s. Skipping.', bot_name)
        end
    end

    mq.delay(1000)
end

mq.cmdf('/dgt \\ay--- "%s" distribution finished. ---', ITEM_NAME)
