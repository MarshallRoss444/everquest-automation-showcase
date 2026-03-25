-- lua/empadd.lua
-- Emperor Ssraeshza add-tank script
-- Self-differentiates by character name at runtime
--
-- State machine per add:
--   SEARCH  -> add not in zone yet
--   PULL    -> add spawned OR aggro lost : go to add, stick close, spam threat
--   DRAG    -> aggro secured (mob targets us) : nav to fight spot, mob follows,
--              periodic re-taunt during the walk to keep aggro above loss threshold
--   FIGHT   -> tank at fight spot : face mob, rotate threat between adds
--
-- Priority: PULL > DRAG > FIGHT
-- Aggro break at any state immediately forces PULL
--
-- Usage:
--   /lua run empadd     (on ExampleWarrior or ExampleKnight client)
--   /lua stop empadd

local mq = require('mq')

------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------

local ASSIGNMENTS = {
    ExampleWarrior = { 'Slakiz the Malignant', 'Nilasz the Devourer' },
    ExampleKnight  = { 'Heriz the Malignant',  'Yasiz the Devourer'  },
}

local THREAT_ABILITY = {
    ExampleWarrior = '/bash',
    ExampleKnight  = '/kick',
}

-- Designated fight location (EQ Y X Z)
local SPOT_Y, SPOT_X, SPOT_Z = -223, 905, 400
local SPOT_RADIUS   = 15    -- units: considered "at fight spot"
local ROTATE_MS     = 3000  -- ms between rotation cycles in FIGHT state
local DRAG_TAUNT_MS = 2500  -- ms between threat pulses while dragging to spot

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------

local myName    = mq.TLO.Me.Name()
local myAdds    = ASSIGNMENTS[myName]
local threatCmd = THREAT_ABILITY[myName]

if not myAdds then
    print(('\ar[EmpAdd] Unknown character "%s". Valid: ExampleWarrior, ExampleKnight'):format(myName))
    return
end

local STATE = { SEARCH = 'SEARCH', PULL = 'PULL', DRAG = 'DRAG', FIGHT = 'FIGHT' }

-- Per-add tracking
local adds = {}
for _, name in ipairs(myAdds) do
    adds[name] = { name = name, state = STATE.SEARCH, id = nil }
end

local lastRotate    = mq.gettime()
local lastDragTaunt = mq.gettime()
local rotIndex      = 0

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function distToSpot()
    local dx = mq.TLO.Me.X() - SPOT_X
    local dy = mq.TLO.Me.Y() - SPOT_Y
    local dz = mq.TLO.Me.Z() - SPOT_Z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function getAlive(name)
    local s = mq.TLO.Spawn('npc ' .. name)
    if s() and s.ID() > 0 and not s.Dead() then return s end
    return nil
end

local function getAliveByID(id)
    local s = mq.TLO.Spawn('id ' .. id)
    if s() and s.ID() > 0 and not s.Dead() then return s end
    return nil
end

-- True if spawn is currently targeting the tank
local function hasAggro(spawn)
    local t = spawn.Target
    return t() ~= nil and t.Name() == myName
end

-- Target mob by ID; returns true on success
local function doTarget(id)
    mq.cmd('/target id ' .. id)
    mq.delay(250, function() return mq.TLO.Target.ID() == id end)
    return mq.TLO.Target.ID() == id
end

-- Full threat burst: target -> attack -> taunt -> bash/kick -> face
-- Used in PULL and FIGHT. Facing ensures mob stays in front of tank.
local function threatBurst(id)
    if not doTarget(id) then
        print(('\ay[EmpAdd] Target failed for ID %d, will retry'):format(id))
        return
    end
    mq.cmd('/attack on')
    mq.cmd('/taunt')
    mq.delay(50)
    mq.cmd(threatCmd)
    mq.delay(50)
    mq.cmd('/face id ' .. id)
end

-- Lightweight taunt used during drag.
-- No /face here — tank faces direction of travel (toward spot), not back at mob.
local function dragTaunt(id)
    if not doTarget(id) then return end
    mq.cmd('/taunt')
    mq.delay(50)
    mq.cmd(threatCmd)
    mq.delay(50)
end

local function navToSpot()
    mq.cmd(('/nav loc %.1f %.1f %.1f'):format(SPOT_Y, SPOT_X, SPOT_Z))
end

------------------------------------------------------------------------
-- Main loop
------------------------------------------------------------------------

print(('\ag[EmpAdd] Running on %s'):format(myName))
print(('\ag[EmpAdd] Watching: %s'):format(table.concat(myAdds, ', ')))
print(('\ag[EmpAdd] Fight spot: Y=%.0f X=%.0f Z=%.0f  radius=%d units'):format(SPOT_Y, SPOT_X, SPOT_Z, SPOT_RADIUS))
print('\ao[EmpAdd] Stop with: /lua stop empadd')

while true do

    ------------------------------------------------------------
    -- STEP 1: State transitions for each add
    ------------------------------------------------------------
    for _, addName in ipairs(myAdds) do
        local info  = adds[addName]
        local spawn = (info.id and getAliveByID(info.id)) or getAlive(addName)

        if not spawn then
            -- Add is gone or not yet spawned
            if info.state ~= STATE.SEARCH then
                print(('\ao[EmpAdd] %s gone/dead -> SEARCH'):format(addName))
                mq.cmd('/stick off')
                mq.cmd('/nav stop')
            end
            info.state = STATE.SEARCH
            info.id    = nil
        else
            info.id      = spawn.ID()
            local got    = hasAggro(spawn)
            local atSpot = distToSpot() <= SPOT_RADIUS

            if info.state == STATE.SEARCH then
                -- Add just appeared in zone
                print(('\ag[EmpAdd] %s spawned -> PULL'):format(addName))
                info.state = STATE.PULL

            elseif info.state == STATE.PULL then
                -- Transition to DRAG once the mob is targeting us
                if got then
                    print(('\ag[EmpAdd] %s aggro confirmed -> DRAG'):format(addName))
                    mq.cmd('/stick off')
                    info.state = STATE.DRAG
                end

            elseif info.state == STATE.DRAG then
                if not got then
                    -- Lost aggro mid-drag — go back and re-establish
                    print(('\ar[EmpAdd] %s aggro lost mid-drag -> PULL'):format(addName))
                    mq.cmd('/nav stop')
                    info.state = STATE.PULL
                elseif atSpot then
                    -- Arrived at fight spot
                    print(('\ag[EmpAdd] %s at fight spot -> FIGHT'):format(addName))
                    mq.cmd('/nav stop')
                    info.state = STATE.FIGHT
                end

            elseif info.state == STATE.FIGHT then
                if not got then
                    -- Aggro broken at spot — immediately go re-pull
                    print(('\ar[EmpAdd] %s aggro lost at spot -> PULL'):format(addName))
                    mq.cmd('/stick off')
                    info.state = STATE.PULL
                end
            end
        end
    end

    ------------------------------------------------------------
    -- STEP 2: Bucket adds by current state
    ------------------------------------------------------------
    local pullList  = {}
    local dragList  = {}
    local fightList = {}

    for _, addName in ipairs(myAdds) do
        local info = adds[addName]
        if info.id then
            if     info.state == STATE.PULL  then table.insert(pullList,  info)
            elseif info.state == STATE.DRAG  then table.insert(dragList,  info)
            elseif info.state == STATE.FIGHT then table.insert(fightList, info)
            end
        end
    end

    ------------------------------------------------------------
    -- STEP 3: Act on highest-priority bucket
    -- Note: if both adds spawn simultaneously both enter PULL.
    -- Script handles them one at a time (first listed takes priority).
    -- Second add will be picked up once the first reaches DRAG.
    ------------------------------------------------------------

    if #pullList > 0 then
        -- PULL: Close distance and blast threat until mob targets us.
        -- /stick 10 MOVEBACK keeps tank at melee range without walking through mob.
        local t = pullList[1]
        mq.cmd('/nav stop')
        if doTarget(t.id) then
            mq.cmd('/stick 10 MOVEBACK')
            mq.cmd('/attack on')
            mq.cmd('/taunt')
            mq.delay(50)
            mq.cmd(threatCmd)
            mq.delay(50)
            mq.cmd('/face id ' .. t.id)
        end

    elseif #dragList > 0 then
        -- DRAG: Navigate to fight spot. Mob(s) follow because they have aggro on us.
        -- /face is intentionally NOT used here so tank faces direction of travel.
        -- Periodic dragTaunt fires on all dragging adds to maintain lead during walk.
        local now = mq.gettime()
        if not mq.TLO.Navigation.Active() then
            navToSpot()
        end
        if (now - lastDragTaunt) >= DRAG_TAUNT_MS then
            for _, t in ipairs(dragList) do
                dragTaunt(t.id)
            end
            -- Re-issue nav in case targeting briefly interrupted movement
            navToSpot()
            lastDragTaunt = now
        end

    elseif #fightList > 0 then
        -- FIGHT: Rotate threat between adds. /face keeps mob in front of tank.
        local now = mq.gettime()
        if (now - lastRotate) >= ROTATE_MS then
            rotIndex = (rotIndex % #fightList) + 1
            local t  = fightList[rotIndex]
            print(('\ag[EmpAdd] Rotating to: %s'):format(t.name))
            threatBurst(t.id)
            lastRotate = now
        end
    end

    mq.delay(250)
end
