-- PaTiRota: your own skill priority. Shows which configured skill is ready next and when the others come back.
-- It never casts by itself: every slot has its own fixed secure button (PaTiRotaSlot1..10) with exactly one spell,
-- set out of combat only. The highlight moves, the buttons and their spells do not.
local addonName, ns = ...
local UI, L, Logic, Spells = ns.UI, ns.UI.L, ns.Logic, ns.Spells

local DB
local testMode = false
local slotsPending = false -- slot changes in combat wait for PLAYER_REGEN_ENABLED

local WIDTH, ROW, ICON, ROW_GAP = 240, 28, 22, 2
local PAD = UI.Spacing.MD
local NEXT_LINE = 18
local TICK_SECONDS = 0.1 -- cooldown texts; only while a shown skill is cooling down
local TEST_SKILLS = { "TEST_SKILL_1", "TEST_SKILL_2", "TEST_SKILL_3", "TEST_SKILL_4" }
local TEST_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function say(key, ...)
    print("|cff68caffPaTiRota:|r " .. L[key]:format(...))
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(addonName, "Version") or "?"
end

-- Key bindings (Bindings.xml): one entry per slot, shown in WoW's key binding menu. Nothing is bound automatically.
local G = _G
G.BINDING_HEADER_PATIROTA = "PaTiRota"
for slot = 1, Logic.SLOTS do
    G["BINDING_NAME_CLICK PaTiRotaSlot" .. slot .. ":LeftButton"] = L.BINDING_SLOT:format(slot)
end

-- Window and slot buttons ----------------------------------------------------------------------

local window = UI.CreateWindow("PaTiRotaFrame", "PaTiRota", WIDTH, UI.Sizes.HeaderHeight + 60)
local nextLine = window:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
nextLine:SetPoint("TOPLEFT", PAD, -UI.Sizes.HeaderHeight - UI.Spacing.SM)
nextLine:SetPoint("RIGHT", -PAD, 0)
nextLine:SetHeight(NEXT_LINE)
nextLine:SetJustifyH("LEFT")
nextLine:SetWordWrap(false)

-- One fixed SecureActionButtonTemplate per slot: left click (and its key binding) casts the slot's spell on your
-- current target, exactly like an action bar button. Attributes, position and visibility only out of combat.
local buttons = {}
for slot = 1, Logic.SLOTS do
    local button = CreateFrame("Button", "PaTiRotaSlot" .. slot, window, "SecureActionButtonTemplate,BackdropTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown") -- down or up, whichever ActionButtonUseKeyDown says
    button:SetSize(WIDTH - 2 * PAD, ROW)
    UI.ApplyBackdrop(button, "Panel", "Border")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON, ICON)
    button.icon:SetPoint("LEFT", 3, 0)
    button.status = button:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    button.status:SetPoint("RIGHT", -UI.Spacing.MD, 0)
    button.name = button:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    button.name:SetPoint("LEFT", button.icon, "RIGHT", UI.Spacing.SM, 0)
    button.name:SetPoint("RIGHT", button.status, "LEFT", -UI.Spacing.SM, 0)
    button.name:SetJustifyH("LEFT")
    button.name:SetWordWrap(false)
    UI.SetTooltip(button, function() return button.tooltipLines end)
    button:Hide()
    buttons[slot] = button
end

local emptyHint = window:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
emptyHint:SetPoint("TOPLEFT", PAD, -UI.Sizes.HeaderHeight - UI.Spacing.SM)
emptyHint:SetPoint("RIGHT", -PAD, 0)
emptyHint:SetJustifyH("LEFT")
emptyHint:SetWordWrap(true)
UI.BindText(emptyHint, "EMPTY_HINT")

-- Out of combat only: which slot buttons are shown, where, and with which fixed spell. Returns false if combat
-- blocked it (then it runs after PLAYER_REGEN_ENABLED).
local shownSlots = {} -- { slot } in priority order, as last applied (painting follows this, also in combat)
local function applySlots()
    if not DB then return true end
    if InCombatLockdown() then slotsPending = true; return false end
    slotsPending = false
    shownSlots = {}
    local filled = Logic.Filled(DB.slots)
    if testMode then
        filled = {}
        for index in ipairs(TEST_SKILLS) do filled[index] = { slot = index, id = 0 } end
    end
    local byslot = {}
    for _, item in ipairs(filled) do byslot[item.slot] = item end
    local y = UI.Sizes.HeaderHeight + UI.Spacing.SM + NEXT_LINE
    for slot, button in ipairs(buttons) do
        local item = not DB.collapsed and byslot[slot]
        local castName = item and not testMode and Spells.IsKnown(item.id) and Spells.CastName(item.id) or nil
        local attributes = Logic.SlotAttributes(castName)
        for _, key in ipairs(Logic.SLOT_ATTRIBUTES) do button:SetAttribute(key, attributes[key]) end
        button.boundId, button.boundSpell = item and item.id, castName
        button:SetShown(item ~= nil and item ~= false)
    end
    for _, item in ipairs(DB.collapsed and {} or filled) do
        local button = buttons[item.slot]
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -y)
        y = y + ROW + ROW_GAP
        shownSlots[#shownSlots + 1] = item.slot
    end
    local empty = not DB.collapsed and #filled == 0
    emptyHint:SetShown(empty)
    nextLine:SetShown(not DB.collapsed and not empty)
    if DB.collapsed then
        window:SetHeight(UI.Sizes.HeaderHeight)
    elseif empty then
        window:SetHeight(UI.Sizes.HeaderHeight + UI.Spacing.SM + math.ceil(emptyHint:GetStringHeight() or 14) + PAD)
    else
        window:SetHeight(y - ROW_GAP + PAD)
    end
    window:SetTestMode(testMode)
    return true
end

-- Painting (plain regions only: fine in combat) ----------------------------------------------------

local STATE_COLOR = { READY = "Success", GCD = "Text", COOLDOWN = "TextMuted", UNKNOWN = "TextMuted",
    UNUSABLE = "Warning", NOT_KNOWN = "Danger" }

local function readState(id, gcd, now)
    local start, duration = Spells.Cooldown(id)
    return Logic.CooldownState({ known = Spells.IsKnown(id), start = start, duration = duration,
        usable = Spells.Usable(id) }, gcd, now, isSecret)
end

local function statusText(result)
    if result.state == "COOLDOWN" then return L.SECONDS:format(Logic.FormatRemaining(result.remaining)) end
    return L["STATE_" .. result.state]
end

-- Returns true while a shown skill cools down (the ticker keeps the texts current).
local function paint()
    if not DB or DB.collapsed then return false end
    local now = GetTime()
    local gcdStart, gcdDuration = Spells.Cooldown(Spells.GCD_SPELL)
    local gcd = { start = gcdStart, duration = gcdDuration }
    local states, names = {}, {}
    for index, slot in ipairs(shownSlots) do
        local button = buttons[slot]
        local id = button.boundId
        states[index] = testMode and Logic.TEST_STATES[index] or readState(id, gcd, now)
        names[index] = testMode and L[TEST_SKILLS[index]] or Spells.Name(id) or L.UNKNOWN_SPELL:format(tostring(id))
        button.icon:SetTexture(testMode and TEST_ICON or Spells.Icon(id) or TEST_ICON)
    end
    local recommended, waiting = Logic.Recommend(states)
    local running = false
    for index, slot in ipairs(shownSlots) do
        local button, result = buttons[slot], states[index]
        local isNext = index == recommended
        button.name:SetText(names[index])
        button.status:SetText(statusText(result))
        button.status:SetTextColor(UI.Color(STATE_COLOR[result.state] or "Text"))
        button.icon:SetDesaturated(result.state ~= "READY" and result.state ~= "GCD")
        button:SetBackdropBorderColor(UI.Color(isNext and "Accent" or "Border"))
        button.tooltipLines = { names[index], L.TIP_STATE:format(statusText(result)),
            button.boundSpell and L.TIP_CLICK:format(button.boundSpell) or L.TIP_NO_CLICK,
            InCombatLockdown() and L.TIP_COMBAT_FIXED or nil }
        running = running or result.remaining ~= nil
    end
    if recommended then
        local text = L.NEXT:format(names[recommended], statusText(states[recommended]))
        nextLine:SetText(waiting and L.NEXT_WAITING:format(names[recommended], statusText(states[recommended])) or text)
    else
        nextLine:SetText(L.NEXT_NONE)
    end
    return running
end

local ticker = CreateFrame("Frame", nil, UIParent)
ticker:Hide()
local sinceTick = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    sinceTick = sinceTick + elapsed
    if sinceTick < TICK_SECONDS then return end
    sinceTick = 0
    if not paint() or not window:IsShown() then self:Hide() end
end)

local function update()
    ticker:SetShown(paint() and window:IsShown())
end

-- Settings modal: Settings.lua ----------------------------------------------------------------

ns.Settings.Init({ db = function() return DB end, window = window, say = say,
    slotsChanged = function()
        if not applySlots() then say("APPLY_AFTER_COMBAT") end
        update()
    end,
    restored = function()
        window:ApplyOpacity()
        UI.SetLanguage(DB.language)
        window:SetLocked(DB.locked)
        if not InCombatLockdown() then window:SetScale(DB.scale) end
        applySlots()
        update()
    end })
local openSettings = ns.Settings.Open

-- Actions -------------------------------------------------------------------------------------

local function combatBlocked()
    if InCombatLockdown() then say("COMBAT_LOCKED"); return true end
    return false
end

local function setShown(shown, quiet)
    if InCombatLockdown() then -- secure slot buttons: the window cannot be shown/hidden in combat
        if not quiet then say("COMBAT_LOCKED") end
        return false
    end
    window:SetShown(shown)
    if shown then update() elseif not quiet then say("HIDDEN_HINT") end
    return true
end

-- Optional PaTiSuite control panel: the same rules as the commands, without chat lines (false = not possible now).
window.suiteSetShown = function(shown) return setShown(shown, true) end

local function toggleTestMode()
    if combatBlocked() then return end
    testMode = not testMode
    applySlots()
    update()
end

local function toggleCollapsed()
    if combatBlocked() then return end
    DB.collapsed = not DB.collapsed
    applySlots()
    update()
end

local function resetPosition()
    if combatBlocked() then return end
    DB.point, DB.relativePoint, DB.x, DB.y = nil, nil, nil, nil
    window:Attach(DB, 0, -260)
end

local function printDebug()
    local version, build, _, interface = GetBuildInfo()
    local gcdStart, gcdDuration = Spells.Cooldown(Spells.GCD_SPELL)
    print("|cff68caffPaTiRota Debug:|r")
    for _, line in ipairs({
        ("Addon %s %s · PaTiShared UI %s"):format(addonName, addonVersion(), tostring(UI.VERSION)),
        ("WoW %s (build %s, interface %s) · locale %s · UI language %s"):format(tostring(version), tostring(build),
            tostring(interface), GetLocale(), UI.GetLanguage()),
        ("Cooldown API %s · usable API %s · issecretvalue %s · GCD spell %d readable %s · test mode %s · pending %s")
            :format(Spells.CooldownApi(), (C_Spell and C_Spell.IsSpellUsable) and "C_Spell" or (IsUsableSpell
            and "IsUsableSpell" or "none"), issecretvalue and "yes" or "no", Spells.GCD_SPELL,
            tostring(type(gcdStart) == "number" and type(gcdDuration) == "number" and not isSecret(gcdStart)),
            testMode and "on" or "off", slotsPending and "yes" or "no"),
        ("Combat %s · last caught API error: %s"):format(InCombatLockdown() and "yes" or "no",
            Spells.lastError or "none"),
    }) do print("  " .. line) end
    local gcd = { start = gcdStart, duration = gcdDuration }
    for slot, id in ipairs(DB.slots) do
        if id ~= 0 then
            local result = readState(id, gcd, GetTime())
            print(("  slot %d: %s (%d) · known %s · state %s · button spell %s"):format(slot,
                tostring(Spells.Name(id)), id, tostring(Spells.IsKnown(id)), result.state,
                tostring(buttons[slot]:GetAttribute("spell1"))))
        end
    end
end

local COMMANDS = {
    [""] = function() setShown(not window:IsShown()) end,
    toggle = function() setShown(not window:IsShown()) end,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    test = toggleTestMode,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    reset = resetPosition,
    settings = openSettings,
    debug = printDebug,
    version = function() say("VERSION", addonVersion()) end,
}

SLASH_PATIROTA1 = "/patirota"
SLASH_PATIROTA2 = "/prota"
SlashCmdList.PATIROTA = function(message)
    local command = COMMANDS[(message or ""):match("^%s*(.-)%s*$"):lower()]
    if command and DB then command() else say("HELP") end
end

window:SetMenu(function()
    if not DB then return {} end
    local combat = InCombatLockdown()
    local combatTip = combat and "COMBAT_LOCKED" or nil
    return {
        { text = "SETTINGS", onClick = openSettings },
        { text = window:IsLocked() and "UNLOCK" or "LOCK", onClick = function() window:SetLocked(not window:IsLocked()) end },
        { text = DB.collapsed and "EXPAND" or "COLLAPSE", disabled = combat, tooltip = combatTip, onClick = toggleCollapsed },
        { text = "TEST_MODE", checked = testMode, disabled = combat, tooltip = combatTip, onClick = toggleTestMode },
        { text = "HIDE", disabled = combat, tooltip = combatTip, onClick = function() setShown(false) end },
    }
end)

-- Events ---------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        PaTiRotaDB = Logic.Migrate(PaTiRotaDB)
        DB = PaTiRotaDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, 0, -260)
        if not InCombatLockdown() then window:SetScale(DB.scale) end -- /reload in combat: after combat
        Spells.Rescan()
        applySlots()
        say("LOADED")
    elseif not DB then
        return
    elseif event == "SPELLS_CHANGED" then
        Spells.Rescan() -- a newly learned spell becomes castable
        applySlots()
    elseif event == "PLAYER_REGEN_ENABLED" then
        window:SetScale(DB.scale)
        if slotsPending then applySlots() end
    end
    update()
end)
UI.OnLanguageChanged(update)
