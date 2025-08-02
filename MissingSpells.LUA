-- Check if a spell is already on your action bars
local function isSpellOnActionBar(spellName)
    for i = 1, 120 do
        local actionType, id = GetActionInfo(i)
        if actionType == "spell" and id then
            local name = GetSpellInfo(id)
            if name == spellName then
                return true
            end
        end
    end
    return false
end

-- Get all active (non-passive) spells from the spellbook
local function GetActiveSpells()
    local active = {}
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, "player")
        if not name then break end

        if GetSpellBookItemInfo(i, "player") == "SPELL" and not IsPassiveSpell(i, "player") then
            active[name] = true
        end

        i = i + 1
    end
    return active
end

-- Update which spellbook buttons should glow
local function UpdateSpellbookHighlights()
    local activeSpells = GetActiveSpells()

    for i = 1, SPELLS_PER_PAGE do
        local button = _G["SpellButton" .. i]

        -- Always clear old glow
        if button and button.__glowing then
            ActionButton_HideOverlayGlow(button)
            button.__glowing = false
        end

        -- Then conditionally add new glow
        if button and button:IsShown() then
            local slot = SpellBook_GetSpellBookSlot(button)
            local spellName = GetSpellBookItemName(slot, "player")

            if spellName and activeSpells[spellName] and not isSpellOnActionBar(spellName) then
                ActionButton_ShowOverlayGlow(button)
                button.__glowing = true
            end
        end
    end
end

-- Periodic updates while spellbook is open
local updateTicker

local function StartPeriodicUpdates()
    if not updateTicker then
        updateTicker = C_Timer.NewTicker(5, UpdateSpellbookHighlights)
    end
end

local function StopPeriodicUpdates()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

SpellBookFrame:HookScript("OnShow", function()
    UpdateSpellbookHighlights()
    StartPeriodicUpdates()
end)

SpellBookFrame:HookScript("OnHide", function()
    StopPeriodicUpdates()
end)

-- Hook spellbook page navigation buttons
local function HookPageButton(button)
    if button and not button.__highlightHooked then
        button:HookScript("OnClick", function()
            C_Timer.After(0.05, UpdateSpellbookHighlights)
        end)
        button.__highlightHooked = true
    end
end

HookPageButton(SpellBookPrevPageButton)
HookPageButton(SpellBookNextPageButton)

-- Hook right-side skill line tabs (e.g., spec/profession)
local function HookSpellTabs()
    local i = 1
    while true do
        local tab = _G["SpellBookSkillLineTab" .. i]
        if not tab then break end

        if not tab.__highlightHooked then
            tab:HookScript("OnClick", function()
                C_Timer.After(0.05, UpdateSpellbookHighlights)
            end)
            tab.__highlightHooked = true
        end

        i = i + 1
    end
end

-- On login: hook tabs once
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", HookSpellTabs)
