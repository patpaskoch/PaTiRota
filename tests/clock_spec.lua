-- PaTiRota cooldown clock (Spells.ShowCooldownClock): WoW's values go straight into a Blizzard Cooldown widget,
-- also when they are secret — PaTiRota never touches them. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local function trap() error("a secret value was used by PaTiRota") end
local SECRET = setmetatable({}, { __add = trap, __sub = trap, __lt = trap, __le = trap, __concat = trap,
    __tostring = trap, __eq = trap, __unm = trap })

local function load()
    wow.install()
    _G.issecretvalue = function(value) return rawequal(value, SECRET) end
    local ns = {}
    wow.loadAddonFile("Logic.lua", ns)
    wow.loadAddonFile("SpellBook.lua", ns)
    return ns.Spells
end

local function widget(opts)
    opts = opts or {}
    local w = { calls = {} }
    function w:SetCooldown(start, duration)
        if opts.refuse then error("refused") end
        self.calls[#self.calls + 1] = { "SetCooldown", start, duration }
    end
    function w:Clear() self.calls[#self.calls + 1] = { "Clear" } end
    if opts.durationObject then
        function w:SetCooldownFromDurationObject(object) self.calls[#self.calls + 1] = { "DurationObject", object } end
    end
    return w
end

local function cleanup() _G.C_Spell, _G.issecretvalue = nil, nil end

describe("Spells.ShowCooldownClock", function()

    it("hands secret start/duration to the widget untouched (no comparison, no arithmetic)", function()
        local Spells = load()
        _G.C_Spell = { GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET } end }
        local w = widget()
        assert.equal("SetCooldown", Spells.ShowCooldownClock(w, 403))
        assert.truthy(rawequal(w.calls[1][2], SECRET) and rawequal(w.calls[1][3], SECRET))
        cleanup()
    end)

    it("prefers WoW's duration object when the client and the widget support it", function()
        local Spells = load()
        local object = {}
        _G.C_Spell = { GetSpellCooldownDuration = function() return object end,
            GetSpellCooldown = function() return { startTime = 1, duration = 2 } end }
        local w = widget({ durationObject = true })
        assert.equal("duration object", Spells.ShowCooldownClock(w, 403))
        assert.truthy(rawequal(w.calls[1][2], object))
        cleanup()
    end)

    it("a refused widget call or a missing API never errors: the clock is cleared", function()
        local Spells = load()
        _G.C_Spell = { GetSpellCooldown = function() return { startTime = SECRET, duration = SECRET } end }
        local w = widget({ refuse = true })
        assert.is_nil(Spells.ShowCooldownClock(w, 403))
        assert.equal("Clear", w.calls[#w.calls][1])
        assert.matches("refused", Spells.lastError)
        _G.C_Spell = nil
        local plain = widget()
        assert.is_nil(Spells.ShowCooldownClock(plain, 403))
        assert.same({ { "Clear" } }, plain.calls)
        cleanup()
    end)

    it("a whole secret info table is not indexed: the clock is cleared", function()
        local Spells = load()
        _G.C_Spell = { GetSpellCooldown = function() return SECRET end }
        local w = widget()
        assert.is_nil(Spells.ShowCooldownClock(w, 403))
        cleanup()
    end)
end)

describe("Setting cooldownClock", function()
    it("on by default; a saved false stays false", function()
        local Logic = wow.loadAddonFile("Logic.lua", {}).Logic
        assert.is_true(Logic.Migrate(nil).cooldownClock)
        assert.is_false(Logic.Migrate({ cooldownClock = false }).cooldownClock)
    end)
end)
