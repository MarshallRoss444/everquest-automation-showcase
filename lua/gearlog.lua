local mq = require('mq')

-- ==============================================================================
-- GearLog MMO - Emergency Stability Build
-- ==============================================================================
local args = {...}
local mode = args[1] or "collect"
local DRIVER_NAME = "ExampleTank"
local CSV_FILENAME = mq.TLO.MacroQuest.Path("Logs")() .. "\\MyGearLog.csv"
local INVENTORY_SLOTS = 21

-- Helper: Parse Focus Math (Fixed 1% bug)
local function parseFocus(fName)
    local name = tostring(fName or "")
    if name == "" or name == "NULL" or name == "nil" then return "" end
    
    local s = mq.TLO.Spell(name)
    if not s or not s() or s.ID() == 0 then return "" end
    
    local desc = ""
    local isBene = false
    local effects = {}

    for i=1, 12 do
        local spa = 0
        pcall(function() spa = s.SPA(i)() or s.Attrib(i)() or 0 end)
        
        local val = 0
        pcall(function()
            local b = math.abs(s.Base(i)() or 0)
            local m = math.abs(s.Max(i)() or 0)
            val = math.max(b, m)
        end)
        
        if spa == 138 and s.Base(i)() == 1 then isBene = true
        elseif spa > 0 and val > 1 then
            if not effects[spa] or val > effects[spa] then
                effects[spa] = val
            end
        end
    end
    
    local prefix = isBene and "Bene " or "Detri "
    for spa, val in pairs(effects) do
        if spa == 15 or spa == 127 then desc = desc .. string.format("%sCast Time %d%%; ", prefix, val)
        elseif spa == 108 or spa == 132 then desc = desc .. string.format("%sMana Pres %d%%; ", prefix, val)
        elseif spa == 104 or spa == 124 then desc = desc .. string.format("%sSpell Dmg %d%%; ", prefix, val)
        elseif spa == 105 or spa == 125 then desc = desc .. "Healing " .. val .. "%; "
        elseif spa == 128 then desc = desc .. string.format("%sDuration %d%%; ", prefix, val)
        elseif spa == 129 then desc = desc .. string.format("%sRange %d%%; ", prefix, val)
        end
    end
    
    return desc:len() > 0 and desc:sub(1, -3) or ""
end

local function startCollecting()
    printf("\ag[GearLog]\ax Starting Collection...")
    local file = io.open(CSV_FILENAME, "w")
    if not file then return end
    file:write("Name,Class,Type,Slot,AugSlot,ItemName,AC,HP,Mana,STR,STA,INT,WIS,AGI,DEX,CHA,SvM,SvF,SvC,SvD,SvP,HPRegen,ManaRegen,Focus,FocusDesc\n")
    file:close()
    
    mq.bind('/gearlog_add', function(...)
        local line = table.concat({...}, " ")
        local f = io.open(CSV_FILENAME, "a")
        if f then f:write(line .. "\n") f:close() end
    end)
    
    mq.cmdf("/dgae /lua run gearlog send %s", mq.TLO.Me.Name())
    mq.cmdf("/lua run gearlog send %s", mq.TLO.Me.Name())
    
    local endTime = os.time() + 45
    while os.time() < endTime do
        mq.doevents()
        mq.delay(100)
    end
    mq.unbind('/gearlog_add')
    printf("\ag[GearLog]\ax Complete!")
end

local function sendData(targetDriver)
    local me = mq.TLO.Me.Name()
    local myClass = mq.TLO.Me.Class.ShortName()
    
    for i = 0, INVENTORY_SLOTS do
        pcall(function()
            local item = mq.TLO.Me.Inventory(i)
            if item and item() then
                local iName = tostring(item.Name()):gsub(",", ""):gsub("\"", "")
                local sName = tostring(mq.TLO.InvSlot(i).Name()):gsub(",", "")
                
                -- Standard Stats
                local ac = item.AC() or 0
                local hp = item.HP() or 0
                local mana = item.Mana() or 0
                local str = item.STR and item.STR() or 0
                local sta = item.STA and item.STA() or 0
                local int = item.INT and item.INT() or 0
                local wis = item.WIS and item.WIS() or 0
                local agi = item.AGI and item.AGI() or 0
                local dex = item.DEX and item.DEX() or 0
                local cha = item.CHA and item.CHA() or 0
                local hpregen = item.HPRegen and item.HPRegen() or 0
                local manaregen = item.ManaRegen and item.ManaRegen() or 0
                
                -- Crash-Proof Resists
                local svm = item.MR and item.MR() or item.SvMagic and item.SvMagic() or 0
                local svf = item.FR and item.FR() or item.SvFire and item.SvFire() or 0
                local svc = item.CR and item.CR() or item.SvCold and item.SvCold() or 0
                local svd = item.DR and item.DR() or item.SvDisease and item.SvDisease() or 0
                local svp = item.PR and item.PR() or item.SvPoison and item.SvPoison() or 0
                
                -- Focus Name (The most stable property in your build)
                local focusName = tostring(item.Spell)
                if focusName == "NULL" or focusName == "nil" then focusName = "" end
                
                local focusDesc = ""
                if focusName ~= "" then
                    focusDesc = parseFocus(focusName)
                end
                
                local dataLine = string.format("%s,%s,Item,%d-%s,,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s",
                    me, myClass, i, sName, iName, ac, hp, mana, str, sta, int, wis, agi, dex, cha, svm, svf, svc, svd, svp, hpregen, manaregen, focusName, focusDesc)
                
                mq.cmdf("/dex %s /gearlog_add %s", targetDriver, dataLine)
                mq.delay(30)
            end
        end)
    end
end

if mode == "collect" then startCollecting()
elseif mode == "send" then sendData(args[2] or DRIVER_NAME)
end
