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

local function generateReport(characters)
    local reportPath = mq.TLO.MacroQuest.Path("Logs")() .. "\\ScoreReport.txt"
    local rf = io.open(reportPath, "w")
    rf:write("GEAR SCORE BREAKDOWN REPORT (v17.0 - Unified Logic)\n")
    rf:write("============================================================\n\n")

    local sortedChars = {}
    for name, data in pairs(characters) do
        local base, focus = weights.scoreCharacter(data)
        table.insert(sortedChars, { name = name, class = data.class, base = base, focus = focus, total = base + focus })
    end
    
    table.sort(sortedChars, function(a, b) return a.total > b.total end)

    for _, c in ipairs(sortedChars) do
        rf:write(string.format("NAME: %-15s | CLASS: %-4s | TOTAL: %d\n", c.name, c.class, c.total))
        rf:write(string.format("  -> Base Stat Score:  %d (Raw AC/HP/Primary/Weapon)\n", c.base))
        rf:write(string.format("  -> Focus Effect Score: %d (Role-Based & Normalized)\n", c.focus))
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
            if not characters[name] then characters[name] = { class = class, items = {}, focuses = {}, totalMana = 0 } end
            
            local item = {
                AC = tonumber(cols[7]) or 0, HP = tonumber(cols[8]) or 0, Mana = tonumber(cols[9]) or 0,
                STR = tonumber(cols[10]) or 0, STA = tonumber(cols[11]) or 0, INT = tonumber(cols[12]) or 0, WIS = tonumber(cols[13]) or 0,
                AGI = tonumber(cols[14]) or 0, DEX = tonumber(cols[15]) or 0, SvM = tonumber(cols[17]) or 0, SvF = tonumber(cols[18]) or 0,
                SvC = tonumber(cols[19]) or 0, SvD = tonumber(cols[20]) or 0, SvP = tonumber(cols[21]) or 0,
                HPRegen = tonumber(cols[22]) or 0, ManaRegen = tonumber(cols[23]) or 0,
                Damage = tonumber(cols[24]) or 0, Delay = tonumber(cols[25]) or 0,
                FocusDesc = cols[28] or ""
            }
            
            characters[name].totalMana = characters[name].totalMana + item.Mana
            table.insert(characters[name].items, item)

            if item.FocusDesc ~= "" then
                for part in item.FocusDesc:gmatch("([^|;%-]+)") do
                    local key = weights.getFocusKey(part)
                    local val = weights.parseValue(part)
                    if key and val > (characters[name].focuses[key] or 0) then 
                        characters[name].focuses[key] = val 
                    end
                end
            end
        end
    end
    f:close()

    local results = {}
    local POWER_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\RaidPower.csv"
    local pFile = io.open(POWER_FILENAME, "w")
    if pFile then pFile:write("Name,Class,TotalScore,Haste,ManaPres,SpellDmg,Healing,CastTime,Duration,Range,Hate,Dodge,MeleeCrit,SpellCrit\n") end

    for name, data in pairs(characters) do
        local base, focus = weights.scoreCharacter(data)
        local totalScore = base + focus
        table.insert(results, { name = name, class = data.class, score = totalScore })
        
        if pFile then
            local f = data.focuses
            pFile:write(string.format("%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", name, data.class, totalScore,
                f.Focus_Haste or 0, f.Focus_Bene_ManaPres or f.Focus_Detri_ManaPres or 0, f.Focus_Detri_SpellDmg or 0, 
                f.Focus_Bene_Healing or 0, f.Focus_Bene_CastTime or f.Focus_Detri_CastTime or 0,
                f.Focus_Duration or 0, f.Focus_Range or 0, f.Focus_Hate or 0, f.Focus_Dodge or 0, 
                f.Focus_MeleeCrit or 0, f.Focus_SpellCrit or 0))
        end
    end
    if pFile then pFile:close() end

    table.sort(results, function(a, b) return a.score > b.score end)
    print("\ag[Score] ========================================\ax")
    for _, res in ipairs(results) do
        local color = "\aw"
        if res.class == "WAR" or res.class == "PAL" or res.class == "SHD" then color = "\ar" end
        if res.class == "CLR" or res.class == "SHM" or res.class == "DRU" then color = "\ap" end
        print(string.format("%-15s | %s%-5s\ax | %d", res.name, color, res.class, res.score))
    end
    
    generateReport(characters)
end

scoreRaid()
