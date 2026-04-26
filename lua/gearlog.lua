local mq = require('mq')

-- ==============================================================================
-- GearLog.lua - Version 17.4 (VERIFIED STAT RESTORATION)
-- ==============================================================================
-- Collects AC, HP, Mana, Primary Stats, and Verified Attack.
-- Removed non-existent Accuracy stat.

local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"

local function printf(...)
    print(string.format(...))
end

local function parseFocus(fName)
    local name = tostring(fName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    local desc = ""
    local effects = {}
    for i=1, 12 do
        local attrib = 0
        pcall(function() attrib = s.Attrib(i)() or 0 end)
        local val = 0
        pcall(function()
            local b1 = math.abs(s.Base(i)() or 0)
            local b2 = math.abs(s.Base2(i)() or 0)
            val = math.max(b1, b2)
        end)
        if attrib > 0 and val >= 1 then
            if not effects[attrib] or val > effects[attrib] then effects[attrib] = val end
        end
    end
    for attrib, val in pairs(effects) do
        if attrib == 15 or attrib == 127 then desc = desc .. "CastTime " .. val .. "% - "
        elseif attrib == 108 or attrib == 132 then desc = desc .. "ManaPres " .. val .. "% - "
        elseif attrib == 104 or attrib == 124 then desc = desc .. "SpellDmg " .. val .. "% - "
        elseif attrib == 105 or attrib == 125 then desc = desc .. "Healing " .. val .. "% - "
        elseif attrib == 114 or attrib == 11 then desc = desc .. "Hate " .. val .. "% - "
        elseif attrib == 174 then desc = desc .. "Dodge " .. val .. "% - "
        elseif attrib == 175 then desc = desc .. "Parry " .. val .. "% - "
        elseif attrib == 168 or attrib == 169 or attrib == 273 then desc = desc .. "MeleeCrit " .. val .. "% - "
        elseif attrib == 192 or attrib == 294 then desc = desc .. "SpellCrit " .. val .. "% - "
        elseif attrib == 100 then desc = desc .. "Ferocity " .. val .. " - "
        elseif attrib == 4 or attrib == 216 or attrib == 184 then desc = desc .. "Accuracy " .. val .. " - "
        elseif attrib == 177 then desc = desc .. "DoubleAttack " .. val .. "% - "
        end
    end
    if desc:len() > 0 then desc = desc:sub(1, -4) end
    return desc:gsub(",", " "):gsub("|", "-") 
end

local function writeLine(line)
    local f = io.open(CSV_FILENAME, "a")
    if f then
        f:write(line:gsub("|", ",") .. "\n")
        f:close()
    end
end

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    if not me then return end
    local myClass = mq.TLO.Me.Class.ShortName()
    
    if targetDriver ~= "local" then mq.delay(math.random(500, 5000)) end

    for i = 0, 21 do
        local item = mq.TLO.Me.Inventory(i)
        if item and item() then
            local iName = tostring(item.Name()):gsub(",", ""):gsub("|", "")
            local slotObj = mq.TLO.InvSlot(i)
            local sName = tostring(slotObj and slotObj() and slotObj.Name() or i):gsub(",", "")
            
            local ac = (item.AC and item.AC()) or 0
            local hp = (item.HP and item.HP()) or 0
            local mana = (item.Mana and item.Mana()) or 0
            local str = (item.STR and item.STR()) or 0
            local sta = (item.STA and item.STA()) or 0
            local int = (item.INT and item.INT()) or 0
            local wis = (item.WIS and item.WIS()) or 0
            local agi = (item.AGI and item.AGI()) or 0
            local dex = (item.DEX and item.DEX()) or 0
            local cha = (item.CHA and item.CHA()) or 0
            local hpr = (item.HPRegen and item.HPRegen()) or 0
            local mnr = (item.ManaRegen and item.ManaRegen()) or 0
            local dam = (item.Damage and item.Damage()) or 0
            local del = (item.ItemDelay and item.ItemDelay()) or (item.Delay and item.Delay()) or 0
            
            -- VERIFIED PROPERTY: Attack
            local atk = (item.Attack and item.Attack()) or 0
            
            local svm = (item.MR and item.MR()) or (item.SvMagic and item.SvMagic()) or 0
            local svf = (item.FR and item.FR()) or (item.SvFire and item.SvFire()) or 0
            local svc = (item.CR and item.CR()) or (item.SvCold and item.SvCold()) or 0
            local svd = (item.DR and item.DR()) or (item.SvDisease and item.SvDisease()) or 0
            local svp = (item.PR and item.PR()) or (item.SvPoison and item.SvPoison()) or 0
            
            local focusNames, focusDescs = {}, {}
            local possible = { "Focus", "Worn", "Spell", "Clicky" }
            for _, t in ipairs(possible) do
                local v = tostring(item[t])
                if v ~= "NULL" and v ~= "nil" and v ~= "" then
                    table.insert(focusNames, v)
                    table.insert(focusDescs, (parseFocus(v)))
                end
            end
            
            -- Structure: 1-5 Chars, 6 Name, 7-16 Base, 17-21 Sv, 22-23 Regen, 24 Dam, 25 Del, 26 Atk, 27-29 Focus
            local data = string.format("%s|%s|Item|%d-%s||%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s",
                me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha,
                svm, svf, svc, svd, svp, hpr, mnr, dam, del, atk,
                table.concat(focusNames, " - "), "", table.concat(focusDescs, " - "))
            
            if targetDriver == "local" then writeLine(data)
            else mq.cmdf("/dex %s /gearlog_add %s", targetDriver, data) end
            mq.delay(20)
        end
    end
end

local function collect()
    local expected = mq.TLO.Raid.Members() or 1
    printf("\ag[GearLog]\ax Collecting modern stats from %d characters...", expected)
    local f = io.open(CSV_FILENAME, "w")
    if f then
        f:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Damage,Delay,Attack,Focus,FocusType,FocusDesc\n")
        f:close()
    end
    mq.bind('/gearlog_add', function(...) writeLine(table.concat({...}, " ")) end)
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    sendData("local")
    mq.delay(30000)
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete. Run /lua run score now.")
end

local args = {...}
if args[1] == "send" then sendData(args[2]) else collect() end
