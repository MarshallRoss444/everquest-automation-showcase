local mq = require('mq')

-- ============================================================================
-- Lua Script: bindarmy.lua
-- Description: Iterates through all connected DanNet peers and binds them
--              one by one. Requires the executor to have "Bind Affinity" memmed.
--              Assumes bots are already disbanded before starting.
--
-- HOW TO RUN:
--   /lua run bindarmy
-- ============================================================================

local function printf(fmt, ...)
    print('\ay[BindArmy]\ax ' .. string.format(fmt, ...))
end

local function main()
    local peerListRaw = mq.TLO.DanNet.Peers()
    local characters = {}
    local myName = mq.TLO.Me.Name()

    -- 1. Gather all connected characters from DanNet
    for peer in string.gmatch(peerListRaw, "([^_|]+)|") do
        if peer ~= myName then
            table.insert(characters, peer)
        end
    end

    if #characters == 0 then
        printf('\arNo connected bots found on DanNet. Aborting.\ax')
        return
    end

    printf('\agFound %d bots to bind. Starting 1-by-1 process...\ax', #characters)

    -- Pause the current macro so it doesn't interrupt our casting (like p3a.mac)
    local macroWasPaused = false
    if mq.TLO.Macro.Name() ~= nil and not mq.TLO.Macro.Paused() then
        mq.cmd('/squelch /mqpause on')
        macroWasPaused = true
        printf('\ayPaused active macro to prevent cast interruptions.\ax')
    end

    -- Stop moving just in case
    mq.cmd('/keypress back')
    mq.cmd('/squelch /stick off')
    mq.cmd('/squelch /moveto off')
    mq.delay(500)

    -- Ensure we start with a clean slate
    if mq.TLO.Group.Members() and mq.TLO.Group.Members() > 0 then
        mq.cmd('/disband')
        mq.delay(1000)
    end

    -- 2. Process each character
    for i, botName in ipairs(characters) do
        printf('Binding %d/%d: \ap%s\ax', i, #characters, botName)
        
        -- Send the invite
        mq.cmdf('/invite %s', botName)
        
        -- Wait up to 5 seconds for them to join (MQ2AutoAccept should handle this)
        mq.delay(5000, function() return mq.TLO.Group.Members() and mq.TLO.Group.Members() > 0 end)

        if mq.TLO.Group.Members() > 0 then
            -- Target the bot safely
            mq.cmdf('/target pc =%s', botName)
            mq.delay(2000, function() 
                local tName = mq.TLO.Target.CleanName()
                return tName and tName:lower() == botName:lower() 
            end)

            local currentTarget = mq.TLO.Target.CleanName()
            if currentTarget and currentTarget:lower() == botName:lower() then
                -- Wait for Spell Recovery / Global Cooldown to finish
                if not mq.TLO.Me.SpellReady("Bind Affinity")() then
                    printf('\ayWaiting for Bind Affinity to be ready...\ax')
                    mq.delay(5000, function() return mq.TLO.Me.SpellReady("Bind Affinity")() end)
                end

                -- Ensure we are not already casting something else
                if mq.TLO.Me.Casting.ID() ~= nil then
                    mq.cmd('/stopcast')
                    mq.delay(1000, function() return mq.TLO.Me.Casting.ID() == nil end)
                end

                -- Cast Bind Affinity
                mq.cmd('/cast "Bind Affinity"')
                -- Wait for cast to start (or timeout after 2 seconds if something went wrong)
                mq.delay(2000, function() return mq.TLO.Me.Casting.ID() ~= nil end)

                -- Wait for cast to finish
                while mq.TLO.Me.Casting.ID() ~= nil do
                    mq.delay(100)
                end

                -- Small buffer after cast finishes to avoid server desync
                mq.delay(500)
            else
                local wrongTarget = mq.TLO.Target.CleanName() or "None"
                printf('\arFailed to target %s (Currently targeting: %s), skipping cast.\ax', botName, wrongTarget)
            end
        else
            printf('\ar%s did not join the group in time. Skipping.\ax', botName)
        end
        
        -- Disband group to prepare for the next bot
        mq.cmd('/disband')
        -- Wait until we are actually solo again
        mq.delay(2000, function() return mq.TLO.Group.Members() == nil or mq.TLO.Group.Members() == 0 end)
    end
    
    -- Resume the macro if we paused it
    if macroWasPaused then
        mq.cmd('/squelch /mqpause off')
        printf('\ayResumed active macro.\ax')
    end

    printf('\agFinished binding process for all bots! You may want to cast it on yourself now.\ax')
end

main()
