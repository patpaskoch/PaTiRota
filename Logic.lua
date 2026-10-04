-- PaTiRota: settings, slot order, cooldown states and the recommendation — no WoW API calls (tests/logic_spec.lua).
-- The recommendation is a display only: the highest-priority slot that is ready. It never casts anything; every slot
-- has its own fixed secure button whose spell changes only out of combat (PaTiRota.lua).
local _, ns = ...
local Logic = {}
ns.Logic = Logic

Logic.SCHEMA = 1
Logic.SLOTS = 10 -- configurable skill slots; order = your priority (slot 1 first)
Logic.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 }
-- Without a readable global cooldown reference, a cooldown this short counts as the global cooldown (classic GCD
-- is 1.5 s; shorter with haste). Only used as the fallback (docs/WOW_API_COMPAT.md).
Logic.GCD_MAX = 1.5

-- Position (point, relativePoint, x, y) is written by the PaTiShared window, not listed here.
Logic.DEFAULTS = {
    opacity = 0.75, -- panel body opacity (PaTiShared window; 0.3–1)
    theme = "default", -- "default" | "woforever" | "dracula" (PaTiShared UI.THEMES; colours only)
    locked = false,
    collapsed = false,
    scale = 1,
    language = "auto",
    cooldownClock = true, -- WoW's cooldown clock on each skill icon (Blizzard widget; also when the values are secret)
}

local function validSlot(value)
    return type(value) == "number" and value >= 0 and value == math.floor(value)
end

-- Fills missing values, keeps existing ones (also false). slots: Logic.SLOTS spell IDs, 0 = empty; anything broken
-- becomes empty, a spell that appears twice keeps only its first (highest-priority) slot.
function Logic.Migrate(db)
    if type(db) ~= "table" then db = {} end
    for key, value in pairs(Logic.DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- A broken scale would make SetScale fail on login: only a sane number is kept (saved values elsewhere stay).
    if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = Logic.DEFAULTS.scale end
    -- Theme: one of the three PaTiShared themes; a typo or an old value falls back to the default look.
    if db.theme ~= "default" and db.theme ~= "woforever" and db.theme ~= "dracula" then db.theme = "default" end
    local old, slots, seen = type(db.slots) == "table" and db.slots or {}, {}, {}
    for index = 1, Logic.SLOTS do
        local id = validSlot(old[index]) and old[index] or 0
        if id ~= 0 and seen[id] then id = 0 end
        seen[id] = true
        slots[index] = id
    end
    db.slots = slots
    db.schema = Logic.SCHEMA
    return db
end

-- "Restore Defaults": settings back; position and your skill slots are kept (there are no default skills, so wiping
-- them would only lose your setup — clear a slot by emptying it).
function Logic.RestoreDefaults(db)
    for key, value in pairs(Logic.DEFAULTS) do db[key] = value end
    return db
end

-- Puts spell `id` (0 = empty) into slot `index`. A spell is in at most one slot: if it was in another slot, that
-- slot gets what `index` had before (the two swap).
function Logic.SetSlot(slots, index, id)
    if id ~= 0 then
        for other, value in ipairs(slots) do
            if value == id and other ~= index then slots[other] = slots[index] end
        end
    end
    slots[index] = id
    return slots
end

-- Moves slot `index` one up (delta -1) or down (+1) by swapping with its neighbour. Returns true if it moved.
function Logic.Move(slots, index, delta)
    local target = index + delta
    if target < 1 or target > #slots then return false end
    slots[index], slots[target] = slots[target], slots[index]
    return true
end

-- Moves the spell in slot `from` to slot `to` (drag and drop); the slots in between shift by one, so the order of
-- all others stays. Returns true if it moved.
function Logic.MoveTo(slots, from, to)
    if from == to or not slots[from] or not slots[to] then return false end
    table.insert(slots, to, table.remove(slots, from))
    return true
end

-- The slots with a spell, in priority order: { { slot, id } }.
function Logic.Filled(slots)
    local list = {}
    for index, id in ipairs(slots) do
        if id ~= 0 then list[#list + 1] = { slot = index, id = id } end
    end
    return list
end

-- Secret-value rule (AGENTS.md §8): check readability FIRST, compare or calculate only afterwards.

-- raw (from the API adapter): { known, start, duration, usable } of one spell; gcd: { start, duration } of the
-- global cooldown reference or nil. now = GetTime(). Returns { state, remaining? }:
--   NOT_KNOWN   you have not learned the spell (or the client does not know the ID)
--   UNKNOWN     cooldown not readable (secret / missing API) — never a recommendation
--   UNUSABLE    WoW says it cannot be used now (e.g. not enough mana)
--   COOLDOWN    on its own cooldown, `remaining` seconds left
--   GCD         only the global cooldown runs: it is ready as soon as the GCD ends
--   READY       ready now
function Logic.CooldownState(raw, gcd, now, isSecret)
    if raw.known ~= true then return { state = "NOT_KNOWN" } end
    local start, duration = raw.start, raw.duration
    if isSecret(start) or isSecret(duration) or type(start) ~= "number" or type(duration) ~= "number" then
        -- secret: WoW answered but keeps the values secret (e.g. in combat) — shown differently from "no API".
        return { state = "UNKNOWN", secret = raw.secret == true }
    end
    local usable = raw.usable
    if not isSecret(usable) and usable == false then return { state = "UNUSABLE" } end
    if start <= 0 or duration <= 0 then return { state = "READY" } end
    local remaining = start + duration - now
    if remaining <= 0 then return { state = "READY" } end
    local gcdStart, gcdDuration = gcd and gcd.start, gcd and gcd.duration
    local gcdReadable = type(gcdStart) == "number" and type(gcdDuration) == "number"
        and not isSecret(gcdStart) and not isSecret(gcdDuration) and gcdDuration > 0
    if gcdReadable then
        -- Same start and length as the GCD reference: only the global cooldown, not the spell's own one.
        if math.abs(start - gcdStart) < 0.05 and math.abs(duration - gcdDuration) < 0.05 then
            return { state = "GCD", remaining = remaining }
        end
    elseif duration <= Logic.GCD_MAX then
        return { state = "GCD", remaining = remaining }
    end
    return { state = "COOLDOWN", remaining = remaining }
end

-- states: CooldownState results in priority order. Returns the index to highlight and whether it is ready:
--   the first READY or GCD one (the GCD runs for every spell alike, so it never makes the pick jump down the list);
--   otherwise the COOLDOWN one that is ready soonest (`waiting` = true); nil if none is readable.
function Logic.Recommend(states)
    local soonest, soonestRemaining
    for index, result in ipairs(states) do
        if result.state == "READY" or result.state == "GCD" then return index, false end
        if result.state == "COOLDOWN" and (not soonestRemaining or result.remaining < soonestRemaining) then
            soonest, soonestRemaining = index, result.remaining
        end
    end
    return soonest, soonest ~= nil
end

-- The secure attributes of one slot button: a fixed spell (left click and key binding) or nothing. Set out of
-- combat only; in combat a button keeps what it had (one click = exactly that spell, never another one).
function Logic.SlotAttributes(castName)
    return { type1 = castName and "spell" or nil, spell1 = castName }
end
Logic.SLOT_ATTRIBUTES = { "type1", "spell1" }

-- Remaining time as text: "3.2" below 10 s, whole seconds below a minute, then "2m".
function Logic.FormatRemaining(seconds)
    if seconds < 10 then return ("%.1f"):format(seconds) end
    if seconds < 60 then return ("%d"):format(math.floor(seconds + 0.5)) end
    return ("%dm"):format(math.floor(seconds / 60 + 0.5))
end

-- Test mode: fake states for the example skills (TEST_SKILLS in PaTiRota.lua), in slot order.
Logic.TEST_STATES = {
    { state = "READY" }, { state = "COOLDOWN", remaining = 3.2 }, { state = "COOLDOWN", remaining = 6.8 },
    { state = "READY" },
}

-- Cooldown sources (owner-observed 2026-10-03: in combat the old adapter turned every known skill UNKNOWN) --------
-- It took C_Spell.GetSpellCooldown's table as soon as one came back, also with unreadable values, and never asked
-- GetSpellCooldown. Now every source is checked for readability first and the first readable one wins.

local function readable(value, isSecret)
    if isSecret(value) then return false end
    return type(value) == "number"
end

-- A yes/no hint the client may add to its cooldown info; nil when absent, secret or not a boolean.
local function hint(value, isSecret)
    if isSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

-- modern(id) → { startTime, duration, isActive?, isOnGCD? } (C_Spell.GetSpellCooldown) or nil when the API is
-- missing; legacy(id) → start, duration (GetSpellCooldown) or nil when missing. Both are called through pcall.
-- Returns { start, duration, source = "modern" | "legacy" | nil, secret, active, onGCD, diag }:
--   start/duration only from a source whose two values are readable numbers (never a secret value);
--   secret = a source answered but kept a value secret; active/onGCD = readable booleans of the modern info;
--   diag = per source { api, ok, start, duration } with "readable" | "secret" | "missing" (for /prota debug).
function Logic.ReadCooldown(modern, legacy, id, isSecret)
    local result = { secret = false, diag = { modern = { api = modern ~= nil }, legacy = { api = legacy ~= nil } } }
    local function judge(diag, start, duration)
        diag.start = isSecret(start) and "secret" or (readable(start, isSecret) and "readable" or "missing")
        diag.duration = isSecret(duration) and "secret" or (readable(duration, isSecret) and "readable" or "missing")
        if diag.start == "secret" or diag.duration == "secret" then result.secret = true end
        return diag.start == "readable" and diag.duration == "readable"
    end
    if modern then
        local ok, info = pcall(modern, id)
        local diag = result.diag.modern
        diag.ok = ok
        if ok and not isSecret(info) and type(info) == "table" then
            result.active, result.onGCD = hint(info.isActive, isSecret), hint(info.isOnGCD, isSecret)
            if judge(diag, info.startTime, info.duration) then
                result.start, result.duration, result.source = info.startTime, info.duration, "modern"
                return result
            end
        elseif ok then
            if isSecret(info) then result.secret = true end
            diag.start, diag.duration = "missing", "missing"
        end
    end
    if legacy then
        local ok, start, duration = pcall(legacy, id)
        local diag = result.diag.legacy
        diag.ok = ok
        if ok and judge(diag, start, duration) then
            result.start, result.duration, result.source = start, duration, "legacy"
            return result
        end
    end
    return result
end

-- Grey icon? Not learned / not usable: always. With WoW's cooldown clock on the icon (owner wish 2026-10-03) the
-- clock's dark swipe shows "cooling down" and disappears when the time is up — so the icon stays in colour and is
-- "lit" again exactly when the cooldown ends, also when the values are secret. Without a clock: grey unless ready.
function Logic.IconGrey(state, clocked)
    if state == "NOT_KNOWN" or state == "UNUSABLE" then return true end
    if clocked then return false end
    return state ~= "READY" and state ~= "GCD"
end
