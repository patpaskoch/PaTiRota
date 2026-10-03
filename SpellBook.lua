-- PaTiRota: spell, spellbook and cooldown adapters. Spell part = deliberate small copy of PaTiHeal/SpellBook.lua
-- (addons stay independent; fix bugs in both). All API calls live here and are guarded, because Interface 16001 may
-- offer modern (C_Spell/C_SpellBook) or classic APIs (docs/WOW_API_COMPAT.md). Values go out raw: Logic checks them.
local _, ns = ...
local Spells = {}
ns.Spells = Spells

-- Spell 61304 is the "global cooldown" reference spell of modern clients; if this client does not know it,
-- Logic.CooldownState falls back to Logic.GCD_MAX.
Spells.GCD_SPELL = 61304

local families = {} -- spell name -> true, from the spellbook (higher ranks have other IDs)

function Spells.Name(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    return GetSpellInfo and GetSpellInfo(id)
end

function Spells.Icon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture and GetSpellTexture(id)
end

function Spells.IsKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    elseif C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id) == nil then
        return false
    end
    local name = Spells.Name(id)
    return name ~= nil and families[name] == true
end

-- Learned spell names from the spellbook, modern API first, classic API as fallback.
local function spellbookNames()
    local names = {}
    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank then
        for line = 1, book.GetNumSpellBookSkillLines() do
            local info = book.GetSpellBookSkillLineInfo(line)
            for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = book.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
                if item and item.name then names[item.name] = true end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for index = offset + 1, offset + count do
                local name = GetSpellBookItemName(index, "spell")
                if name then names[name] = true end
            end
        end
    end
    return names
end

-- Call on login and SPELLS_CHANGED. Returns false if no spellbook API worked.
function Spells.Rescan()
    local ok, names = pcall(spellbookNames)
    families = ok and names or {}
    return ok and next(families) ~= nil
end

-- Name for the secure `spell` attribute: the plain name = your highest known rank.
function Spells.CastName(id)
    return Spells.Name(id)
end

-- What the player typed in a slot (a name or an ID) → spell ID; "" → 0 (empty slot); nil if nothing matches.
-- A name only resolves for spells the client knows by that name (usually the ones you learned).
function Spells.Resolve(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return 0 end
    local id = tonumber(text)
    if id then return Spells.Name(id) and id or nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(text)
        return info and info.spellID
    end
    if GetSpellInfo then return (select(7, GetSpellInfo(text))) end
    return nil
end

-- The spell on the mouse cursor (dragged from the spellbook onto a settings slot), or nil.
function Spells.FromCursor()
    if not GetCursorInfo then return nil end
    local kind, index, bookType, spellID = GetCursorInfo()
    if kind ~= "spell" then return nil end
    if type(spellID) == "number" then return spellID end -- modern clients: the 4th value
    if type(index) ~= "number" then return nil end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        local item = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
        return item and item.spellID
    end
    if GetSpellBookItemInfo then
        local _, id = GetSpellBookItemInfo(index, bookType)
        return id
    end
    return nil
end

-- Cooldown of one spell as raw values (start, duration in seconds; may be secret): modern C_Spell first, then the
-- classic GetSpellCooldown. nil, nil if neither answers. Never errors.
function Spells.Cooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then return info.startTime, info.duration end
        if not ok then Spells.lastError = tostring(info):sub(1, 120) end -- /prota debug only
    end
    if GetSpellCooldown then
        local ok, start, duration = pcall(GetSpellCooldown, id)
        if ok then return start, duration end
        Spells.lastError = tostring(start):sub(1, 120)
    end
    return nil, nil
end

-- Usable now (mana, form …) as WoW reports it: true / false / nil (unknown). Never errors.
function Spells.Usable(id)
    local fn = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not fn then return nil end
    local ok, usable = pcall(fn, id)
    if not ok then Spells.lastError = tostring(usable):sub(1, 120); return nil end
    if issecretvalue and issecretvalue(usable) then return usable end -- Logic treats it as unknown
    return usable == true or usable == 1 -- classic IsUsableSpell answers 1 / nil
end

-- Which cooldown API answers (for /prota debug).
function Spells.CooldownApi()
    if C_Spell and C_Spell.GetSpellCooldown then return "C_Spell.GetSpellCooldown" end
    return GetSpellCooldown and "GetSpellCooldown" or "none"
end
