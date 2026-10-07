-- PaTiRota: settings modal (built on first open, when the DB exists). Ten skill slots in priority order, edited with
-- PaTiShared's slot list (UI.AddSlotList: type or drag spells, arrows and grip to sort — the same in every addon).
-- Slot changes in combat are saved at once; the secure buttons follow after combat (PaTiRota.lua applySlots).
local _, ns = ...
local UI, L, Logic, Spells = ns.UI, ns.UI.L, ns.Logic, ns.Spells

local Settings = {}
ns.Settings = Settings

local app -- { db, window, say, slotsChanged, restored } from PaTiRota.lua
function Settings.Init(callbacks) app = callbacks end

local modal

local function setSlot(slot, id)
    Logic.SetSlot(app.db().slots, slot, id)
    app.slotsChanged()
end

local function moveTo(from, to)
    if Logic.MoveTo(app.db().slots, from, to) then app.slotsChanged() end
end

local function build()
    local DB, window = app.db(), app.window
    modal = UI.CreateModal("PaTiRotaSettings", function() return "PaTiRota " .. L.SETTINGS end, 440)
    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 170))
    local scales = {}
    for _, scale in ipairs(Logic.SCALES) do
        scales[#scales + 1] = { value = scale, text = function() return ("%d %%"):format(scale * 100 + 0.5) end }
    end
    modal:AddRow("SCALE", UI.CreateDropdown(modal, 170, {
        items = function() return scales end,
        get = function() return DB.scale end,
        set = function(scale)
            DB.scale = scale
            if InCombatLockdown() then app.say("APPLY_AFTER_COMBAT") else window:SetScale(scale) end
        end,
    }))
    modal:AddControls(UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }), UI.CreateCheckbox(modal, "COOLDOWN_CLOCK", { -- display only: no secure change, fine in combat
        get = function() return DB.cooldownClock end,
        set = function(on) DB.cooldownClock = on; app.repaint() end,
    }))
    modal:AddSection("SKILLS")
    UI.AddSlotList(modal, {
        count = Logic.SLOTS,
        title = "SKILLS_TITLE",
        help = { { "SKILLS_HELP_PRIORITY_KEY", "SKILLS_HELP_PRIORITY" } },
        get = function() return app.db().slots end,
        set = setSlot,
        moveTo = moveTo,
        name = Spells.Name,
        icon = Spells.Icon,
        resolve = Spells.Resolve,
        fromCursor = Spells.FromCursor,
        notFound = function(text) app.say("SPELL_NOT_FOUND", text) end,
    })
    modal.cursor = modal.cursor - UI.Spacing.MD
    -- Below the list (owner wish 2026-10-04): key bindings, one entry per slot.
    modal:AddNote("KEYBIND_TITLE", "KEYBIND_PATH", "KEYBIND_TEXT", 2)
    UI.AddWindowSettings(modal, window) -- panel opacity (PaTiShared)
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        app.restored()
    end)
end

function Settings.Open()
    if not modal then build() end
    modal:Show()
end
