-- =====[ Config / Constants ]=====
local BOOK = "player"                    -- Keep as-is since this works in your client
local PER_PAGE = SPELLS_PER_PAGE or 12   -- Fallback to 12 if the global isn't set
local REFRESH_DELAY = 0.05               -- Small delay after page/tab changes
local TICK_SECONDS = 5                   -- Periodic refresh while Spellbook is open

-- =====[ Utilities ]=====

-- Check if a spell (by name) is already on action bars
local function IsSpellOnActionBar(spellName)
    if not spellName then return false end
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

-- Gather all active (non-passive) spells from the spellbook (keyed by name)
local function GetActiveSpells()
    local active, i = {}, 1
    while true do
        local name = GetSpellBookItemName(i, BOOK)
        if not name then break end

        if GetSpellBookItemInfo(i, BOOK) == "SPELL" and not IsPassiveSpell(i, BOOK) then
            active[name] = true
        end
        i = i + 1
    end
    return active
end

-- Safe glow helpers (overlay glow if available, fallback to Spellbook highlight texture)
local function HideGlow(button)
    if not button then return end
    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(button)
    end
    if button.SpellHighlightTexture then
        button.SpellHighlightTexture:Hide()
    end
    button.__glowing = false
end

local function ShowGlow(button)
    if not button then return end
    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(button)
    end
    if button.SpellHighlightTexture then
        button.SpellHighlightTexture:SetAlpha(1)
        button.SpellHighlightTexture:SetBlendMode("ADD")
        button.SpellHighlightTexture:Show()
    end
    button.__glowing = true
end

-- =====[ Core ]=====

-- Update which spellbook buttons should glow
local function UpdateSpellbookHighlights()
    if not SpellBookFrame or not SpellBookFrame:IsShown() then return end

    local activeSpells = GetActiveSpells()

    for i = 1, PER_PAGE do
        local button = _G["SpellButton" .. i]

        -- Always clear old glow
        if button and button.__glowing then
            HideGlow(button)
        end

        -- Then conditionally add new glow
        if button and button:IsShown() then
            local slot = SpellBook_GetSpellBookSlot(button)
            if slot then
                local spellName = GetSpellBookItemName(slot, BOOK)
                if spellName and activeSpells[spellName] and not IsSpellOnActionBar(spellName) then
                    ShowGlow(button)
                end
            end
        end
    end
end

-- Periodic updates while spellbook is open
local updateTicker

local function StartPeriodicUpdates()
    if not updateTicker then
        updateTicker = C_Timer.NewTicker(TICK_SECONDS, UpdateSpellbookHighlights)
    end
end

local function StopPeriodicUpdates()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

-- Refresh when the Spellbook opens/closes
SpellBookFrame:HookScript("OnShow", function()
    UpdateSpellbookHighlights()
    StartPeriodicUpdates()
end)

SpellBookFrame:HookScript("OnHide", function()
    StopPeriodicUpdates()
end)

-- Hook a button to refresh shortly after clicks (page left/right)
local function HookPageButton(button)
    if button and not button.__highlightHooked then
        button:HookScript("OnClick", function()
            C_Timer.After(REFRESH_DELAY, UpdateSpellbookHighlights)
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
                C_Timer.After(REFRESH_DELAY, UpdateSpellbookHighlights)
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
