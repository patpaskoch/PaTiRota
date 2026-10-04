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

local EDIT_WIDTH, MOVE_WIDTH, ICON = 170, 28, 18
local CHEVRON = 6 -- arm length of the up/down chevron (same drawing as the PaTiShared dropdown arrow)
local GRIP, GRIP_LINES, GRIP_GAP = 16, 3, 4 -- drag grip: three short lines, 4 px apart

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

-- Up/Down as a chevron instead of text (owner wish 2026-10-04); the word stays in the tooltip. Muted while disabled
-- (slot 1 cannot go up, slot 10 not down).
local function moveButton(parent, key, up, onClick)
    local button = UI.CreateButton(parent, nil, MOVE_WIDTH, onClick)
    local arrow = CreateFrame("Frame", nil, button)
    arrow:SetSize(12, 12)
    arrow:SetPoint("CENTER")
    local sign = up and 1 or -1
    local lines = { UI.Line(arrow, CHEVRON, 45 * sign, -2, 0), UI.Line(arrow, CHEVRON, -45 * sign, 2, 0) }
    local function paint()
        for _, line in ipairs(lines) do line:SetColorTexture(UI.Color(button:IsEnabled() and "Text" or "TextMuted")) end
    end
    button:HookScript("OnEnable", paint)
    button:HookScript("OnDisable", paint)
    UI.OnThemeChanged(paint)
    paint()
    UI.SetTooltip(button, key)
    return button
end

-- Reorder by dragging a slot's icon onto another slot (owner wish 2026-10-04). Plain frames, settings only: the secure
-- buttons follow through app.slotsChanged like any other slot change. The row under the mouse is lit while dragging.
local dragFrom

local function rowUnderMouse()
    for slot, row in ipairs(slotRows) do
        if row:IsMouseOver() then return slot end
    end
    return nil
end

local function showDropTarget()
    local target = rowUnderMouse()
    for slot, row in ipairs(slotRows) do row.drop:SetShown(slot == target and slot ~= dragFrom) end
end

local function endDrag(drop)
    if not dragFrom then return end
    local from, target = dragFrom, drop and rowUnderMouse()
    dragFrom = nil
    for _, row in ipairs(slotRows) do
        row.handle:SetScript("OnUpdate", nil)
        row.grip:SetScript("OnUpdate", nil)
        row.drop:Hide()
        row:SetAlpha(1)
    end
    if target and Logic.MoveTo(app.db().slots, from, target) then
        refreshSlots()
        app.slotsChanged()
    end
end

-- Makes `handle` start a drag of this slot (the icon and the grip both do).
local function makeDraggable(handle, row, slot)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function(self)
        if app.db().slots[slot] == 0 then return end -- an empty slot has nothing to move
        dragFrom = slot
        row:SetAlpha(0.5)
        self:SetScript("OnUpdate", showDropTarget) -- only while dragging; removed in endDrag
    end)
    handle:SetScript("OnDragStop", function() endDrag(true) end)
    UI.SetTooltip(handle, function() return app.db().slots[slot] ~= 0 and L.DRAG_TIP or nil end)
    return handle
end

-- The grip at the end of a row (owner wish 2026-10-04: an own symbol for dragging): ≡ drawn from lines.
local function gripButton(row, slot)
    local grip = CreateFrame("Button", nil, row)
    grip:SetSize(GRIP, UI.Sizes.ButtonHeight)
    local lines = {}
    for index = 1, GRIP_LINES do
        lines[index] = UI.Line(grip, GRIP - 4, 0, 0, (index - (GRIP_LINES + 1) / 2) * GRIP_GAP)
    end
    local function paint(hovered)
        for _, line in ipairs(lines) do line:SetColorTexture(UI.Color(hovered and "Text" or "TextMuted")) end
    end
    grip:SetScript("OnEnter", function() paint(true) end)
    grip:SetScript("OnLeave", function() paint(false) end)
    UI.OnThemeChanged(function() paint(grip:IsMouseOver()) end)
    paint(false)
    return makeDraggable(grip, row, slot)
end

-- One slot row: [icon][spell name or ID ……][^][v][≡]. Enter applies, Escape restores, empty + Enter clears.
local function slotRow(parent, slot)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ICON + UI.Spacing.SM + EDIT_WIDTH + 2 * (MOVE_WIDTH + UI.Spacing.XS) + UI.Spacing.XS + GRIP,
        UI.Sizes.ButtonHeight)
    row.drop = row:CreateTexture(nil, "BACKGROUND")
    row.drop:SetPoint("TOPLEFT", -UI.Spacing.XS, UI.Spacing.XS)
    row.drop:SetPoint("BOTTOMRIGHT", UI.Spacing.XS, -UI.Spacing.XS)
    UI.Paint(row.drop, "SetColorTexture", "Accent", 0.25)
    row.drop:Hide()
    row.handle = CreateFrame("Button", nil, row)
    row.handle:SetSize(ICON, ICON)
    row.handle:SetPoint("LEFT")
    makeDraggable(row.handle, row, slot)
    row.icon = row.handle:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
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
    row.down = moveButton(row, "MOVE_DOWN", false, function() move(slot, 1) end)
    row.grip = gripButton(row, slot)
    row.grip:SetPoint("RIGHT")
    row.down:SetPoint("RIGHT", row.grip, "LEFT", -UI.Spacing.XS, 0)
    row.up = moveButton(row, "MOVE_UP", true, function() move(slot, -1) end)
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
    modal:AddNote("SKILLS_TITLE", nil, "SKILLS_TEXT", 4) -- above the list: how to fill a slot
    modal.cursor = modal.cursor - UI.Spacing.MD -- breathing room between the note and the list (owner wish 2026-10-04)
    for slot = 1, Logic.SLOTS do
        slotRows[slot] = slotRow(modal, slot)
        modal:AddRow(function() return L.SLOT:format(slot) end, slotRows[slot])
    end
    modal.cursor = modal.cursor - UI.Spacing.MD
    -- Below the list (owner wish 2026-10-04): key bindings, one entry per slot.
    modal:AddNote("KEYBIND_TITLE", "KEYBIND_PATH", "KEYBIND_TEXT", 2)
    UI.AddWindowSettings(modal, window) -- panel opacity (PaTiShared)
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        app.restored()
    end)
    modal:HookScript("OnShow", refreshSlots)
    modal:HookScript("OnHide", function() endDrag(false) end) -- closed mid-drag: nothing moves
end

function Settings.Open()
    if not modal then build() end
    modal:Show()
end
