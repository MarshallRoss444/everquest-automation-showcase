local mq = require('mq')

print('\ar[StripBuffs]\ax Starting simple buff strip...')

local attempts = 0
local maxAttempts = 200   -- safety (~20 seconds max)

while attempts < maxAttempts do
    attempts = attempts + 1
    local removedThisLoop = false

    for i = 1, 30 do
        local buff = mq.TLO.Me.Buff(i)
        
        if buff() and buff.ID() then
            local name = buff.Name()
            if name then
                mq.cmdf('/removebuff "%s"', name)
                removedThisLoop = true
                -- print(string.format('Removed: %s', name))  -- uncomment if you want to see what gets removed
            end
        end
    end

    if not removedThisLoop then
        break
    end

    mq.delay(100)   -- 100ms loop
end

print('\ag[StripBuffs]\ax Done! All buffs removed.')