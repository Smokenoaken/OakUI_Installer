local addonName, addonTable = ...

local _, playerClass = UnitClass("player")
local classColor = C_ClassColor.GetClassColor(playerClass)
local r, g, b = classColor.r, classColor.g, classColor.b
local cWrap = "|c" .. classColor:GenerateHexColor()

local function MakeVisibilityCheckbox(parent, text, updateFunc, getStateFunc)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.32, 0.38, 1)
    local inner = btn:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("LEFT", btn, "RIGHT", 10, 0)
    label:SetText(text)

    btn.UpdateState = function(self)
        if getStateFunc() then
            inner:SetColorTexture(r, g, b, 1)
        else
            inner:SetColorTexture(0.137, 0.141, 0.172, 1)
        end
    end

    btn:SetScript("OnClick", function(self)
        local newState = not getStateFunc()
        updateFunc(newState)
        self:UpdateState()

        if addonTable.ShowReloadPrompt then
            addonTable.ShowReloadPrompt("QUI visibility settings updated!\nA UI Reload is required to finalize the changes.")
        else
            ReloadUI()
        end
    end)

    return btn, label
end

-- ==========================================
-- QUI DATABASE HOOKS
-- ==========================================

local function SetCDM(state)
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile then
        if not _G.QUI.db.profile.cdmVisibility then _G.QUI.db.profile.cdmVisibility = {} end
        _G.QUI.db.profile.cdmVisibility.showAlways = state
    end
end

local function GetCDM()
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile and _G.QUI.db.profile.cdmVisibility then
        return _G.QUI.db.profile.cdmVisibility.showAlways
    end
    return false
end

local function SetUnitframes(state)
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile then
        if not _G.QUI.db.profile.unitframesVisibility then _G.QUI.db.profile.unitframesVisibility = {} end
        _G.QUI.db.profile.unitframesVisibility.showAlways = state
    end
end

local function GetUnitframes()
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile and _G.QUI.db.profile.unitframesVisibility then
        return _G.QUI.db.profile.unitframesVisibility.showAlways
    end
    return false
end

local function SetMouseover(state)
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile then
        if not _G.QUI.db.profile.actionBars then _G.QUI.db.profile.actionBars = {} end
        if not _G.QUI.db.profile.actionBars.fade then _G.QUI.db.profile.actionBars.fade = {} end
        _G.QUI.db.profile.actionBars.fade.enabled = not state

        if not _G.QUI.db.profile.actionBarsVisibility then
            _G.QUI.db.profile.actionBarsVisibility = {}
        end

        -- QUI 3.0 adds a separate HUD visibility controller for action bars.
        -- Keep it aligned with OakUI's "Disable Action Bar Fading" toggle so
        -- bars remain visible instead of being hidden by HUD rules.
        _G.QUI.db.profile.actionBarsVisibility.showAlways = state
        if state then
            _G.QUI.db.profile.actionBarsVisibility.showOnMouseover = false
        end

        if _G.QUI_RefreshActionBarFade then
            _G.QUI_RefreshActionBarFade()
        end
        if _G.QUI_RefreshActionBarsMouseover then
            _G.QUI_RefreshActionBarsMouseover()
        end
        if _G.QUI_RefreshActionBarsVisibility then
            _G.QUI_RefreshActionBarsVisibility()
        end
    end
end

local function GetMouseover()
    if _G.QUI and _G.QUI.db and _G.QUI.db.profile then
        local fadeDisabled = false
        if _G.QUI.db.profile.actionBars and _G.QUI.db.profile.actionBars.fade then
            fadeDisabled = not _G.QUI.db.profile.actionBars.fade.enabled
        end

        local visibilityAlwaysOn = false
        if _G.QUI.db.profile.actionBarsVisibility then
            visibilityAlwaysOn = _G.QUI.db.profile.actionBarsVisibility.showAlways == true
        end

        return fadeDisabled or visibilityAlwaysOn
    end
    return false
end

-- ==========================================
-- BUILD THE UI PAGE
-- ==========================================
function addonTable.BuildVisibilityUI(parentFrame)
    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "QUI Visibility Hooks|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetWidth(480)
    Desc:SetJustifyH("LEFT")
    Desc:SetText("Control QUI's native visibility settings directly from OakUI. Changes automatically update the QUI database.")

    local checkboxes = {}

    local cb1, lbl1 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Always Show CDM|r", SetCDM, GetCDM)
    cb1:SetPoint("TOPLEFT", Desc, "BOTTOMLEFT", 0, -40)
    local d1 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d1:SetPoint("LEFT", lbl1, "RIGHT", 15, 0); d1:SetText("- Forces the CDM block to remain visible."); d1:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb1)

    local cb2, lbl2 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Always Show Unitframes|r", SetUnitframes, GetUnitframes)
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -30)
    local d2 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d2:SetPoint("LEFT", lbl2, "RIGHT", 15, 0); d2:SetText("- Overrides combat-only rules for frames."); d2:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb2)

    local cb3, lbl3 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Disable Action Bar Fading|r", SetMouseover, GetMouseover)
    cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -30)
    local d3 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d3:SetPoint("LEFT", lbl3, "RIGHT", 15, 0); d3:SetText("- Turns off action bar mouseover fading."); d3:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb3)

    -- Update states immediately when built
    for _, cb in ipairs(checkboxes) do cb:UpdateState() end

    -- Also update states when the frame is shown (if toggled via other means)
    parentFrame:SetScript("OnShow", function()
        for _, cb in ipairs(checkboxes) do cb:UpdateState() end
    end)
end
