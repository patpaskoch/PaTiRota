-- PaTiRota cooldown sources (owner-observed 2026-10-03: in combat every known skill turned "unclear").
-- Logic.ReadCooldown with injected API functions; secret values are a marker table that must never be compared,
-- calculated with or turned into text before isSecret says no. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Logic.lua", {}).Logic
end

-- A secret value: any arithmetic, comparison, concatenation or tostring on it raises an error.
local function trap() error("a secret value was used before isSecret was checked") end
local SECRET = setmetatable({}, { __add = trap, __sub = trap, __lt = trap, __le = trap, __concat = trap,
    __tostring = trap, __eq = trap, __unm = trap })
local function isSecret(value) return rawequal(value, SECRET) end

local ID, NOW = 403, 100
local function modernReturns(start, duration, extra)
    return function()
        local info = { startTime = start, duration = duration }
        for key, value in pairs(extra or {}) do info[key] = value end
        return info
    end
end
local function legacyReturns(start, duration) return function() return start, duration end end
local function failing() error("API failure") end

describe("Logic.ReadCooldown: the first readable source wins", function()
    it("1. modern readable → modern", function()
        local r = load().ReadCooldown(modernReturns(98, 8), legacyReturns(1, 1), ID, isSecret)
        assert.same({ "modern", 98, 8, false }, { r.source, r.start, r.duration, r.secret })
    end)

    it("2. modern API missing, legacy readable → legacy", function()
        local r = load().ReadCooldown(nil, legacyReturns(97, 6), ID, isSecret)
        assert.same({ "legacy", 97, 6 }, { r.source, r.start, r.duration })
        assert.is_false(r.diag.modern.api)
    end)

    it("3. modern call fails, legacy readable → legacy", function()
        local r = load().ReadCooldown(failing, legacyReturns(97, 6), ID, isSecret)
        assert.equal("legacy", r.source)
        assert.is_false(r.diag.modern.ok)
    end)

    it("4. modern start secret, legacy readable → legacy (the old adapter stopped at modern)", function()
        local r = load().ReadCooldown(modernReturns(SECRET, 8), legacyReturns(97, 6), ID, isSecret)
        assert.same({ "legacy", 97, 6 }, { r.source, r.start, r.duration })
        assert.same({ "secret", "readable" }, { r.diag.modern.start, r.diag.modern.duration })
        assert.is_true(r.secret)
    end)

    it("5. modern duration secret, legacy readable → legacy", function()
        local r = load().ReadCooldown(modernReturns(98, SECRET), legacyReturns(97, 6), ID, isSecret)
        assert.equal("legacy", r.source)
        assert.equal("secret", r.diag.modern.duration)
    end)

    it("6. modern and legacy secret → no readable cooldown, flagged secret, never a secret value handed on", function()
        local r = load().ReadCooldown(modernReturns(SECRET, SECRET), legacyReturns(SECRET, SECRET), ID, isSecret)
        assert.is_nil(r.source)
        assert.is_nil(r.start)
        assert.is_nil(r.duration)
        assert.is_true(r.secret)
        assert.same({ "secret", "secret" }, { r.diag.legacy.start, r.diag.legacy.duration })
    end)

    it("7. modern unreadable type, legacy readable → legacy; a whole secret info table counts as secret", function()
        local Logic = load()
        assert.equal("legacy", Logic.ReadCooldown(modernReturns("x", {}), legacyReturns(97, 6), ID, isSecret).source)
        assert.equal("legacy", Logic.ReadCooldown(function() return "nope" end, legacyReturns(97, 6), ID, isSecret).source)
        local r = Logic.ReadCooldown(function() return SECRET end, nil, ID, isSecret)
        assert.is_nil(r.source)
        assert.is_true(r.secret)
    end)

    it("8. no API at all → no source, not secret (\"unclear\", not \"unreadable in combat\")", function()
        local r = load().ReadCooldown(nil, nil, ID, isSecret)
        assert.is_nil(r.source)
        assert.is_false(r.secret)
        assert.is_false(r.diag.legacy.api)
    end)

    it("readable isActive/isOnGCD hints are reported; secret ones are dropped (debug only, never decide)", function()
        local Logic = load()
        local r = Logic.ReadCooldown(modernReturns(SECRET, SECRET, { isActive = true, isOnGCD = false }), nil, ID,
            isSecret)
        assert.same({ true, false }, { r.active, r.onGCD })
        r = Logic.ReadCooldown(modernReturns(SECRET, SECRET, { isActive = SECRET }), nil, ID, isSecret)
        assert.is_nil(r.active)
        assert.equal("UNKNOWN", Logic.CooldownState({ known = true, start = r.start, duration = r.duration,
            secret = r.secret }, nil, NOW, isSecret).state)
    end)
end)

describe("CooldownState with the read result", function()
    it("9. GCD reference unreadable, a readable short cooldown → the safe GCD fallback", function()
        local Logic = load()
        local gcd = Logic.ReadCooldown(modernReturns(SECRET, SECRET), legacyReturns(SECRET, SECRET), 61304, isSecret)
        local spell = Logic.ReadCooldown(modernReturns(SECRET, SECRET), legacyReturns(99.5, 1.5), ID, isSecret)
        local state = Logic.CooldownState({ known = true, start = spell.start, duration = spell.duration },
            { start = gcd.start, duration = gcd.duration }, NOW, isSecret)
        assert.equal("GCD", state.state)
    end)

    it("10. a secret result is UNKNOWN + secret without any operation on the secret value", function()
        local Logic = load()
        local state = Logic.CooldownState({ known = true, start = SECRET, duration = SECRET, secret = true,
            usable = SECRET }, { start = SECRET, duration = SECRET }, NOW, isSecret)
        assert.same({ "UNKNOWN", true }, { state.state, state.secret })
        local plain = Logic.CooldownState({ known = true }, nil, NOW, isSecret)
        assert.same({ "UNKNOWN", false }, { plain.state, plain.secret })
    end)

    it("11. UNKNOWN (also secret) is never recommended as ready", function()
        local Logic = load()
        local index = Logic.Recommend({ { state = "UNKNOWN", secret = true }, { state = "UNKNOWN" } })
        assert.is_nil(index)
        assert.equal(2, (Logic.Recommend({ { state = "UNKNOWN", secret = true }, { state = "READY" } })))
    end)

    it("12. the fixed slot attributes do not depend on any cooldown read", function()
        local Logic = load()
        local before = Logic.SlotAttributes("Blitzschlag")
        Logic.ReadCooldown(modernReturns(SECRET, SECRET), legacyReturns(SECRET, SECRET), ID, isSecret)
        assert.same({ type1 = "spell", spell1 = "Blitzschlag" }, before)
        assert.same(before, Logic.SlotAttributes("Blitzschlag"))
    end)
end)
