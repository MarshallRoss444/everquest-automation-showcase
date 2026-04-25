local mq = require('mq')
local weights = require('lib/weights')

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"

local function parseCSVLine(line)
    local columns = {}
    for col in (line..","):gmatch("(.-),") do
        table.insert(columns, col)
    end
    return columns
end

local function generateReport()
    local f = io.open(CSV_FILENAME, "r")
    if not f then return end
    local header = f:read("*l")
    local characters = {}

    for line in f:lines() do
        local cols = parseCSVLine(line)
        if #cols >= 28 then
            local name, class = cols[1], cols[2]
            if not characters[name] then characters[name] = { class = class, items = {}, focuses = {} } end
            
            local item = {
                Name = cols[6], AC = tonumber(cols[7]) or 0, HP = tonumber(cols[8]) or 0, Mana = tonumber(cols[9]) or 0,
                STR = tonumber(cols[10]) or 0, STA = tonumber(cols[11]) or 0, INT = tonumber(cols[12]) or 0, WIS = tonumber(cols[13]) or 0,
                AGI = tonumber(cols[14]) or 0, DEX = tonumber(cols[15]) or 0, SvM = tonumber(cols[17]) or 0, SvF = tonumber(cols[18]) or 0,
                SvC = tonumber(cols[19]) or 0, SvD = tonumber(cols[20]) or 0, SvP = tonumber(cols[21]) or 0,
                HPRegen = tonumber(cols[22]) or 0, ManaRegen = tonumber(cols[23]) or 0, 
                Damage = tonumber(cols[24]) or 0, Delay = tonumber(cols[25]) or 0,
                FocusDesc = cols[28] or ""
            }
            table.insert(characters[name].items, item)
            
            if item.FocusDesc ~= "" then
                for part in item.FocusDesc:gmatch("([^|;%-]+)") do
                    local key = weights.getFocusKey(part)
                    local val = weights.parseValue(part)
                    if key and val > (characters[name].focuses[key] or 0) then characters[name].focuses[key] = val end
                end
            end
        end
    end
    f:close()

    local reportPath = mq.TLO.MacroQuest.Path("Logs")() .. "\\ScoreReport.txt"
    local rf = io.open(reportPath, "w")
    rf:write("GEAR SCORE BREAKDOWN REPORT (v16.0 - Weighted Weapons)\n")
    rf:write("============================================================\n\n")

    local sortedChars = {}
    for name, data in pairs(characters) do
        local profile = weights.ClassMap[data.class] or weights.ClassMap.WAR
        local baseScore = 0
        local totalMana = 0
        for _, item in ipairs(data.items) do
            totalMana = totalMana + item.Mana
            baseScore = baseScore + (item.AC * profile.AC) + (item.HP * profile.HP) + (item.Mana * profile.Mana) +
                        (item.STR * profile.STR) + (item.STA * profile.STA) + (item.INT * profile.INT) + (item.WIS * profile.WIS) +
                        (item.HPRegen * profile.HPRegen) + (item.ManaRegen * profile.ManaRegen) +
                        (item.Damage * profile.Damage) + (item.Delay * profile.Delay)
        end
        
        local focusScore = 0
        local hasMana = (totalMana > 0)
        for key, rawVal in pairs(data.focuses) do
            local val = weights.normalizeValue(rawVal, key)
            if profile[key] then
                local isSpellFocus = key:find("ManaPres") or key:find("SpellDmg") or key:find("Healing") or key:find("CastTime")
                if not isSpellFocus or hasMana then
                    focusScore = focusScore + (val * profile[key])
                end
            end
        end
        
        table.insert(sortedChars, { name = name, class = data.class, base = baseScore, focus = focusScore, total = baseScore + focusScore, mana = totalMana })
    end
    
    table.sort(sortedChars, function(a, b) return a.total > b.total end)

    for _, c in ipairs(sortedChars) do
        rf:write(string.format("NAME: %-15s | CLASS: %-4s | TOTAL: %d\n", c.name, c.class, c.total))
        rf:write(string.format("  -> Base Stat Score:  %d (Raw AC/HP/Dam/Del)\n", c.base))
        rf:write(string.format("  -> Focus Effect Score: %d (Role-Based Filtering)\n", c.focus))
        rf:write("  ----------------------------------------------------------\n")
    end
    rf:close()
    print("\ag[Score] Updated report: Logs/ScoreReport.txt\ax")
end

local function scoreRaid()
    local f = io.open(CSV_FILENAME, "r")
    if not f then return end
    local header = f:read("*l")
    local characters = {}

    for line in f:lines() do
        local cols = parseCSVLine(line)
        if #cols >= 28 then
            local name, class = cols[1], cols[2]
            if not characters[name] then characters[name] = { class = class, items = {}, focuses = {} } end
            local item = {
                AC = tonumber(cols[7]) or 0, HP = tonumber(cols[8]) or 0, Mana = tonumber(cols[9]) or 0,
                STR = tonumber(cols[10]) or 0, STA = tonumber(cols[11]) or 0, INT = tonumber(cols[12]) or 0, WIS = tonumber(cols[13]) or 0,
                AGI = tonumber(cols[14]) or 0, DEX = tonumber(cols[15]) or 0, SvM = tonumber(cols[17]) or 0, SvF = tonumber(cols[18]) or 0,
                SvC = tonumber(cols[19]) or 0, SvD = tonumber(cols[20]) or 0, SvP = tonumber(cols[21]) or 0,
                HPRegen = tonumber(cols[22]) or 0, ManaRegen = tonumber(cols[23]) or 0,
                Damage = tonumber(cols[24]) or 0, Delay = tonumber(cols[25]) or 0,
                FocusDesc = cols[28] or ""
            }
            if item.FocusDesc ~= "" then
                for part in item.FocusDesc:gmatch("([^|;%-]+)") do
                    local key = weights.getFocusKey(part)
                    local val = weights.parseValue(part)
                    if key and val > (characters[name].focuses[key] or 0) then characters[name].focuses[key] = val end
                end
            end
            table.insert(characters[name].items, item)
        end
    end
    f:close()

    local results = {}
    for name, data in pairs(characters) do
        local totalScore = 0
        local totalMana = 0
        local profile = weights.ClassMap[data.class] or weights.ClassMap.WAR
        for _, item in ipairs(data.items) do
            totalMana = totalMana + item.Mana
            totalScore = totalScore + (item.AC * profile.AC) + (item.HP * profile.HP) + (item.Mana * profile.Mana) +
                        (item.STR * profile.STR) + (item.STA * profile.STA) + (item.INT * profile.INT) + (item.WIS * profile.WIS) +
                        (item.AGI * profile.AGI) + (item.DEX * profile.DEX) + (item.HPRegen * profile.HPRegen) + (item.ManaRegen * profile.ManaRegen) +
                        (item.Damage * profile.Damage) + (item.Delay * profile.Delay) +
                        (item.SvM * profile.SvMagic) + (item.SvF * profile.SvFire) + (item.SvC * profile.SvCold) + (item.SvD * profile.SvDisease) + (item.SvP * profile.SvPoison)
        end
        local hasMana = (totalMana > 0)
        for key, rawVal in pairs(data.focuses) do
            local val = weights.normalizeValue(rawVal, key)
            if profile[key] then 
                local isSpellFocus = key:find("ManaPres") or key:find("SpellDmg") or key:find("Healing") or key:find("CastTime")
                if not isSpellFocus or hasMana then
                    totalScore = totalScore + (val * profile[key]) 
                end
            end
        end
        table.insert(results, { name = name, class = data.class, score = math.floor(totalScore) })
    end
    table.sort(results, function(a, b) return a.score > b.score end)
    print("\ag[Score] ========================================\ax")
    for _, res in ipairs(results) do
        local color = "\aw"
        if res.class == "WAR" or res.class == "PAL" or res.class == "SHD" then color = "\ar" end
        if res.class == "CLR" or res.class == "SHM" or res.class == "DRU" then color = "\ap" end
        print(string.format("%-15s | %s%-5s\ax | %d", res.name, color, res.class, res.score))
    end
    generateReport()
end

scoreRaid()
