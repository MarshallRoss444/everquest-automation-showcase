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
    
    printf("\ag[Score] Calibrated Snapshot Complete (Full %d Characters)\ax", #results)
    for i, res in ipairs(results) do
        local classColor = "\aw"
        if res.class == "WAR" or res.class == "PAL" or res.class == "SHD" then classColor = "\ar"
        elseif res.class == "CLR" or res.class == "SHM" or res.class == "DRU" then classColor = "\ap"
        elseif res.class == "MNK" or res.class == "BER" or res.class == "ROG" then classColor = "\ay"
        elseif res.class == "WIZ" or res.class == "MAG" or res.class == "NEC" or res.class == "ENC" then classColor = "\at"
        elseif res.class == "BRD" or res.class == "RNG" or res.class == "BST" then classColor = "\am"
        end
        printf("%d. \aw%-15s\ax (%s%-4s\ax) | \ao%d\ax", i, res.name, classColor, res.class, res.score)
    end

    local raidTotal = 0
    for _, res in ipairs(results) do raidTotal = raidTotal + res.score end
    printf("\ag[Score] Raid Total GearScore: \ao%d\ax", raidTotal)
end

main()
