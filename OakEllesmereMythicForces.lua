local addonName, addonTable = ...

local activeEventFrame
local activeTexts = {}
local previewActive = false
local previewPlate
local previewText

local FORCE_SIZE_KEY = "oakEllesmereMythicForcesSize"
local FORCE_X_OFFSET_KEY = "oakEllesmereMythicForcesXOffset"
local FORCE_Y_OFFSET_KEY = "oakEllesmereMythicForcesYOffset"

local DEFAULT_FORCE_SIZE = 15
local DEFAULT_FORCE_X_OFFSET = 2
local DEFAULT_FORCE_Y_OFFSET = 0

local MIN_FORCE_SIZE = 6
local MAX_FORCE_SIZE = 24
local MIN_FORCE_OFFSET = -125
local MAX_FORCE_OFFSET = 125

local function EnsureVisibilityDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.visibility then OakUI_DB.visibility = {} end
    if OakUI_DB.visibility.oakEllesmereMythicForces == nil then
        OakUI_DB.visibility.oakEllesmereMythicForces = true
    end
    return OakUI_DB.visibility
end

local function GetSetting(key, defaultValue, minValue, maxValue)
    local value = tonumber(EnsureVisibilityDB()[key])
    if not value then return defaultValue end
    return math.max(minValue, math.min(maxValue, value))
end

local function SetSetting(key, value, defaultValue, minValue, maxValue)
    local db = EnsureVisibilityDB()
    value = tonumber(value) or defaultValue
    db[key] = math.max(minValue, math.min(maxValue, value))
end

local function IsChallengeModeActive()
    return C_PartyInfo
        and type(C_PartyInfo.IsChallengeModeActive) == "function"
        and C_PartyInfo.IsChallengeModeActive() == true
end

local function IsSupportedEnemy(unit)
    if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) then
        return false
    end
    if UnitIsPlayer(unit) then return false end
    if UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit) then
        return false
    end
    return true
end

local function SetTextFont(text, size)
    size = size or DEFAULT_FORCE_SIZE
    local ns = _G.EllesmereNameplates_NS
    if ns and type(ns.SetFSFont) == "function" then
        local ok = pcall(ns.SetFSFont, text, size)
        if ok then return end
    end

    local eui = _G.EllesmereUI
    local font = eui and type(eui.GetFontPath) == "function"
        and eui.GetFontPath("nameplates")
    local outline = eui and type(eui.GetFontOutlineFlag) == "function"
        and eui.GetFontOutlineFlag("nameplates")
    if text and text.SetFont then
        text:SetFont(font or "Interface\\AddOns\\OakUI_Installer\\Media\\OakFont.ttf", size, outline or "OUTLINE")
    end
end

local function ConfigureText(text)
    text:SetTextColor(1, 1, 1, 1)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetNonSpaceWrap(false)
    text:SetMaxLines(1)
    text:SetWidth(60)
end

local function ApplyTextLayout(plate, text)
    local size = GetSetting(FORCE_SIZE_KEY, DEFAULT_FORCE_SIZE, MIN_FORCE_SIZE, MAX_FORCE_SIZE)
    local xOffset = GetSetting(FORCE_X_OFFSET_KEY, DEFAULT_FORCE_X_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)
    local yOffset = GetSetting(FORCE_Y_OFFSET_KEY, DEFAULT_FORCE_Y_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)

    SetTextFont(text, size)
    text:SetHeight(size + 2)
    text:ClearAllPoints()
    text:SetPoint("LEFT", plate.cast, "RIGHT", xOffset, yOffset)
end

local function EnsureText(plate)
    if plate.oakMythicForcesText then
        return plate.oakMythicForcesText
    end

    local parent = plate.healthTextFrame or plate
    local text = parent:CreateFontString(nil, "OVERLAY")
    ConfigureText(text)
    ApplyTextLayout(plate, text)
    text:Hide()
    plate.oakMythicForcesText = text
    return text
end

local function HideUnit(unit)
    local text = activeTexts[unit]
    if text then
        text:Hide()
        activeTexts[unit] = nil
    end
end

local function UpdateUnit(unit, plate)
    if not plate then
        HideUnit(unit)
        return
    end

    local text = EnsureText(plate)
    ApplyTextLayout(plate, text)
    activeTexts[unit] = text

    if not IsChallengeModeActive() or not IsSupportedEnemy(unit) then
        text:Hide()
        return
    end

    local scenarioInfo = C_ScenarioInfo
    if not scenarioInfo or type(scenarioInfo.GetUnitCriteriaProgressValues) ~= "function" then
        text:Hide()
        return
    end

    local amount, _, percent = scenarioInfo.GetUnitCriteriaProgressValues(unit)
    if type(amount) == "nil" or type(percent) == "nil" then
        text:Hide()
        return
    end

    text:SetFormattedText("%s%%", percent)
    text:Show()
end

local function FindPreviewPlate()
    local ns = _G.EllesmereNameplates_NS
    if not ns or type(ns.plates) ~= "table" then return nil end

    for _, plate in pairs(ns.plates) do
        if plate and plate.cast and (plate.healthTextFrame or plate.CreateFontString) then
            return plate
        end
    end
end

local function EnsurePreviewText(plate)
    if plate.oakMythicForcesPreviewText then
        return plate.oakMythicForcesPreviewText
    end

    local parent = plate.healthTextFrame or plate
    local text = parent:CreateFontString(nil, "OVERLAY")
    ConfigureText(text)
    plate.oakMythicForcesPreviewText = text
    return text
end

local function ClearPreview()
    if previewText then
        previewText:Hide()
    end
    previewText = nil
    previewPlate = nil
end

local function RefreshPreview()
    if not previewActive then return end

    local ns = _G.EllesmereNameplates_NS
    local currentPlateStillVisible = false
    if previewPlate and ns and type(ns.plates) == "table" then
        for _, plate in pairs(ns.plates) do
            if plate == previewPlate then
                currentPlateStillVisible = true
                break
            end
        end
    end

    if not currentPlateStillVisible then
        ClearPreview()
        previewPlate = FindPreviewPlate()
    end
    if not previewPlate then return end

    if previewPlate.oakMythicForcesText then
        previewPlate.oakMythicForcesText:Hide()
    end

    previewText = EnsurePreviewText(previewPlate)
    ApplyTextLayout(previewPlate, previewText)
    previewText:SetText("75%")
    previewText:Show()
end

local function RefreshAll()
    local ns = _G.EllesmereNameplates_NS
    if not ns or type(ns.plates) ~= "table" then return end

    for unit, text in pairs(activeTexts) do
        if not ns.plates[unit] then
            text:Hide()
            activeTexts[unit] = nil
        end
    end

    for unit, plate in pairs(ns.plates) do
        UpdateUnit(unit, plate)
    end

    RefreshPreview()
end

local function Enable()
    if activeEventFrame then
        activeEventFrame:UnregisterAllEvents()
    else
        activeEventFrame = CreateFrame("Frame")
    end

    activeEventFrame:RegisterEvent("ADDON_LOADED")
    activeEventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    activeEventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    activeEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    activeEventFrame:RegisterEvent("CHALLENGE_MODE_START")
    activeEventFrame:RegisterEvent("SCENARIO_UPDATE")
    activeEventFrame:SetScript("OnEvent", function(_, event, unit, loadedAddon)
        if event == "ADDON_LOADED" then
            if loadedAddon == "EllesmereUINameplates" then RefreshAll() end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            local ns = _G.EllesmereNameplates_NS
            UpdateUnit(unit, ns and ns.plates and ns.plates[unit])
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            HideUnit(unit)
        else
            RefreshAll()
        end
    end)
    RefreshAll()
end

local function Disable()
    if activeEventFrame then
        activeEventFrame:UnregisterAllEvents()
    end
    for unit, text in pairs(activeTexts) do
        text:Hide()
        activeTexts[unit] = nil
    end
    previewActive = false
    ClearPreview()
end

local function RefreshAppearance()
    local ns = _G.EllesmereNameplates_NS
    if not ns or type(ns.plates) ~= "table" then return end

    for _, plate in pairs(ns.plates) do
        if plate.oakMythicForcesText then
            ApplyTextLayout(plate, plate.oakMythicForcesText)
        end
    end
    RefreshPreview()
end

local function RefreshSettingsCog()
    if addonTable.RefreshOakEllesmereMythicForcesCog then
        addonTable.RefreshOakEllesmereMythicForcesCog()
    end
end

function addonTable.SetOakEllesmereMythicForcesEnabled(state)
    local db = EnsureVisibilityDB()
    db.oakEllesmereMythicForces = state == true
    if db.oakEllesmereMythicForces then
        Enable()
    else
        Disable()
    end
    RefreshSettingsCog()
end

function addonTable.GetOakEllesmereMythicForcesEnabled()
    return EnsureVisibilityDB().oakEllesmereMythicForces == true
end

function addonTable.GetOakEllesmereMythicForcesSize()
    return GetSetting(FORCE_SIZE_KEY, DEFAULT_FORCE_SIZE, MIN_FORCE_SIZE, MAX_FORCE_SIZE)
end

function addonTable.SetOakEllesmereMythicForcesSize(value)
    SetSetting(FORCE_SIZE_KEY, value, DEFAULT_FORCE_SIZE, MIN_FORCE_SIZE, MAX_FORCE_SIZE)
    RefreshAppearance()
end

function addonTable.GetOakEllesmereMythicForcesXOffset()
    return GetSetting(FORCE_X_OFFSET_KEY, DEFAULT_FORCE_X_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)
end

function addonTable.SetOakEllesmereMythicForcesXOffset(value)
    SetSetting(FORCE_X_OFFSET_KEY, value, DEFAULT_FORCE_X_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)
    RefreshAppearance()
end

function addonTable.GetOakEllesmereMythicForcesYOffset()
    return GetSetting(FORCE_Y_OFFSET_KEY, DEFAULT_FORCE_Y_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)
end

function addonTable.SetOakEllesmereMythicForcesYOffset(value)
    SetSetting(FORCE_Y_OFFSET_KEY, value, DEFAULT_FORCE_Y_OFFSET, MIN_FORCE_OFFSET, MAX_FORCE_OFFSET)
    RefreshAppearance()
end

function addonTable.GetOakEllesmereMythicForcesPreview()
    return previewActive
end

function addonTable.SetOakEllesmereMythicForcesPreview(state)
    previewActive = state == true
    if previewActive then
        RefreshPreview()
    else
        ClearPreview()
        if addonTable.GetOakEllesmereMythicForcesEnabled() then
            RefreshAll()
        end
    end
end

function addonTable.BuildOakEllesmereMythicForcesCog(parent, anchor)
    local eui = _G.EllesmereUI
    if not parent or not anchor or not eui or type(eui.BuildCogPopup) ~= "function" then
        return
    end

    local _, showCog = eui.BuildCogPopup({
        title = "M+ Forces Text Settings",
        frameStrata = "FULLSCREEN_DIALOG",
        frameLevel = 1300,
        rows = {
            { type = "slider", label = "Size", min = MIN_FORCE_SIZE, max = MAX_FORCE_SIZE, step = 1,
              get = addonTable.GetOakEllesmereMythicForcesSize,
              set = addonTable.SetOakEllesmereMythicForcesSize },
            { type = "slider", label = "X Offset", min = MIN_FORCE_OFFSET, max = MAX_FORCE_OFFSET, step = 1,
              get = addonTable.GetOakEllesmereMythicForcesXOffset,
              set = addonTable.SetOakEllesmereMythicForcesXOffset },
            { type = "slider", label = "Y Offset", min = MIN_FORCE_OFFSET, max = MAX_FORCE_OFFSET, step = 1,
              get = addonTable.GetOakEllesmereMythicForcesYOffset,
              set = addonTable.SetOakEllesmereMythicForcesYOffset },
            { type = "toggle", label = "Test Display", tooltip = "Shows a fake 75% value on a visible enemy nameplate so you can adjust the text placement. Turn it off when finished.",
              get = addonTable.GetOakEllesmereMythicForcesPreview,
              set = addonTable.SetOakEllesmereMythicForcesPreview },
        },
    })

    local cogButton = CreateFrame("Button", nil, parent)
    cogButton:SetSize(26, 26)
    cogButton:SetPoint("LEFT", anchor, "RIGHT", 184, 0)
    cogButton:SetFrameLevel(parent:GetFrameLevel() + 5)

    local cogTexture = cogButton:CreateTexture(nil, "OVERLAY")
    cogTexture:SetAllPoints()
    cogTexture:SetTexture(eui.RESIZE_ICON or eui.COGS_ICON)

    local function ElevatePopup()
        local popup = showCog._popupFrame
        if not popup then return end

        -- OakUI's installer deliberately raises its own FULLSCREEN_DIALOG
        -- frame. Keep this popup above it so the placement controls cannot be
        -- hidden behind the installer window.
        popup:SetFrameStrata("TOOLTIP")
        popup:SetFrameLevel(1100)
        if popup.Raise then popup:Raise() end
    end

    local function UpdateCogState()
        local enabled = addonTable.GetOakEllesmereMythicForcesEnabled()
        cogButton:SetAlpha(enabled and 0.4 or 0.15)
        cogButton:EnableMouse(enabled)
    end

    cogButton:SetScript("OnEnter", function()
        if addonTable.GetOakEllesmereMythicForcesEnabled() then
            cogButton:SetAlpha(0.7)
        end
    end)
    cogButton:SetScript("OnLeave", UpdateCogState)
    cogButton:SetScript("OnClick", function(button)
        if addonTable.GetOakEllesmereMythicForcesEnabled() then
            showCog(button)
            ElevatePopup()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, ElevatePopup)
            end
        end
    end)

    addonTable.RefreshOakEllesmereMythicForcesCog = UpdateCogState
    UpdateCogState()
end

function addonTable.ApplyOakEllesmereMythicForcesIfEnabled()
    if addonTable.GetOakEllesmereMythicForcesEnabled() then
        Enable()
    end
end
