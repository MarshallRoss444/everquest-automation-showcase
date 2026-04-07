-- ============================================================================
-- splitraid.lua
-- Description: Splits the 54-man army into two independent raids.
--
--   RAID 1 (24 players, 4 groups) -- Raid Leader: ExampleTank
--     Group 1: ExampleBard  (ExampleTank, ExampleChar27, ExampleChar12,
--                                ExampleChar44, ExampleChar21)
--     Group 3: ExampleChar17     (ExampleChar49, ExampleChar53, ExampleChar30,
--                                ExampleChar35, ExampleChar38)
--     Group 4: ExampleChar14   (ExampleChar26, ExampleChar28, ExampleChar33,
--                                ExampleChar46, ExampleChar51)
--     Group 9: ExampleChar54   (ExampleChar25, ExampleChar37, ExampleChar09,
--                                ExampleChar40, ExampleChar20)
--
--   RAID 2 (30 players, 5 groups) -- Raid Leader: ExampleWarrior
--     Group 2: ExampleChar48    (ExampleChar15, ExampleChar08, ExampleChar18,
--                                ExampleChar39, ExampleChar43)
--     Group 5: ExampleChar22     (ExampleChar13, ExampleChar29, ExampleChar02,
--                                ExampleChar52, ExampleChar45)
--     Group 6: ExampleChar41     (ExampleChar23, ExampleChar16, ExampleChar07,
--                                ExampleChar36, ExampleChar10)
--     Group 7: ExampleChar34    (ExampleChar06, ExampleChar03, ExampleChar04,
--                                ExampleChar24, ExampleChar05)
--     Group 8: ExampleChar11     (ExampleChar01, ExampleChar32, ExampleChar31,
--                                ExampleWarrior, ExampleKnight)
--
--   NOTE: ExampleChar44 and ExampleChar21 move from ExampleChar11 -> Raid 1 Group 1.
--         ExampleWarrior and ExampleKnight move from Group 1 -> Raid 2 ExampleChar11 group.
--
--   Execution order:
--     1. All characters /raidleave and /disband (clean slate)
--     2. All 9 bards invite their 5 group members
--     3. Wait for MQ2AutoAccept to process
--     4. ExampleBard forms Raid 1, promotes ExampleTank as raid leader
--     5. ExampleChar48 forms Raid 2, promotes ExampleWarrior as raid leader
--
-- HOW TO RUN (on ExampleTank):
--   /lua run splitraid
-- ============================================================================

local mq = require('mq')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Raid 1: 4 groups, 24 players
local RAID1_GROUPS = {
    { leader = 'ExampleBard', members = { 'ExampleTank',    'ExampleChar27',  'ExampleChar12',   'ExampleChar44', 'ExampleChar21'   } },
    { leader = 'ExampleChar17',    members = { 'ExampleChar49',   'ExampleChar53',   'ExampleChar30',  'ExampleChar35',  'ExampleChar38'   } },
    { leader = 'ExampleChar14',  members = { 'ExampleChar26',    'ExampleChar28',    'ExampleChar33',    'ExampleChar46', 'ExampleChar51'    } },
    { leader = 'ExampleChar54',  members = { 'ExampleChar25',      'ExampleChar37',    'ExampleChar09',     'ExampleChar40',    'ExampleChar20'   } },
}

-- Raid 2: 5 groups, 30 players
local RAID2_GROUPS = {
    { leader = 'ExampleChar48',   members = { 'ExampleChar15',    'ExampleChar08', 'ExampleChar18',   'ExampleChar39',  'ExampleChar43'   } },
    { leader = 'ExampleChar22',    members = { 'ExampleChar13', 'ExampleChar29', 'ExampleChar02',  'ExampleChar52',    'ExampleChar45'   } },
    { leader = 'ExampleChar41',    members = { 'ExampleChar23',     'ExampleChar16',   'ExampleChar07','ExampleChar36',   'ExampleChar10'  } },
    { leader = 'ExampleChar34',   members = { 'ExampleChar06',     'ExampleChar03',  'ExampleChar04',   'ExampleChar24',  'ExampleChar05'  } },
    { leader = 'ExampleChar11',    members = { 'ExampleChar01', 'ExampleChar32',  'ExampleChar31',   'ExampleWarrior',    'ExampleKnight'     } },
}

local RAID1_LEADER   = 'ExampleTank'    -- Raid 1 raid leader
local RAID1_INVITER  = 'ExampleBard' -- First bard in Raid 1; sends /raidinvite to others

local RAID2_LEADER   = 'ExampleWarrior'     -- Raid 2 raid leader
local RAID2_INVITER  = 'ExampleChar48'   -- First bard in Raid 2; sends /raidinvite to others

-- ============================================================================
-- HELPERS
-- ============================================================================

local function printf(fmt, ...)
    mq.cmd('/echo \ay[SplitRaid]\ax ' .. string.format(fmt, ...))
end

-- Execute a command on a remote character via DanNet
local function dex(charName, cmd)
    mq.cmdf('/dex %s %s', charName, cmd)
end

local function allGroups()
    local all = {}
    for _, g in ipairs(RAID1_GROUPS) do table.insert(all, g) end
    for _, g in ipairs(RAID2_GROUPS) do table.insert(all, g) end
    return all
end

-- ============================================================================
-- PHASE 0: CLEAN SLATE -- raidleave + disband for all 54 characters
-- ============================================================================

local function cleanSlate()
    printf('Phase 0: Raiddisband + Raidleave + Disband all characters...')
    for _, grp in ipairs(allGroups()) do
        dex(grp.leader, '/raiddisband')
        dex(grp.leader, '/raidleave')
        dex(grp.leader, '/disband')
        for _, member in ipairs(grp.members) do
            dex(member, '/raiddisband')
            dex(member, '/raidleave')
            dex(member, '/disband')
        end
    end
    mq.delay(2000)
    printf('Clean slate complete.')
end

-- ============================================================================
-- PHASE 1: BARDS INVITE THEIR GROUP MEMBERS
-- ============================================================================

local function inviteAllGroups()
    printf('Phase 1: Sending all group invites...')
    for _, grpList in ipairs({ RAID1_GROUPS, RAID2_GROUPS }) do
        for i, grp in ipairs(grpList) do
            printf('  %s inviting group members...', grp.leader)
            for _, member in ipairs(grp.members) do
                dex(grp.leader, '/invite ' .. member)
                mq.delay(100)
            end
        end
    end
    printf('All group invites sent. Waiting for AutoAccept...')
    mq.delay(3000)
end

-- ============================================================================
-- PHASE 2A: FORM RAID 1
-- ============================================================================

local function formRaid1()
    printf('Phase 2A: Forming Raid 1 (%d groups)...', #RAID1_GROUPS)

    -- ExampleBard invites bards 2-4 of Raid 1
    for i = 2, #RAID1_GROUPS do
        local bard = RAID1_GROUPS[i].leader
        printf('  Raid 1: %s inviting %s', RAID1_INVITER, bard)
        dex(RAID1_INVITER, '/raidinvite ' .. bard)
        mq.delay(500)
    end

    mq.delay(1000)

    -- Promote ExampleTank as Raid 1 leader
    dex(RAID1_INVITER, '/makeraidleader ' .. RAID1_LEADER)
    mq.delay(1500)

    printf('\agRaid 1 formed. %s is Raid 1 Leader.\ax', RAID1_LEADER)
end

-- ============================================================================
-- PHASE 2B: FORM RAID 2
-- ============================================================================

local function formRaid2()
    printf('Phase 2B: Forming Raid 2 (%d groups)...', #RAID2_GROUPS)

    -- ExampleChar48 invites bards 2-5 of Raid 2
    for i = 2, #RAID2_GROUPS do
        local bard = RAID2_GROUPS[i].leader
        printf('  Raid 2: %s inviting %s', RAID2_INVITER, bard)
        dex(RAID2_INVITER, '/raidinvite ' .. bard)
        mq.delay(500)
    end

    mq.delay(1000)

    -- Promote ExampleWarrior as Raid 2 leader
    -- ExampleWarrior is in ExampleChar11's group which is already in the raid
    dex(RAID2_INVITER, '/makeraidleader ' .. RAID2_LEADER)
    mq.delay(1500)

    printf('\agRaid 2 formed. %s is Raid 2 Leader.\ax', RAID2_LEADER)
end

-- ============================================================================
-- MAIN
-- ============================================================================

local function main()
    printf('========================================')
    printf('  SPLITRAID  -  Starting')
    printf('  Raid 1: %d groups  |  Leader: %s', #RAID1_GROUPS, RAID1_LEADER)
    printf('  Raid 2: %d groups  |  Leader: %s', #RAID2_GROUPS, RAID2_LEADER)
    printf('  Run from: %s', mq.TLO.Me.Name())
    printf('========================================')

    cleanSlate()
    inviteAllGroups()
    formRaid1()
    formRaid2()

    mq.delay(2000)

    printf('========================================')
    printf('  SETUP COMPLETE!')
    printf('  Raid 1 Leader : %s  (%d groups, 24 players)', RAID1_LEADER, #RAID1_GROUPS)
    printf('  Raid 2 Leader : %s  (%d groups, 30 players)', RAID2_LEADER, #RAID2_GROUPS)
    printf('========================================')
end

main()
