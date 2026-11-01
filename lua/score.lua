local mq = require('mq')
local weights = require('lib.weights')

-- ==============================================================================
-- Score.lua - Version 21.4 (STRICT PASSIVE FILTER)
-- ==============================================================================
-- Strictly excludes FocusType=Spell. Only 'Focus' and 'Worn' count.

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"

local function printf(...)
    print(string.format(...))
end

local function parseCSVLine(line)
    local columns = {}
    for col in (line..","):gmatch("(.-),") do
        table.insert(columns, col)
    end
    return columns
end

local function split(str, pat)
    local t = {}
    for part in str:gmatch("([^" .. pat .. "]+)") do
        table.insert(t, part:match("^%s*(.-)%s*$"))
    end
    return t
end

local function main()
    local f = io.open(CSV_FILENAME, "r")
    if not f then printf("\ar[Score] Error: MyGearLog.csv not found!\ax"); return end
    f:read("*l") 
    
    local characters = {}
    for line in f:lines() do
        local cols = parseCSVLine(line)
        if #cols >= 29 then
            local name, class = cols[1], cols[2]
            if not characters[name] then characters[name] = { class = class, items = {}, focuses = {}, totalMana = 0 } end
            
            local item = {
                Slot = cols[4] or "",
                ItemName = cols[6] or "Empty",
                AC = tonumber(cols[7]) or 0, HP = tonumber(cols[8]) or 0, Mana = tonumber(cols[9]) or 0,
                STR = tonumber(cols[10]) or 0, STA = tonumber(cols[11]) or 0, INT = tonumber(cols[12]) or 0, WIS = tonumber(cols[13]) or 0,
                AGI = tonumber(cols[14]) or 0, DEX = tonumber(cols[15]) or 0, CHA = tonumber(cols[16]) or 0,
                SvM = tonumber(cols[17]) or 0, SvF = tonumber(cols[18]) or 0, SvC = tonumber(cols[19]) or 0, SvD = tonumber(cols[20]) or 0, SvP = tonumber(cols[21]) or 0,
                HPRegen = tonumber(cols[22]) or 0, ManaRegen = tonumber(cols[23]) or 0,
                Damage = tonumber(cols[24]) or 0, Delay = tonumber(cols[25]) or 0,
                Attack = tonumber(cols[26]) or 0,
                FocusType = cols[28] or "",
                FocusDesc = cols[29] or ""
            }
            
            characters[name].totalMana = characters[name].totalMana + item.Mana
            table.insert(characters[name].items, item)

            if item.FocusDesc ~= "" then
                local fTypes = split(item.FocusType, "|%-")
                local fDescs = split(item.FocusDesc, "|%-")

                for i, desc in ipairs(fDescs) do
                    local fType = fTypes[i] or "Focus"
                    
                    -- THE USER MANDATE: Strictly ignore 'Spell' types.
                    if fType ~= "Spell" and (fType == "Focus" or fType == "Worn") then
                        local key = weights.getFocusKey(desc)
                        local val = weights.parseValue(desc)
                        if key then
                            local nv = weights.normalizeFocusValue(val, key)
                            if nv > (characters[name].focuses[key] or 0) then 
                                characters[name].focuses[key] = nv 
                            end
                        end
                    end
                end
            end
        end
    end
    f:close()

    local results = {}
    for name, data in pairs(characters) do
        local base, focus = weights.scoreCharacter(data)
        table.insert(results, { name = name, class = data.class, score = base + focus })
    end

    table.sort(results, function(a, b) return a.score > b.score end)

    -- Compute summary stats
    local raidTotal = 0
    for _, res in ipairs(results) do raidTotal = raidTotal + res.score end
    local average = #results > 0 and math.floor(raidTotal / #results) or 0

    -- Top character per class
    local CLASS_NAMES = {
        WAR="Warrior", PAL="Paladin", SHD="Shadow Knight", CLR="Cleric", SHM="Shaman",
        DRU="Druid", MNK="Monk", BER="Berserker", ROG="Rogue", WIZ="Wizard",
        MAG="Magician", NEC="Necromancer", ENC="Enchanter", BRD="Bard",
        RNG="Ranger", BST="Beastlord"
    }
    local CLASS_ORDER = { "WAR","PAL","SHD","CLR","SHM","DRU","BRD","RNG","BST","MNK","BER","ROG","WIZ","MAG","NEC","ENC" }
    local CLASS_COLOR = {
        WAR="\ar", PAL="\ar", SHD="\ar",
        CLR="\ap", SHM="\ap", DRU="\ap",
        MNK="\ay", BER="\ay", ROG="\ay",
        WIZ="\at", MAG="\at", NEC="\at", ENC="\at",
        BRD="\am", RNG="\am", BST="\am"
    }

    local topByClass = {}
    for _, res in ipairs(results) do
        if not topByClass[res.class] then
            topByClass[res.class] = res
        end
    end

    printf("\ag[Score] ==============================\ax")
    printf("\ag[Score] === Raid GearScore Summary  ===\ax")
    printf("\ag[Score] ==============================\ax")
    printf("\ag[Score]\ax Total Raid GearScore:    \ao%d\ax", raidTotal)
    printf("\ag[Score]\ax Average Character Score: \ao%d\ax", average)
    printf("\ag[Score]\ax Characters Scored:       \aw%d\ax", #results)
    printf("\ag[Score] ------------------------------\ax")
    -- Fixed column widths: Shadow Knight: = 14 (longest class), ExampleBard = 16 (longest name)
    local COL_CLASS = 16
    local COL_NAME  = 18

    printf("\ag[Score]\ax Top Characters per Class:")
    for _, short in ipairs(CLASS_ORDER) do
        local res = topByClass[short]
        if res then
            local color = CLASS_COLOR[short] or "\aw"
            local fullName = CLASS_NAMES[short] or short
            local label = fullName .. ":"
            printf("  %s%-" .. COL_CLASS .. "s\ax \aw%-" .. COL_NAME .. "s\ax | \ao%d\ax", color, label, res.name, res.score)
        end
    end
    printf("\ag[Score] ==============================\ax")

    -- Return summary data for optional Discord post
    return { raidTotal=raidTotal, average=average, count=#results, topByClass=topByClass, CLASS_NAMES=CLASS_NAMES, CLASS_ORDER=CLASS_ORDER, COL_CLASS=COL_CLASS, COL_NAME=COL_NAME }
end

-- Optional local secret: EQ_DISCORD_WEBHOOK_URL. Unset disables Discord posting.
local WEBHOOK_URL = os.getenv("EQ_DISCORD_WEBHOOK_URL") or ""

local function postToDiscord(summary)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then return false end

    local lines = {}
    table.insert(lines, "=== Example Raid GearScore Summary ===")
    table.insert(lines, string.format("Total Raid GearScore:    %d", summary.raidTotal))
    table.insert(lines, string.format("Average Character Score: %d", summary.average))
    table.insert(lines, string.format("Characters Scored:       %d", summary.count))
    table.insert(lines, string.rep("-", 40))
    table.insert(lines, "Top Characters per Class:")
    for _, short in ipairs(summary.CLASS_ORDER) do
        local res = summary.topByClass[short]
        if res then
            local label = (summary.CLASS_NAMES[short] or short) .. ":"
            table.insert(lines, string.format("  %-16s %-18s | %d", label, res.name, res.score))
        end
    end
    table.insert(lines, string.rep("=", 40))

    -- Write payload to a temp file to avoid shell escaping issues
    local tmpFile = mq.TLO.MacroQuest.Path("Logs")() .. "\\discord_payload.json"
    local body = table.concat(lines, "\n"):gsub("\n", "\\n")
    local pf = io.open(tmpFile, "w")
    if not pf then return false end
    pf:write('{"content": "```\\n' .. body .. '\\n```"}')
    pf:close()

    local cmd = string.format('curl -s -X POST -H "Content-Type: application/json" -d @"%s" "%s"', tmpFile, WEBHOOK_URL)
    os.execute(cmd)
    return true
end

local args = {...}
local summary = main()
if args[1] == "discord" and summary then
    local ok = postToDiscord(summary)
    if ok then
        printf("\ag[Score]\ax Discord delivery attempted; verify receipt in your configured channel.")
    else
        printf("\ar[Score]\ax Discord post skipped — no webhook URL configured.")
    end
end
