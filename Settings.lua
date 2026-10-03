-- PaTiRota: settings modal (built on first open, when the DB exists). Ten skill slots in priority order: type a
-- spell name or ID (Enter), or drag a spell from your spellbook onto the slot; Up/Down change the order.
-- Slot changes in combat are saved at once; the secure buttons follow after combat (PaTiRota.lua applySlots).
local _, ns = ...
local UI, L, Logic, Spells = ns.UI, ns.UI.L, ns.Logic, ns.Spells

local Settings = {}
ns.Settings = Settings

local app -- { db, window, say, slotsChanged, restored } from PaTiRota.lua
function Settings.Init(callbacks) app = callbacks end

local modal
local slotRows = {}

local EDIT_WIDTH, MOVE_WIDTH, ICON = 170, 56, 18

local function slotText(id)
    if id == 0 then return "" end
    return Spells.Name(id) or tostring(id)
end

local function refreshSlots()
    local DB = app.db()
    for slot, row in ipairs(slotRows) do
        local id = DB.slots[slot]
        if not row.edit:HasFocus() then row.edit:SetText(slotText(id)) end
        row.icon:SetTexture(id ~= 0 and Spells.Icon(id) or nil)
        row.up:SetEnabled(slot > 1)
        row.down:SetEnabled(slot < Logic.SLOTS)
    end
end

local function setSlot(slot, id)
    Logic.SetSlot(app.db().slots, slot, id)
    refreshSlots()
    app.slotsChanged()
end

local function move(slot, delta)
    if Logic.Move(app.db().slots, slot, delta) then
        refreshSlots()
        app.slotsChanged()
    end
end

-- A spell dropped from the spellbook onto the slot.
local function receiveDrag(slot)
    local id = Spells.FromCursor()
    if not id then return end
    if ClearCursor then ClearCursor() end
    setSlot(slot, id)
end

-- One slot row: [icon][spell name or ID ……][Up][Down]. Enter applies, Escape restores, empty + Enter clears.
local function slotRow(parent, slot)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ICON + UI.Spacing.SM + EDIT_WIDTH + 2 * (MOVE_WIDTH + UI.Spacing.XS), UI.Sizes.ButtonHeight)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT")
    local edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    edit:SetSize(EDIT_WIDTH, UI.Sizes.ButtonHeight)
    edit:SetPoint("LEFT", row.icon, "RIGHT", UI.Spacing.SM, 0)
    edit:SetAutoFocus(false)
    edit:SetFontObject(UI.Fonts.Text)
    edit:SetTextInsets(UI.Spacing.SM + 2, UI.Spacing.SM, 0, 0)
    UI.ApplyBackdrop(edit, "Panel", "Border")
    edit:SetScript("OnEnterPressed", function(self)
        local id = Spells.Resolve(self:GetText())
        self:ClearFocus()
        if id then setSlot(slot, id) else app.say("SPELL_NOT_FOUND", self:GetText()); refreshSlots() end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshSlots() end)
    edit:SetScript("OnReceiveDrag", function() receiveDrag(slot) end)
    edit:SetScript("OnMouseDown", function() if GetCursorInfo and GetCursorInfo() == "spell" then receiveDrag(slot) end end)
    row.edit = edit
    row.down = UI.CreateButton(row, "MOVE_DOWN", MOVE_WIDTH, function() move(slot, 1) end)
    row.down:SetPoint("RIGHT")
    row.up = UI.CreateButton(row, "MOVE_UP", MOVE_WIDTH, function() move(slot, -1) end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -UI.Spacing.XS, 0)
    UI.SetTooltip(edit, function() return { L.SLOT:format(slot), L.SLOT_TIP } end)
    return row
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
    modal:AddNote("SKILLS_TITLE", "KEYBIND_PATH", "SKILLS_TEXT", 4) -- key bindings: own entry per slot
    for slot = 1, Logic.SLOTS do
        slotRows[slot] = slotRow(modal, slot)
        modal:AddRow(function() return L.SLOT:format(slot) end, slotRows[slot])
    end
    UI.AddWindowSettings(modal, window) -- panel opacity (PaTiShared)
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        app.restored()
    end)
    modal:HookScript("OnShow", refreshSlots)
end

function Settings.Open()
    if not modal then build() end
    modal:Show()
end
