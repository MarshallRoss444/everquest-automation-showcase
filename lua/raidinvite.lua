-- ============================================================================
-- raidinvite.lua
-- Description: Forms all 9 groups with bards as group leaders, then creates
--              a raid with ExampleTank as raid leader.
--
--              Execution order:
--                1. Disband all existing groups (clean slate)
--                2. All bards send /invite Name to their 5 members
--                3. Wait for MQ2AutoAccept to process invites
--                4. ExampleBard invites bard leaders 2-9 to raid
--                5. ExampleBard promotes ExampleTank to raid leader
--
-- NOTE: Must be run FROM ExampleBard. Raid invite commands run locally.
--       MQ2AutoGroup.ini is aligned with these groups.
--
-- HOW TO RUN (on ExampleBard):
--   /lua run raidinvite
-- ============================================================================

local mq = require('mq')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Groups: leader (bard) is first entry, members follow.
-- Order matches CLAUDE.md. Bards are group leaders; ExampleTank is raid leader.
local GROUPS = {
    { leader = 'ExampleBard', members = { 'ExampleTank',   'ExampleChar27', 'ExampleKnight',    'ExampleWarrior',   'ExampleChar12'   } },
    { leader = 'ExampleChar48',   members = { 'ExampleChar15',   'ExampleChar08','ExampleChar18',  'ExampleChar39', 'ExampleChar43'   } },
    { leader = 'ExampleChar17',    members = { 'ExampleChar49',  'ExampleChar53',  'ExampleChar30', 'ExampleChar35', 'ExampleChar38'   } },
    { leader = 'ExampleChar14',  members = { 'ExampleChar26',   'ExampleChar28',   'ExampleChar33',   'ExampleChar46','ExampleChar51'    } },
    { leader = 'ExampleChar22',    members = { 'ExampleChar13','ExampleChar29','ExampleChar02', 'ExampleChar52',   'ExampleChar45'   } },
    { leader = 'ExampleChar41',    members = { 'ExampleChar23',    'ExampleChar16',  'ExampleChar07','ExampleChar36', 'ExampleChar05'  } },
    { leader = 'ExampleChar34',   members = { 'ExampleChar06',    'ExampleChar03', 'ExampleChar04',  'ExampleChar24', 'ExampleChar10'  } },
    { leader = 'ExampleChar11',    members = { 'ExampleChar01','ExampleChar32', 'ExampleChar31',  'ExampleChar21',  'ExampleChar44' } },
    { leader = 'ExampleChar54',  members = { 'ExampleChar25',     'ExampleChar37',   'ExampleChar09',    'ExampleChar40',   'ExampleChar20'   } },
}

local RAID_LEADER    = 'ExampleTank'   -- Becomes raid leader (Group 1 member)
local RAID_INVITER   = 'ExampleBard' -- Must be raid leader to send /raidinvite

-- ============================================================================
-- HELPERS
-- ============================================================================

local function printf(fmt, ...)
    mq.cmd('/echo \ay[RaidInvite]\ax ' .. string.format(fmt, ...))
end

-- Execute a command on a remote character via DanNet
local function dex(charName, cmd)
    mq.cmdf('/dex %s %s', charName, cmd)
end

-- ============================================================================
-- PHASE 1A: DISBAND ALL GROUPS (CLEAN SLATE)
-- ============================================================================

local function disbandAllGroups()
    printf('Disbanding all existing groups and raids...')
    for _, grp in ipairs(GROUPS) do
        dex(grp.leader, '/raiddisband')
        dex(grp.leader, '/disband')
        for _, member in ipairs(grp.members) do
            dex(member, '/raiddisband')
            dex(member, '/disband')
        end
    end
    mq.delay(1000)
    printf('Disbands complete.')
end

-- ============================================================================
-- PHASE 1B: BARDS INVITE THEIR GROUP MEMBERS
-- ============================================================================

local function inviteAllGroups()
    printf('Sending all group invites...')
    for i, grp in ipairs(GROUPS) do
        printf('  Group %d: %s inviting...', i, grp.leader)
        for _, member in ipairs(grp.members) do
            dex(grp.leader, '/invite ' .. member)
            mq.delay(100)
        end
    end
    printf('All invites sent.')
end

-- ============================================================================
-- PHASE 2: FORM THE RAID
-- ============================================================================

local function formRaid()
    printf('--- Raid Formation Phase ---')

    -- ExampleBard sends all /raidinvite calls
    for i = 2, #GROUPS do
        local bard = GROUPS[i].leader
        printf('  Inviting %s', bard)
        dex(RAID_INVITER, '/raidinvite ' .. bard)
        mq.delay(500)
    end

    mq.delay(1000)

    -- Promote ExampleTank to raid leader
    dex(RAID_INVITER, '/makeraidleader ' .. RAID_LEADER)
    mq.delay(2000)

    printf('\agRaid formed. %s is now Raid Leader.\ax', RAID_LEADER)
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    printf('========================================')
    printf('  RAIDINVITE  -  Starting')
    printf('  Groups : %d   Raid Leader : %s', #GROUPS, RAID_LEADER)
    printf('  Run from: %s', mq.TLO.Me.Name())
    printf('  MQ2AutoGroup.ini is aligned -- working together')
    printf('========================================')

    -- -----------------------------------------------------------------------
    -- PHASE 1: Disband existing groups, then invite all members
    -- -----------------------------------------------------------------------
    disbandAllGroups()
    inviteAllGroups()

    -- -----------------------------------------------------------------------
    -- PHASE 2: Form raid, promote ExampleTank as raid leader
    -- -----------------------------------------------------------------------
    formRaid()

    mq.delay(2000)

    printf('========================================')
    printf('  SETUP COMPLETE!')
    printf('  Raid Leader : %s', RAID_LEADER)
    printf('  9 groups in raid, bards leading each.')
    printf('========================================')
end

main()
