--[[
    PaladinBuffAssign
    Buff assignment tool for paladins in group/raid.
--]]

local addonName = "PaladinBuffAssign"
local PBA = {}
_G[addonName] = PBA
PBA.version = "3.4.10"

-- ==================== LOCALE ====================
local L = {}
if GetLocale() == "ruRU" then
    L.title = "Назначение баффов паладинов"
    L.enabled = "Включить"; L.groupOnly = "Только в группе/рейде"
    L.menuDirection = "Направление меню"; L.dirLeft = "Влево"; L.dirRight = "Вправо"
    L.width = "Ширина бара"; L.height = "Высота бара"; L.scale = "Масштаб"; L.spacing = "Отступ"
    L.barAlpha = "Прозрачность баров"; L.menuAlpha = "Прозрачность меню"
    L.locked = "Закрепить позицию"; L.minimal = "Минималистичный режим"
    L.buffNameMode = "Название баффа в меню"
    L.bmIcon = "Иконка"; L.bmShort = "Сокращение"; L.bmFull = "Полное название"
    L.announceNameMode = "Название баффа в объявлении"; L.anShort = "Сокращение"; L.anFull = "Полное название"
    L.announceChannel = "Канал объявления"
    L.chAuto = "Авто (RW, иначе RAID)"
    L.chRaid = "Raid (/raid)"
    L.chRW   = "Raid Warning (/rw)"
    L.chLocal = "Только локально"
    L.assign = "Назначить бафф"; L.unassign = "Снять все назначения"; L.announce = "Объявить"
    L.noPaladins = "Нет паладинов в группе"; L.allAssigned = "Все баффы назначены"
    L.assignedTo = "%s: %s"
    L.loaded = "Загружен. /pba — настройки."
    L.proto = "Прото-бафф"
    L.specUnknown = "Неизв."; L.specHoly = "Свет"; L.specProt = "Защита"; L.specRet = "Воздаяние"
    L.shortKings = "Каска"; L.shortMight = "Кулак"; L.shortWisdom = "Крест"
    L.shortProto = "Прото"
else
    L.title = "Paladin Buff Assign"
    L.enabled = "Enable"; L.groupOnly = "Only in group/raid"
    L.menuDirection = "Menu direction"; L.dirLeft = "Left"; L.dirRight = "Right"
    L.width = "Bar width"; L.height = "Bar height"; L.scale = "Scale"; L.spacing = "Spacing"
    L.barAlpha = "Bar alpha"; L.menuAlpha = "Menu alpha"
    L.locked = "Lock position"; L.minimal = "Minimalist mode"
    L.buffNameMode = "Buff name in menu"
    L.bmIcon = "Icon"; L.bmShort = "Short name"; L.bmFull = "Full name"
    L.announceNameMode = "Buff name in announce"; L.anShort = "Short name"; L.anFull = "Full name"
    L.announceChannel = "Announce channel"
    L.chAuto = "Auto (RW, else RAID)"
    L.chRaid = "Raid (/raid)"
    L.chRW   = "Raid Warning (/rw)"
    L.chLocal = "Local only"
    L.assign = "Assign buff"; L.unassign = "Unassign all"; L.announce = "Announce"
    L.noPaladins = "No paladins in group"; L.allAssigned = "All buffs assigned"
    L.assignedTo = "%s: %s"
    L.loaded = "Loaded. Type /pba for options."
    L.proto = "Proto-buff"
    L.specUnknown = "Unknown"; L.specHoly = "Holy"; L.specProt = "Protection"; L.specRet = "Retribution"
    L.shortKings = "Kings"; L.shortMight = "Might"; L.shortWisdom = "Wisdom"
    L.shortProto = "Proto"
end
PBA.L = L

-- ==================== BUFF DEFINITIONS ====================
local BUFF_POOL = {
    { key = "kings",  id = 20217, name = GetSpellInfo(20217) or "Blessing of Kings",  icon = "Interface\\Icons\\Spell_Magic_MageArmor",         short = L.shortKings },
    { key = "might",  id = 19838, name = GetSpellInfo(19838) or "Blessing of Might",  icon = "Interface\\Icons\\Spell_Holy_FistOfJustice",      short = L.shortMight },
    { key = "wisdom", id = 19742, name = GetSpellInfo(19742) or "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom",       short = L.shortWisdom },
    { key = "proto",  id = 20911, name = L.proto,                                     icon = "Interface\\Icons\\Spell_nature_lightningshield", short = L.shortProto },
}
PBA.BUFF_POOL = BUFF_POOL
local BUFF_KEY_ORDER = { "kings", "might", "wisdom", "proto" }
local BUFF_DISPLAY, BUFF_SHORT = {}, {}
for _, b in ipairs(BUFF_POOL) do
    BUFF_DISPLAY[b.key] = b.name
    BUFF_SHORT[b.key] = b.short
end

-- ==================== SPEC DETECTION ====================
local LibGroupTalents = LibStub and LibStub("LibGroupTalents-1.0", true)
local LibTalentQuery  = LibStub and LibStub("LibTalentQuery-1.0", true)

local function GetTalentPoints(tab, isInspect, group)
    local ok, _, _, pointsSpent = pcall(GetTalentTabInfo, tab, isInspect, nil, group)
    if not ok then return 0 end
    return pointsSpent or 0
end

local function SpecFromPoints(x, y, z)
    if x == 0 and y == 0 and z == 0 then return nil end
    if x > y and x > z then return "Holy" end
    if y > x and y > z then return "Protection" end
    if z > x and z > y then return "Retribution" end
    if x > 0 then return "Holy" end
    if y > 0 then return "Protection" end
    if z > 0 then return "Retribution" end
    return nil
end

local function GetPlayerSpecViaTalents()
    local tg = GetActiveTalentGroup(false) or 1
    return SpecFromPoints(
        GetTalentPoints(1, false, tg),
        GetTalentPoints(2, false, tg),
        GetTalentPoints(3, false, tg)
    )
end

local function GetInspectedSpec()
    local activeGroup = 1
    if GetActiveTalentGroup then
        local ok, g = pcall(GetActiveTalentGroup, true)
        if ok and (g == 1 or g == 2) then activeGroup = g end
    end

    local h = GetTalentPoints(1, true, activeGroup)
    local p = GetTalentPoints(2, true, activeGroup)
    local r = GetTalentPoints(3, true, activeGroup)
    if (h + p + r) > 0 then
        return SpecFromPoints(h, p, r), { h, p, r }, activeGroup
    end

    for group = 1, 2 do
        if group ~= activeGroup then
            local gh = GetTalentPoints(1, true, group)
            local gp = GetTalentPoints(2, true, group)
            local gr = GetTalentPoints(3, true, group)
            if (gh + gp + gr) > 0 then
                return SpecFromPoints(gh, gp, gr), { gh, gp, gr }, group
            end
        end
    end

    return nil, nil, activeGroup
end

local SPEC_SPELLBOOK_NAMES = {
    ["Holy Shock"] = "Holy", ["Шок Света"] = "Holy", ["Святой шок"] = "Holy",
    ["Beacon of Light"] = "Holy", ["Маяк Света"] = "Holy",
    ["Avenger's Shield"] = "Protection", ["Щит мстителя"] = "Protection", ["Щит Мстителя"] = "Protection",
    ["Hammer of the Righteous"] = "Protection", ["Молот праведности"] = "Protection",
    ["Crusader Strike"] = "Retribution", ["Удар крестоносца"] = "Retribution", ["Удар Крестоносца"] = "Retribution",
    ["Divine Storm"] = "Retribution", ["Божественная буря"] = "Retribution",
}

local function ScanSpellbookForSpec()
    if IsSpellKnown and IsSpellKnown(35395) then return "Retribution" end
    if IsSpellKnown and IsSpellKnown(31935) then return "Protection" end
    if IsSpellKnown and IsSpellKnown(20473) then return "Holy" end
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tabIndex = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if name and SPEC_SPELLBOOK_NAMES[name] then
                    return SPEC_SPELLBOOK_NAMES[name]
                end
            end
        end
    end
    return nil
end

local SPEC_SPELL_NAMES = {
    ["Righteous Fury"] = "Protection", ["Holy Shield"] = "Protection",
    ["Avenger's Shield"] = "Protection", ["Shield of Righteousness"] = "Protection",
    ["Hammer of the Righteous"] = "Protection",
    ["Holy Shock"] = "Holy", ["Beacon of Light"] = "Holy", ["Light's Grace"] = "Holy",
    ["Crusader Strike"] = "Retribution", ["Divine Storm"] = "Retribution",
    ["Repentance"] = "Retribution", ["Seal of Command"] = "Retribution",
}
SPEC_SPELL_NAMES["Праведный гнев"] = "Protection"
SPEC_SPELL_NAMES["Святой щит"] = "Protection"
SPEC_SPELL_NAMES["Щит правосудия"] = "Protection"
SPEC_SPELL_NAMES["Молот праведности"] = "Protection"
SPEC_SPELL_NAMES["Молния Света"] = "Holy"
SPEC_SPELL_NAMES["Маяк Света"] = "Holy"
SPEC_SPELL_NAMES["Благодать Света"] = "Holy"
SPEC_SPELL_NAMES["Удар крестоносца"] = "Retribution"
SPEC_SPELL_NAMES["Божественная буря"] = "Retribution"
SPEC_SPELL_NAMES["Покаяние"] = "Retribution"
SPEC_SPELL_NAMES["Печать повеления"] = "Retribution"

local function ScanUnitForSpecAuras(unit)
    for i = 1, 40 do
        local name = UnitBuff(unit, i); if not name then break end
        if SPEC_SPELL_NAMES[name] then return SPEC_SPELL_NAMES[name] end
    end
    for i = 1, 40 do
        local name = UnitDebuff(unit, i); if not name then break end
        if SPEC_SPELL_NAMES[name] then return SPEC_SPELL_NAMES[name] end
    end
    return nil
end

local function SpecFromLibName(treeOrName)
    if not treeOrName then return nil end
    if type(treeOrName) == "number" then
        if treeOrName == 1 then return "Holy" end
        if treeOrName == 2 then return "Protection" end
        if treeOrName == 3 then return "Retribution" end
        return nil
    end
    local s = string.lower(tostring(treeOrName))
    if s == "holy" or s == "свет" then return "Holy" end
    if s == "protection" or s == "защита" then return "Protection" end
    if s == "retribution" or s == "воздаяние" then return "Retribution" end
    return nil
end

local function GetSpecFromLib(unit)
    if not LibGroupTalents then return nil end
    local ok, tree = pcall(function() return LibGroupTalents:GetUnitTalentSpec(unit) end)
    if not ok then return nil end
    return SpecFromLibName(tree)
end

local function GetSpecForUnit(unit)
    if unit == "player" then
        return ScanSpellbookForSpec()
            or GetPlayerSpecViaTalents()
            or GetSpecFromLib(unit)
            or ScanUnitForSpecAuras(unit)
    end
    return GetSpecFromLib(unit) or ScanUnitForSpecAuras(unit)
end

-- ==================== SAVED VARIABLES ====================
local DEFAULTS = {
    version = 1, enabled = true, groupOnly = false, minimal = false,
    menuDirection = "right", buffNameMode = "full", announceNameMode = "short",
    announceChannel = "auto",
    width = 220, height = 32, spacing = 4, scale = 1.0,
    barAlpha = 0.85, menuAlpha = 0.90, locked = true,
    point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
}

-- ==================== STATE ====================
PBA.paladins = {}
PBA.assignments = {}
PBA.specCache = {}
PBA._debugInspect = false
PBA._lastRosterHash = nil
local gearFrame = nil
local menuFrame = nil
local announceBtn = nil
local inspectQueue = {}
local _currentInspect = nil

local REINSPECT_INTERVAL = 15
local MAX_ATTEMPTS = 10

-- ==================== INSPECT RANGE ====================
local function IsInspectable(unit)
    if not UnitExists(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if CanInspect then
        local ok, res = pcall(CanInspect, unit)
        if ok and res == false then return false end
    end
    if CheckInteractDistance then
        local ok, res = pcall(CheckInteractDistance, unit, 4)
        if ok and res == false then return false end
    end
    return true
end

-- ==================== SPEC CACHE ====================
local function CacheSpec(unit, spec)
    if not spec then return end
    local guid = UnitGUID(unit)
    if guid then PBA.specCache[guid] = spec end
end

local function GetCachedSpec(unit)
    local guid = UnitGUID(unit)
    return guid and PBA.specCache[guid] or nil
end

-- ==================== ROSTER ====================
local function ApplySpec(name, spec)
    if not spec then return false end
    local p = PBA.paladins[name]
    if not p then return false end
    local changed = (p.spec ~= spec)
    p.spec = spec
    CacheSpec(p.unit, spec)

    if spec ~= "Protection" then
        if PBA.assignments["proto"] == name then
            PBA.assignments["proto"] = nil
            p.buffs["proto"] = nil
            changed = true
        end
        if PBA.db and PBA.db.assignments and PBA.db.assignments["proto"] == name then
            PBA.db.assignments["proto"] = nil
            changed = true
        end
    elseif not PBA.assignments["proto"]
        and PBA.db and PBA.db.assignments and PBA.db.assignments["proto"] == name then
        p.buffs["proto"] = true
        PBA.assignments["proto"] = name
        changed = true
    end
    return changed
end

function PBA:UpdateRoster()
    local units = {}
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            local _, class = UnitClass(unit)
            if class == "PALADIN" and UnitIsConnected(unit) then units[#units + 1] = unit end
        end
    elseif GetNumPartyMembers() > 0 then
        local _, pclass = UnitClass("player")
        if pclass == "PALADIN" then units[#units + 1] = "player" end
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local _, class = UnitClass(unit)
            if class == "PALADIN" and UnitIsConnected(unit) then units[#units + 1] = unit end
        end
    else
        local _, pclass = UnitClass("player")
        if pclass == "PALADIN" then units[#units + 1] = "player" end
    end

    local parts = {}
    for _, unit in ipairs(units) do parts[#parts + 1] = UnitGUID(unit) or "?" end
    local hash = table.concat(parts, ";")

    local knownCount = 0
    for _ in pairs(PBA.paladins) do knownCount = knownCount + 1 end

    if hash == PBA._lastRosterHash and #units == knownCount then
        local allKnown = true
        for _, unit in ipairs(units) do
            local name = UnitName(unit)
            local p = name and PBA.paladins[name]
            if not p or not p.spec then allKnown = false; break end
        end
        if allKnown then return end
    end
    PBA._lastRosterHash = hash

    local seen = {}
    for _, unit in ipairs(units) do
        local name = UnitName(unit)
        if name then
            seen[name] = true
            local existing = PBA.paladins[name]
            local spec = GetSpecForUnit(unit)
                or (existing and existing.spec)
                or GetCachedSpec(unit)

            if not existing then
                PBA.paladins[name] = { unit = unit, spec = spec, buffs = {} }
            else
                existing.unit = unit
                if spec then existing.spec = spec end
            end
            if spec then CacheSpec(unit, spec) end
        end
    end

    for name in pairs(PBA.paladins) do
        if not seen[name] then PBA.paladins[name] = nil end
    end

    for _, p in pairs(PBA.paladins) do p.buffs = {} end
    wipe(PBA.assignments)
    local d = PBA.db
    if d then
        for buffKey, pname in pairs(d.assignments or {}) do
            local p = PBA.paladins[pname]
            if p then
                if buffKey == "proto" then
                    if p.spec == "Protection" then
                        p.buffs[buffKey] = true
                        PBA.assignments[buffKey] = pname
                    elseif p.spec then
                        d.assignments[buffKey] = nil
                    end
                else
                    p.buffs[buffKey] = true
                    PBA.assignments[buffKey] = pname
                end
            end
        end
    end

    local needed = {}
    for _, p in pairs(PBA.paladins) do
        if p.unit ~= "player" and not p.spec then needed[p.unit] = true end
    end
    for unit in pairs(inspectQueue) do
        if not needed[unit] and not inspectQueue[unit].recheck then
            inspectQueue[unit] = nil
        end
    end
    for unit in pairs(needed) do
        if not inspectQueue[unit] then inspectQueue[unit] = { attempts = 0 } end
    end

    PBA:RebuildBars()
    PBA:ApplyFrameSettings()
    PBA:UpdateAnnounceButton()
    PBA:UpdateGearVisibility()
end

-- ==================== LIBGROUPTALENTS CALLBACK ====================
if LibGroupTalents then
    pcall(function()
        LibGroupTalents:RegisterCallback("LibGroupTalents_Update",
            function(owner, guid, unit, newSpec)
                local name = unit and UnitName(unit)
                if not name then
                    for pname, p in pairs(PBA.paladins) do
                        if UnitGUID(p.unit) == guid then name = pname; break end
                    end
                end
                if not name then return end
                local spec = SpecFromLibName(newSpec)
                if spec and ApplySpec(name, spec) then
                    PBA:RebuildBars()
                end
            end)
    end)
end

-- ==================== PERIODIC RESCAN (только player) ====================
local specRescanT = 0
local specRescanFrame = CreateFrame("Frame")
specRescanFrame:SetScript("OnUpdate", function(self, el)
    if not PBA.db or not PBA.db.enabled then return end
    specRescanT = specRescanT + el
    if specRescanT < 5 then return end
    specRescanT = 0
    local changed = false
    for name, p in pairs(PBA.paladins) do
        if p.unit == "player" then
            local spec = ScanSpellbookForSpec() or GetPlayerSpecViaTalents()
            if spec and ApplySpec(name, spec) then changed = true end
        end
    end
    if changed then PBA:RebuildBars() end
end)

-- ==================== DIRECT INSPECT FALLBACK ====================
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_TALENT_READY")
pcall(function() inspectFrame:RegisterEvent("INSPECT_READY") end)

local function ResolveInspectedUnit(arg1)
    if type(arg1) == "string" and #arg1 > 0 then
        if arg1:match("^party%d") or arg1:match("^raid%d") or arg1 == "player" then
            return arg1
        end
        if #arg1 >= 10 then
            for _, p in pairs(PBA.paladins) do
                if UnitGUID(p.unit) == arg1 then return p.unit end
            end
            if GetNumRaidMembers and GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do
                    local u = "raid" .. i
                    if UnitExists(u) and UnitGUID(u) == arg1 then return u end
                end
            elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
                if UnitExists("player") and UnitGUID("player") == arg1 then return "player" end
                for i = 1, GetNumPartyMembers() do
                    local u = "party" .. i
                    if UnitExists(u) and UnitGUID(u) == arg1 then return u end
                end
            end
            return nil
        end
        return nil
    end
    if _currentInspect then return _currentInspect.unit end
    return nil
end

local function TryProcessInspectedUnit(unit)
    if not unit then return false end
    local name = UnitName(unit)
    if not name then return false end
    local spec, pts, group = GetInspectedSpec()
    local pal = PBA.paladins[name]

    if PBA._debugInspect then
        local ptxt = pts and (pts[1] .. "/" .. pts[2] .. "/" .. pts[3]) or "0/0/0"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00AAFFPBA inspect|r " .. name
            .. " pts=" .. ptxt .. " group=" .. tostring(group)
            .. " old=" .. tostring(pal and pal.spec))
    end

    if not spec then return false end

    if pal then
        local oldSpec = pal.spec
        local oldPoints = pal.lastPoints
        local pointsChanged = (not oldPoints)
            or oldPoints[1] ~= pts[1] or oldPoints[2] ~= pts[2] or oldPoints[3] ~= pts[3]

        pal.lastPoints = pts
        pal.lastInspect = GetTime()
        local specChanged = ApplySpec(name, spec)

        if specChanged and PBA._debugInspect then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00PBA spec CHANGE|r " .. name
                .. ": " .. tostring(oldSpec) .. " -> " .. spec)
        end

        if specChanged or pointsChanged then
            PBA:RebuildBars()
        end
    end

    inspectQueue[unit] = nil
    return true
end

inspectFrame:SetScript("OnEvent", function(self, event, arg1)
    local unit = ResolveInspectedUnit(arg1)
    if not unit then return end

    if not arg1 and _currentInspect and _currentInspect.unit == unit then
        if not IsInspectable(unit) then return end
    end

    local ok = TryProcessInspectedUnit(unit)

    if _currentInspect and _currentInspect.unit == unit then
        if ok then
            _currentInspect = nil
        else
            inspectQueue[unit] = nil
            _currentInspect = nil
        end
    end
end)

local inspectTimer = 0
inspectFrame:SetScript("OnUpdate", function(self, el)
    if not PBA.db or not PBA.db.enabled then return end

    if _currentInspect then
        local age = GetTime() - _currentInspect.requestedAt
        if age > 10 then
            inspectQueue[_currentInspect.unit] = nil
            _currentInspect = nil
        else
            return
        end
    end

    inspectTimer = inspectTimer + el
    if inspectTimer < 4.0 then return end
    inspectTimer = 0

    for unit, info in pairs(inspectQueue) do
        local name = UnitName(unit)
        local p = name and PBA.paladins[name]
        if not p then
            inspectQueue[unit] = nil
        elseif not info.recheck and p.spec then
            inspectQueue[unit] = nil
        elseif info.attempts >= MAX_ATTEMPTS then
            inspectQueue[unit] = nil
        elseif not IsInspectable(unit) then
            if PBA._debugInspect and not info._rangeLogged then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFAA00PBA|r " .. tostring(name)
                    .. " out of inspect range, will retry when in range")
                info._rangeLogged = true
            end
        else
            info._rangeLogged = false
            info.attempts = info.attempts + 1
            _currentInspect = { unit = unit, requestedAt = GetTime() }
            if type(ClearInspectPlayer) == "function" then
                pcall(ClearInspectPlayer)
            end
            NotifyInspect(unit)
            return
        end
    end
end)

-- ==================== PERIODIC RE-INSPECT ====================
local reinspectTimer = 0
local reinspectFrame = CreateFrame("Frame")
reinspectFrame:SetScript("OnUpdate", function(self, el)
    if not PBA.db or not PBA.db.enabled then return end
    reinspectTimer = reinspectTimer + el
    if reinspectTimer < REINSPECT_INTERVAL then return end
    reinspectTimer = 0
    local now = GetTime()
    for name, p in pairs(PBA.paladins) do
        if p.unit ~= "player" then
            local lastT = p.lastInspect or 0
            if (now - lastT) > REINSPECT_INTERVAL then
                if not inspectQueue[p.unit] then
                    inspectQueue[p.unit] = { attempts = 0, recheck = true }
                end
            end
        end
    end
end)

-- ==================== ASSIGNMENT LOGIC ====================
function PBA:IsBuffAvailable(buffKey, paladinName)
    if buffKey == "proto" then
        local p = paladinName and PBA.paladins[paladinName]
        return (p and p.spec == "Protection") and true or false
    end
    return true
end

function PBA:GetAssignableBuffs(forPaladinName)
    local result = {}
    for _, buff in ipairs(BUFF_POOL) do
        if self:IsBuffAvailable(buff.key, forPaladinName) then
            local owner = PBA.assignments[buff.key]
            if not owner or owner == forPaladinName then result[#result + 1] = buff.key end
        end
    end
    return result
end

function PBA:HasBuff(paladinName, buffKey)
    local p = PBA.paladins[paladinName]
    return p and p.buffs[buffKey] == true
end

function PBA:AssignBuff(paladinName, buffKey)
    local p = PBA.paladins[paladinName]
    if not p or not self:IsBuffAvailable(buffKey, paladinName) then return end
    if p.buffs[buffKey] then
        PBA.assignments[buffKey] = nil; p.buffs[buffKey] = nil
        if PBA.db.assignments then PBA.db.assignments[buffKey] = nil end
        PBA:RebuildBars(); PBA:UpdateAnnounceButton(); return
    end
    local prevOwner = PBA.assignments[buffKey]
    if prevOwner and prevOwner ~= paladinName and PBA.paladins[prevOwner] then
        PBA.paladins[prevOwner].buffs[buffKey] = nil
    end
    p.buffs[buffKey] = true
    PBA.assignments[buffKey] = paladinName
    if PBA.db then
        PBA.db.assignments = PBA.db.assignments or {}
        PBA.db.assignments[buffKey] = paladinName
    end
    PBA:RebuildBars(); PBA:UpdateAnnounceButton()
end

function PBA:UnassignBuff(paladinName, buffKey)
    local p = PBA.paladins[paladinName]
    if not p or not p.buffs[buffKey] then return end
    PBA.assignments[buffKey] = nil; p.buffs[buffKey] = nil
    if PBA.db.assignments then PBA.db.assignments[buffKey] = nil end
    PBA:RebuildBars(); PBA:UpdateAnnounceButton()
end

function PBA:UnassignAllBuffs(paladinName)
    local p = PBA.paladins[paladinName]; if not p then return end
    for _, bk in ipairs(PBA:GetPaladinBuffs(paladinName)) do
        PBA.assignments[bk] = nil; p.buffs[bk] = nil
        if PBA.db.assignments then PBA.db.assignments[bk] = nil end
    end
    PBA:RebuildBars(); PBA:UpdateAnnounceButton()
end

function PBA:AnyBuffAssigned()
    for _, p in pairs(PBA.paladins) do
        if p.buffs and next(p.buffs) then return true end
    end
    return false
end

function PBA:GetAssignedPaladin(buffKey) return PBA.assignments[buffKey] end

function PBA:GetPaladinBuffs(paladinName)
    local p = PBA.paladins[paladinName]; if not p then return {} end
    local r = {}
    for k, v in pairs(p.buffs) do if v then r[#r + 1] = k end end
    return r
end

function PBA:FormatBuffName(buffKey, mode)
    if mode == "icon" then return "" end
    if mode == "short" then return BUFF_SHORT[buffKey] or buffKey end
    return BUFF_DISPLAY[buffKey] or buffKey
end

function PBA:GetBuffIcon(buffKey)
    for _, b in ipairs(BUFF_POOL) do if b.key == buffKey then return b.icon end end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function PBA:FormatBuffNameAnnounce(buffKey)
    local mode = PBA.db.announceNameMode or "short"
    if mode == "short" then return BUFF_SHORT[buffKey] or buffKey end
    return BUFF_DISPLAY[buffKey] or buffKey
end

function PBA:GetSpecName(spec)
    if spec == "Protection" then return L.specProt end
    if spec == "Holy" then return L.specHoly end
    if spec == "Retribution" then return L.specRet end
    return L.specUnknown
end

function PBA:GetSpecIcon(spec)
    if spec == "Holy" then return "Interface\\Icons\\Spell_Holy_HolyBolt" end
    if spec == "Protection" then return "Interface\\Icons\\Spell_Holy_DevotionAura" end
    if spec == "Retribution" then return "Interface\\Icons\\Spell_Holy_AuraOfLight" end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ==================== ANNOUNCE ====================

local function IsPlayerRaidLeaderOrAssistant()
    if not GetNumRaidMembers or GetNumRaidMembers() == 0 then
        return false
    end
    if IsRaidLeader then
        local ok, res = pcall(IsRaidLeader)
        if ok and (res == 1 or res == true) then return true end
    end
    if IsRaidOfficer then
        local ok, res = pcall(IsRaidOfficer)
        if ok and (res == 1 or res == true) then return true end
    end
    local myName = UnitName("player")
    if myName and GetRaidRosterInfo then
        for i = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name == myName and rank and rank >= 1 then
                return true
            end
        end
    end
    if UnitIsGroupLeader then
        local ok, res = pcall(UnitIsGroupLeader, "player")
        if ok and (res == 1 or res == true) then return true end
    end
    if UnitIsGroupAssistant then
        local ok, res = pcall(UnitIsGroupAssistant, "player")
        if ok and (res == 1 or res == true) then return true end
    end
    return false
end

-- Одиночный | в тексте — escape-префикс WoW, из-за него SendChatMessage
-- бросает "Invalid escape code". Заменяем на '!', если встретился.
local function SanitizeLine(s)
    if not s then return s end
    return (s:gsub("|([^cCrHh])", "!%1"))
end

function PBA:BuildAnnounceLines()
    local entries = {}
    for name in pairs(PBA.paladins) do
        local buffs = {}
        for _, buffKey in ipairs(BUFF_KEY_ORDER) do
            if self:IsBuffAvailable(buffKey, name) and PBA.assignments[buffKey] == name then
                buffs[#buffs + 1] = PBA:FormatBuffNameAnnounce(buffKey)
            end
        end
        if #buffs > 0 then
            entries[#entries + 1] = { name = name, text = table.concat(buffs, ", ") }
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    local lines = {}
    for _, entry in ipairs(entries) do
        local line = string.format(L.assignedTo, entry.name, entry.text)
        lines[#lines + 1] = SanitizeLine(line)
    end
    return lines
end

function PBA:Announce()
    if not self:AnyBuffAssigned() then return end

    local lines = self:BuildAnnounceLines()
    if #lines == 0 then return end

    local inRaid  = (GetNumRaidMembers()  > 0) or UnitExists("raid1")
    local inParty = (GetNumPartyMembers() > 0) or UnitExists("party1")
    local channelPref = (self.db and self.db.announceChannel) or "auto"

    if not inRaid and not inParty then
        for _, line in ipairs(lines) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: " .. line)
        end
        return
    end

    if channelPref == "local" then
        for _, line in ipairs(lines) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: " .. line)
        end
        return
    end

    -- RAID_WARNING — если возможно и включено/авто.
    if inRaid and IsPlayerRaidLeaderOrAssistant()
        and (channelPref == "rw" or channelPref == "auto") then
        -- Отправляем ВСЕ строки сразу, без задержки, каждая — на своей строке.
        for _, line in ipairs(lines) do
            SendChatMessage(line, "RAID_WARNING")
        end
        return
    end

    -- RAID / PARTY — все строки сразу.
    local channel = inRaid and "RAID" or "PARTY"
    for _, line in ipairs(lines) do
        SendChatMessage(line, channel)
    end
end

function PBA:AnnounceTest()
    local lines = self:BuildAnnounceLines()
    if #lines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r announcetest: buffs not assigned")
        return
    end
    local inRaid  = (GetNumRaidMembers()  > 0) or UnitExists("raid1")
    local inParty = (GetNumPartyMembers() > 0) or UnitExists("party1")
    local canRW = IsPlayerRaidLeaderOrAssistant()
    local pref = (self.db and self.db.announceChannel) or "auto"

    DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r announcetest:")
    DEFAULT_CHAT_FRAME:AddMessage("  inRaid=" .. tostring(inRaid)
        .. " inParty=" .. tostring(inParty)
        .. " canRW=" .. tostring(canRW)
        .. " pref=" .. pref
        .. " lines=" .. #lines)

    local plan
    if pref == "local" then
        plan = "local chat (forced)"
    elseif inRaid then
        local useRW = canRW and (pref == "rw" or pref == "auto")
        if useRW then plan = "RAID_WARNING, " .. #lines .. " lines instantly"
        else plan = "RAID, " .. #lines .. " lines instantly" end
    elseif inParty then
        plan = "PARTY, " .. #lines .. " lines instantly"
    else
        plan = "local chat"
    end
    DEFAULT_CHAT_FRAME:AddMessage("  channel: " .. plan)

    for i, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] (" .. #line .. "b) " .. line)
    end
end

-- ==================== GEAR FRAME ====================
function PBA:CreateGearFrame()
    if gearFrame then return end
    local d = PBA.db
    local gf = CreateFrame("Button", addonName .. "Gear", UIParent)
    gf:SetWidth(36); gf:SetHeight(36)
    gf:SetFrameStrata("DIALOG"); gf:EnableMouse(true)
    gf:RegisterForDrag("LeftButton"); gf:SetMovable(true)
    gf:SetPoint(d.point or "CENTER", UIParent, d.relPoint or "CENTER", d.x or 0, d.y or 0)
    local tex = gf:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(gf)
    tex:SetTexture("Interface\\Icons\\INV_Gizmo_GnomishUniversalRemote"); gf.tex = tex
    gf:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 1, 0, 1) end)
    gf:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1, 1) end)
    gf:SetScript("OnClick", function(self) PBA:ToggleBars() end)
    gf:SetScript("OnDragStart", function(f) if not d.locked then f:StartMoving() end end)
    gf:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        d.point = point or "CENTER"; d.relPoint = relPoint or "CENTER"
        d.x = x or 0; d.y = y or 0
    end)
    gearFrame = gf
    PBA:UpdateGearVisibility()
end

function PBA:UpdateGearVisibility()
    local d = PBA.db; if not d or not gearFrame then return end
    if d.minimal then gearFrame:Show() else gearFrame:Hide() end
end

function PBA:ToggleBars()
    if not PBA.main then return end
    if PBA.main:IsShown() then PBA.main:Hide()
    else PBA:RebuildBars(); PBA.main:Show() end
    PBA:UpdateAnnounceButton()
end

-- ==================== INIT ====================
function PBA:InitDB()
    local d = PaladinBuffAssignDB
    if type(d) ~= "table" then d = {} end
    if d.version ~= DEFAULTS.version then
        local pt, rp, px, py = d.point, d.relPoint, d.x, d.y
        local savedAssign = d.assignments
        wipe(d)
        for k, v in pairs(DEFAULTS) do d[k] = v end
        d.point = pt or DEFAULTS.point; d.relPoint = rp or DEFAULTS.relPoint
        d.x = px or DEFAULTS.x; d.y = py or DEFAULTS.y
        d.version = DEFAULTS.version
        if type(savedAssign) == "table" then d.assignments = savedAssign end
    end
    for k, v in pairs(DEFAULTS) do if d[k] == nil then d[k] = v end end
    if type(d.assignments) ~= "table" then d.assignments = {} end
    PaladinBuffAssignDB = d
    PBA.db = d
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
pcall(function() eventFrame:RegisterEvent("UNIT_CONNECTION") end)
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        PBA:InitDB()
        PBA:CreateMain()
        PBA:CreateGearFrame()
        PBA:UpdateRoster()
        PBA:UpdateAnnounceButton()
        PBA:UpdateGearVisibility()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: " .. L.loaded)
        return
    end
    if not PBA.db or not PBA.db.enabled then return end
    if event == "PLAYER_ENTERING_WORLD" then
        PBA._lastRosterHash = nil
        PBA._rosterPending = true
        return
    end
    if event == "UNIT_CONNECTION" then
        if type(arg1) == "string" and
           (arg1:match("^party%d") or arg1:match("^raid%d")) then
            PBA._rosterPending = true
        end
        return
    end
    if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        PBA._rosterPending = true
    end
end)

local delayT = 0
local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function(self, el)
    if not PBA._rosterPending then return end
    delayT = delayT + el
    if delayT < 2 then return end
    delayT = 0; PBA._rosterPending = false
    PBA:UpdateRoster()
end)

SLASH_PALADINBUFFASSIGN1 = "/pba"
SlashCmdList["PALADINBUFFASSIGN"] = function(msg)
    msg = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if not PBA.db then return end
    if msg == "lock" then
        PBA.db.locked = true; PBA:ApplyFrameSettings()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: " .. L.locked)
    elseif msg == "unlock" then
        PBA.db.locked = false; PBA:ApplyFrameSettings()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: unlocked")
    elseif msg == "reset" then
        PaladinBuffAssignDB = nil; ReloadUI()
    elseif msg == "announce" then
        PBA:Announce()
    elseif msg == "announcetest" then
        PBA:AnnounceTest()
    elseif msg == "whoami" then
        local inRaid = (GetNumRaidMembers() or 0) > 0
        local inParty = (GetNumPartyMembers() or 0) > 0
        local isLeader, isOfficer = false, false
        if IsRaidLeader then
            local ok, res = pcall(IsRaidLeader)
            if ok and (res == 1 or res == true) then isLeader = true end
        end
        if IsRaidOfficer then
            local ok, res = pcall(IsRaidOfficer)
            if ok and (res == 1 or res == true) then isOfficer = true end
        end
        local rank = 0
        local myName = UnitName("player")
        if inRaid and GetRaidRosterInfo and myName then
            for i = 1, GetNumRaidMembers() do
                local n, r = GetRaidRosterInfo(i)
                if n == myName then rank = r or 0; break end
            end
        end
        local canRW = IsPlayerRaidLeaderOrAssistant()
        local willUse = "local chat"
        if inRaid then
            willUse = canRW and "RAID_WARNING (/rw)" or "RAID (/raid)"
        elseif inParty then
            willUse = "PARTY"
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r whoami:")
        DEFAULT_CHAT_FRAME:AddMessage("  raid=" .. tostring(inRaid)
            .. " party=" .. tostring(inParty)
            .. " IsRaidLeader=" .. tostring(isLeader)
            .. " IsRaidOfficer=" .. tostring(isOfficer)
            .. " rosterRank=" .. tostring(rank))
        DEFAULT_CHAT_FRAME:AddMessage("  Can use RAID_WARNING: " .. tostring(canRW))
        DEFAULT_CHAT_FRAME:AddMessage("  Channel preference: " .. tostring(PBA.db.announceChannel))
        DEFAULT_CHAT_FRAME:AddMessage("  Next announce channel: " .. willUse)
    elseif msg == "inspectdebug" then
        PBA._debugInspect = not PBA._debugInspect
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r inspect debug: "
            .. tostring(PBA._debugInspect))
    elseif msg == "refresh" then
        wipe(PBA.specCache)
        PBA._lastRosterHash = nil
        _currentInspect = nil
        if type(ClearInspectPlayer) == "function" then
            pcall(ClearInspectPlayer)
        end
        for _, p in pairs(PBA.paladins) do
            if p.unit ~= "player" then
                p.spec = nil
                p.lastInspect = nil
                p.lastPoints = nil
                inspectQueue[p.unit] = { attempts = 0, recheck = true }
            end
        end
        PBA:RebuildBars()
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. addonName .. "|r: spec cache cleared, re-inspecting")
    elseif msg == "debug" then
        local f = DEFAULT_CHAT_FRAME.AddMessage
        f(DEFAULT_CHAT_FRAME, "|cffFF7D0A" .. addonName .. "|r debug:")
        f(DEFAULT_CHAT_FRAME, "  LibStub: " .. (LibStub and "OK" or "MISSING"))
        f(DEFAULT_CHAT_FRAME, "  LibTalentQuery-1.0: " .. (LibTalentQuery and "OK" or "MISSING"))
        f(DEFAULT_CHAT_FRAME, "  LibGroupTalents-1.0: " .. (LibGroupTalents and "OK" or "MISSING"))
        f(DEFAULT_CHAT_FRAME, "  announceChannel: " .. tostring(PBA.db.announceChannel))
        local qcount = 0
        for _ in pairs(inspectQueue) do qcount = qcount + 1 end
        local ccache = 0
        for _ in pairs(PBA.specCache) do ccache = ccache + 1 end
        f(DEFAULT_CHAT_FRAME, "  inspect queue: " .. qcount
            .. "  current: " .. (_currentInspect and _currentInspect.unit or "nil")
            .. "  specCache: " .. ccache)
        for name, p in pairs(PBA.paladins) do
            f(DEFAULT_CHAT_FRAME, "  " .. name .. " (" .. tostring(p.unit) .. ") → "
                .. tostring(p.spec))
        end
    else
        PBA:ToggleConfig()
    end
end