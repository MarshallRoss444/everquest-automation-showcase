local mq = require('mq')
local weights = require('lib/weights')

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"

local function parseCSVLine(line)
    local columns = {}
    -- Correctly handle commas in quoted fields or use the pattern from before
    -- For MQ2 GearLog, commas are stripped from item names, but focus descs might have them?
    -- Actually, your gearlog.lua replaces commas with empty strings in names and focus descs.
    for col in (line..","):gmatch("(.-),") do
        table.insert(columns, col)
    end
    return columns
end

local function scoreRaid()
    local f = io.open(CSV_FILENAME, "r")
    if not f then
        print("\ar[Score] Error: Could not open " .. CSV_FILENAME .. "\ax")
        return
    end

    local header = f:read("*l") -- Skip header
    local characters = {} -- charName -> { class = "", items = {}, focuses = {} }

    for line in f:lines() do
        local cols = parseCSVLine(line)
        -- Col 1: Name, 2: Class, 3: Type, 4: Slot, 5: AugSlot, 6: ItemName, 
        -- 7: AC, 8: HP, 9: Mana, 10: STR, 11: STA, 12: INT, 13: WIS, 14: AGI, 15: DEX, 16: CHA,
        -- 17: SvM, 18: SvF, 19: SvC, 20: SvD, 21: SvP, 22: HPRegen, 23: ManaRegen, 24: Focus, 25: FocusType, 26: FocusDesc
        
        if #cols >= 26 then
            local name = cols[1]
            local class = cols[2]
            
            local itemData = {
                ItemName = cols[6],
                AC = tonumber(cols[7]) or 0,
                HP = tonumber(cols[8]) or 0,
                Mana = tonumber(cols[9]) or 0,
                STR = tonumber(cols[10]) or 0,
                STA = tonumber(cols[11]) or 0,
                INT = tonumber(cols[12]) or 0,
                WIS = tonumber(cols[13]) or 0,
                AGI = tonumber(cols[14]) or 0,
                DEX = tonumber(cols[15]) or 0,
                SvM = tonumber(cols[17]) or 0,
                SvF = tonumber(cols[18]) or 0,
                SvC = tonumber(cols[19]) or 0,
                SvD = tonumber(cols[20]) or 0,
                SvP = tonumber(cols[21]) or 0,
                HPRegen = tonumber(cols[22]) or 0,
                ManaRegen = tonumber(cols[23]) or 0,
                Focus = cols[24],
                FocusType = cols[25],
                FocusDesc = cols[26] or ""
            }

            if not characters[name] then
                characters[name] = { class = class, items = {}, focuses = {} }
            end

            -- Capture best focuses character-wide
            if itemData.FocusDesc ~= "" then
                -- Support both | and ; delimiters
                for part in itemData.FocusDesc:gmatch("([^|;]+)") do
                    local key = weights.getFocusKey(part)
                    local val = weights.parseValue(part)
                    if key and val > (characters[name].focuses[key] or 0) then
                        characters[name].focuses[key] = val
                    end
                end
            end
            
            table.insert(characters[name].items, itemData)
        end
    end
    f:close()

    local results = {}
    local POWER_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\RaidPower.csv"
    local pFile = io.open(POWER_FILENAME, "w")
    if pFile then
        pFile:write("Name,Class,TotalScore,Haste,ManaPres,SpellDmg,Healing,CastTime,Duration,Range,Hate,Dodge,MeleeCrit,SpellCrit\n")
    end

    for name, data in pairs(characters) do
        local totalScore = 0
        local profile = weights.ClassMap[data.class] or weights.ClassMap.WAR
        
        -- 1. Score Base Stats
        for _, item in ipairs(data.items) do
            -- Re-calculating base score without focuses to avoid double counting
            totalScore = totalScore + (item.AC * profile.AC)
            totalScore = totalScore + (item.HP * profile.HP)
            totalScore = totalScore + (item.Mana * profile.Mana)
            totalScore = totalScore + (item.STR * profile.STR)
            totalScore = totalScore + (item.STA * profile.STA)
            totalScore = totalScore + (item.INT * profile.INT)
            totalScore = totalScore + (item.WIS * profile.WIS)
            totalScore = totalScore + (item.AGI * profile.AGI)
            totalScore = totalScore + (item.DEX * profile.DEX)
            totalScore = totalScore + (item.HPRegen * profile.HPRegen)
            totalScore = totalScore + (item.ManaRegen * profile.ManaRegen)
            totalScore = totalScore + (item.SvM * profile.SvMagic)
            totalScore = totalScore + (item.SvF * profile.SvFire)
            totalScore = totalScore + (item.SvC * profile.SvCold)
            totalScore = totalScore + (item.SvD * profile.SvDisease)
            totalScore = totalScore + (item.SvP * profile.SvPoison)
        end

        -- 2. Score Focuses (Highest character-wide)
        for key, val in pairs(data.focuses) do
            if profile[key] then
                totalScore = totalScore + (val * profile[key])
            end
        end

        local finalScore = math.floor(totalScore)
        table.insert(results, { name = name, class = data.class, score = finalScore })

        if pFile then
            local f = data.focuses
            local line = string.format("%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
                name, data.class, finalScore,
                f.Focus_Haste or 0, f.Focus_ManaPres or 0, f.Focus_SpellDmg or 0, f.Focus_Healing or 0,
                f.Focus_CastTime or 0, f.Focus_Duration or 0, f.Focus_Range or 0, f.Focus_Hate or 0,
                f.Focus_Dodge or 0, f.Focus_MeleeCrit or 0, f.Focus_SpellCrit or 0)
            pFile:write(line)
        end
    end
    if pFile then pFile:close() end

    table.sort(results, function(a, b) return a.score > b.score end)

    print("\ag[Score] ========================================\ax")
    print(string.format("%-15s | %-5s | %-10s", "Name", "Class", "Gear Score"))
    print("\ag[Score] ----------------------------------------\ax")
    for _, res in ipairs(results) do
        local color = "\aw"
        if res.class == "WAR" or res.class == "PAL" or res.class == "SHD" then color = "\ar" end
        if res.class == "CLR" or res.class == "SHM" or res.class == "DRU" then color = "\ap" end
        print(string.format("%-15s | %s%-5s\ax | %d", res.name, color, res.class, res.score))
    end
    print("\ag[Score] ========================================\ax")
end

scoreRaid()
