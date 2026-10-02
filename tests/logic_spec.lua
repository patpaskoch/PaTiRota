-- PaTiRota: settings, slot order, cooldown states, recommendation, fixed secure attributes. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function load()
    return wow.loadAddonFile("Logic.lua", {}).Logic
end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local function isSecret(value) return value == SECRET end
local NOW = 100

local function slots(list)
    local result = {}
    for index = 1, 10 do result[index] = list[index] or 0 end
    return result
end

describe("Logic.Migrate / RestoreDefaults (PaTiRotaDB)", function()
    it("a new character gets defaults, ten empty slots and schema 1", function()
        local db = load().Migrate(nil)
        assert.same({ 0.75, false, false, 1, "auto", 1 },
            { db.opacity, db.locked, db.collapsed, db.scale, db.language, db.schema })
        assert.same(slots({}), db.slots)
    end)

    it("keeps saved values (also false), the position and the slots", function()
        local db = load().Migrate({ locked = true, collapsed = true, scale = 1.25, point = "TOP", x = 4,
            slots = { 17364, 8050, 0, 60103 } })
        assert.same({ true, true, 1.25, "TOP", 4 }, { db.locked, db.collapsed, db.scale, db.point, db.x })
        assert.same(slots({ 17364, 8050, 0, 60103 }), db.slots)
    end)

    it("repairs broken slots: non-numbers, negatives, fractions and duplicates become empty", function()
        local db = load().Migrate({ slots = { "x", -3, 1.5, 8050, 8050, 403 } })
        assert.same(slots({ 0, 0, 0, 8050, 0, 403 }), db.slots)
        assert.same(slots({}), load().Migrate({ slots = "broken" }).slots)
        assert.equal(1, load().Migrate("broken").schema)
    end)

    it("Restore Defaults: settings back, slots and position kept", function()
        local db = load().RestoreDefaults({ locked = true, scale = 1.5, point = "TOP", slots = slots({ 8050 }) })
        assert.same({ false, 1, "TOP", 8050 }, { db.locked, db.scale, db.point, db.slots[1] })
    end)
end)

describe("Slot order (priority)", function()
    it("SetSlot puts a spell in; a spell already in another slot swaps with it (never twice)", function()
        local Logic = load()
        local list = slots({ 1, 2, 3 })
        Logic.SetSlot(list, 1, 3)
        assert.same(slots({ 3, 2, 1 }), list)
        Logic.SetSlot(list, 5, 2)
        assert.same(slots({ 3, 0, 1, 0, 2 }), list)
        Logic.SetSlot(list, 1, 0) -- clear
        assert.same(slots({ 0, 0, 1, 0, 2 }), list)
    end)

    it("Move swaps with the neighbour; not past the first or last slot", function()
        local Logic = load()
        local list = slots({ 1, 2, 3 })
        assert.is_true(Logic.Move(list, 2, -1))
        assert.same(slots({ 2, 1, 3 }), list)
        assert.is_true(Logic.Move(list, 2, 1))
        assert.same(slots({ 2, 3, 1 }), list)
        assert.is_false(Logic.Move(list, 1, -1))
        assert.is_false(Logic.Move(list, 10, 1))
    end)

    it("Filled lists the configured slots in priority order, gaps skipped", function()
        assert.same({ { slot = 1, id = 9 }, { slot = 4, id = 7 } }, load().Filled(slots({ 9, 0, 0, 7 })))
        assert.same({}, load().Filled(slots({})))
    end)
end)

describe("Logic.CooldownState (cooldown read adapter → state)", function()
    local function state(raw, gcd) return load().CooldownState(raw, gcd, NOW, isSecret) end

    it("unknown spell → NOT_KNOWN; unreadable cooldown → UNKNOWN (never a false READY)", function()
        assert.equal("NOT_KNOWN", state({ known = false, start = 0, duration = 0 }).state)
        assert.equal("UNKNOWN", state({ known = true, start = SECRET, duration = 8 }).state)
        assert.equal("UNKNOWN", state({ known = true, start = 90, duration = SECRET }).state)
        assert.equal("UNKNOWN", state({ known = true }).state) -- no API answered
    end)

    it("no cooldown or an expired one → READY", function()
        assert.equal("READY", state({ known = true, start = 0, duration = 0 }).state)
        assert.equal("READY", state({ known = true, start = 80, duration = 10 }).state)
    end)

    it("own cooldown → COOLDOWN with the remaining seconds", function()
        local result = state({ known = true, start = 98, duration = 8 }, { start = 99, duration = 1.5 })
        assert.equal("COOLDOWN", result.state)
        assert.equal(6, result.remaining)
    end)

    it("GCD: same start and length as the global cooldown reference", function()
        local result = state({ known = true, start = 99.5, duration = 1.5 }, { start = 99.5, duration = 1.5 })
        assert.equal("GCD", result.state)
        assert.equal(1, result.remaining)
    end)

    it("GCD without a readable reference: a cooldown up to 1.5 s counts as GCD, a longer one as COOLDOWN", function()
        assert.equal("GCD", state({ known = true, start = 99.5, duration = 1.5 }, { start = SECRET }).state)
        assert.equal("GCD", state({ known = true, start = 99.5, duration = 1.0 }, nil).state)
        assert.equal("COOLDOWN", state({ known = true, start = 99.5, duration = 6 }, nil).state)
    end)

    it("not usable (WoW says so) → UNUSABLE; an unreadable usable flag is ignored", function()
        assert.equal("UNUSABLE", state({ known = true, start = 0, duration = 0, usable = false }).state)
        assert.equal("READY", state({ known = true, start = 0, duration = 0, usable = SECRET }).state)
        assert.equal("READY", state({ known = true, start = 0, duration = 0, usable = nil }).state)
    end)
end)

describe("Logic.Recommend (next skill)", function()
    local Logic = load()
    local READY, GCD = { state = "READY" }, { state = "GCD", remaining = 1 }
    local function cd(seconds) return { state = "COOLDOWN", remaining = seconds } end

    it("the highest-priority ready skill wins", function()
        assert.same({ 2, false }, { Logic.Recommend({ cd(5), READY, READY }) })
    end)

    it("during the GCD the pick does not jump: GCD counts like ready, slot order decides", function()
        assert.same({ 1, false }, { Logic.Recommend({ GCD, GCD, READY }) })
        assert.same({ 2, false }, { Logic.Recommend({ cd(4), GCD, GCD }) })
    end)

    it("nothing ready: the cooldown that ends first, marked as waiting", function()
        assert.same({ 3, true }, { Logic.Recommend({ cd(6.8), cd(3.2), cd(1.1) }) })
    end)

    it("unknown, unusable and not learned are never recommended", function()
        assert.same({ 3, false }, { Logic.Recommend({ { state = "UNKNOWN" }, { state = "UNUSABLE" }, READY }) })
        local index, waiting = Logic.Recommend({ { state = "UNKNOWN" }, { state = "NOT_KNOWN" } })
        assert.is_nil(index)
        assert.is_false(waiting)
        assert.is_nil((Logic.Recommend({})))
    end)

    it("test mode data recommends slot 1", function()
        assert.equal(1, (Logic.Recommend(Logic.TEST_STATES)))
    end)
end)

describe("Fixed secure attributes (never a self-changing cast button)", function()
    it("one fixed spell per slot button, or nothing", function()
        local Logic = load()
        assert.same({ type1 = "spell", spell1 = "Sturmschlag" }, Logic.SlotAttributes("Sturmschlag"))
        assert.same({}, Logic.SlotAttributes(nil)) -- empty / unknown slot: the button casts nothing
        assert.same({ "type1", "spell1" }, Logic.SLOT_ATTRIBUTES)
    end)

    it("the attributes depend only on the slot's own spell, not on the recommendation", function()
        local Logic = load()
        local before = Logic.SlotAttributes("Flammenschock")
        Logic.Recommend({ { state = "READY" }, { state = "COOLDOWN", remaining = 2 } })
        assert.same(before, Logic.SlotAttributes("Flammenschock"))
    end)
end)

describe("Logic.FormatRemaining", function()
    it("tenths below 10 s, seconds below a minute, then minutes", function()
        local Logic = load()
        assert.equal("3.2", Logic.FormatRemaining(3.24))
        assert.equal("12", Logic.FormatRemaining(12.4))
        assert.equal("2m", Logic.FormatRemaining(118))
    end)
end)
