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
        if parent.UpdateVisibilityCheckboxes then
            parent:UpdateVisibilityCheckboxes()
        end

        if addonTable.ShowReloadPrompt then
            addonTable.ShowReloadPrompt("Visibility settings updated!\nA UI Reload may be required to finalize every frame.")
        else
            ReloadUI()
        end
    end)

    return btn, label
end

local function EnsureVisibilityDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.visibility then OakUI_DB.visibility = {} end
    return OakUI_DB.visibility
end

local function GetElvUI()
    if type(_G.ElvUI) ~= "table" then return nil end
    return _G.ElvUI[1]
end

local function RefreshElvUIUnitFrames(E)
    if not E or type(E.GetModule) ~= "function" then return end
    local UF = E:GetModule("UnitFrames", true)
    if UF and type(UF.Update_AllFrames) == "function" then
        pcall(UF.Update_AllFrames, UF)
    end
end

local function RestoreAccidentallyForcedGroupVisibility(E)
    local db = EnsureVisibilityDB()
    if not E or not E.db or not E.db.unitframe or not E.db.unitframe.units then return false end

    local units = E.db.unitframe.units
    local changed = false
    for _, unit in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
        if units[unit] and units[unit].visibility == "show" then
            units[unit].visibility = nil
            changed = true
        end
    end
    if units.party and units.party.visibility == "show" then
        units.party.visibility = "[@raid6,exists][@party1,noexists] hide;show"
        changed = true
    end
    if units.raid1 and units.raid1.visibility == "show" then
        units.raid1.visibility = "[@raid6,noexists][@raid21,exists] hide;show"
        changed = true
    end
    if units.raid2 and units.raid2.visibility == "show" then
        units.raid2.visibility = "[@raid21,noexists][@raid31,exists] hide;show"
        changed = true
    end
    if units.raid3 and units.raid3.visibility == "show" then
        units.raid3.visibility = "[@raid31,noexists] hide;show"
        changed = true
    end

    db.unitframesAlways = nil
    return changed
end

local function SetUnitframes(state)
    local db = EnsureVisibilityDB()
    db.playerFrameHidden = state == true
    local E = GetElvUI()
    if E and E.db and E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player then
        RestoreAccidentallyForcedGroupVisibility(E)
        local player = E.db.unitframe.units.player
        player.fader = player.fader or {}
        player.fader.enable = state == true
        RefreshElvUIUnitFrames(E)
    elseif E and RestoreAccidentallyForcedGroupVisibility(E) then
        RefreshElvUIUnitFrames(E)
    end
end

local function GetUnitframes()
    local E = GetElvUI()
    if E and RestoreAccidentallyForcedGroupVisibility(E) then
        RefreshElvUIUnitFrames(E)
    end
    if E and E.db and E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player and E.db.unitframe.units.player.fader then
        return E.db.unitframe.units.player.fader.enable == true
    end
    return EnsureVisibilityDB().playerFrameHidden == true
end

local function SetMouseover(state)
    if addonTable.SetActionBarsHidden then
        addonTable.SetActionBarsHidden(state)
    end
end

local function GetMouseover()
    if addonTable.GetActionBarsHidden then
        return addonTable.GetActionBarsHidden()
    end
    return false
end

local function RefreshElvUIChat(E)
    if not E or type(E.GetModule) ~= "function" then return end
    local LO = E:GetModule("Layout", true)
    if LO and type(LO.ToggleChatPanels) == "function" then
        pcall(LO.ToggleChatPanels, LO)
    end
end

local function SetChatBackgroundHidden(state)
    EnsureVisibilityDB().chatBackgroundHidden = state == true
    local E = GetElvUI()
    if E and E.db and E.db.chat then
        E.db.chat.panelBackdrop = state and "HIDEBOTH" or "SHOWBOTH"
        RefreshElvUIChat(E)
    end
end

local function GetChatBackgroundHidden()
    local E = GetElvUI()
    if E and E.db and E.db.chat then
        return E.db.chat.panelBackdrop == "HIDEBOTH"
    end
    return EnsureVisibilityDB().chatBackgroundHidden == true
end

local function GetCDM()
    return _G.Ayije_CDM
end

local function SetCDMFading(state)
    EnsureVisibilityDB().cdmFading = state == true
    local CDM = GetCDM()
    if CDM and CDM.db then
        CDM.db.fadingEnabled = state == true
        if type(CDM.Refresh) == "function" then
            pcall(CDM.Refresh, CDM, "STYLE")
        end
    end
end

local function GetCDMFading()
    local CDM = GetCDM()
    if CDM and CDM.db and CDM.db.fadingEnabled ~= nil then
        return CDM.db.fadingEnabled == true
    end
    return EnsureVisibilityDB().cdmFading == true
end

local function SetAllHidden(state)
    SetUnitframes(state)
    SetMouseover(state)
    SetChatBackgroundHidden(state)
    SetCDMFading(state)
    EnsureVisibilityDB().allHidden = state == true
end

local function GetAllHidden()
    return GetUnitframes() and GetMouseover() and GetChatBackgroundHidden() and GetCDMFading()
end

function addonTable.ApplyOakVisibilityDefaults()
    SetAllHidden(true)
end

-- ==========================================
-- BUILD THE UI PAGE
-- ==========================================
function addonTable.BuildVisibilityUI(parentFrame)
    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Visibility|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetWidth(480)
    Desc:SetJustifyH("LEFT")
    Desc:SetText("Control OakUI visibility behavior for the selected base UI.")

    local checkboxes = {}

    local cbAll, lblAll = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide All|r", SetAllHidden, GetAllHidden)
    cbAll:SetPoint("TOPLEFT", Desc, "BOTTOMLEFT", 0, -40)
    local dAll = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dAll:SetPoint("LEFT", lblAll, "RIGHT", 15, 0); dAll:SetText("- Applies every visibility hide toggle below."); dAll:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cbAll)

    local cb1, lbl1 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Player Frame|r", SetUnitframes, GetUnitframes)
    cb1:SetPoint("TOPLEFT", cbAll, "BOTTOMLEFT", 0, -30)
    local d1 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d1:SetPoint("LEFT", lbl1, "RIGHT", 15, 0); d1:SetText("- Toggles ElvUI Player > Fader."); d1:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb1)

    local cb2, lbl2 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Action Bars|r", SetMouseover, GetMouseover)
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -30)
    local d2 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d2:SetPoint("LEFT", lbl2, "RIGHT", 15, 0); d2:SetText("- Fades all action bars in together on mouseover."); d2:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb2)

    local cb3, lbl3 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Chat Background|r", SetChatBackgroundHidden, GetChatBackgroundHidden)
    cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -30)
    local d3 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d3:SetPoint("LEFT", lbl3, "RIGHT", 15, 0); d3:SetText("- Sets ElvUI Chat > Panels > Panel Backdrop."); d3:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb3)

    local cb4, lbl4 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide CDM|r", SetCDMFading, GetCDMFading)
    cb4:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -30)
    local d4 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d4:SetPoint("LEFT", lbl4, "RIGHT", 15, 0); d4:SetText("- Toggles Ayije CDM > Styling > Fading."); d4:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb4)

    parentFrame.UpdateVisibilityCheckboxes = function()
        for _, cb in ipairs(checkboxes) do cb:UpdateState() end
    end

    parentFrame:UpdateVisibilityCheckboxes()

    -- Also update states when the frame is shown (if toggled via other means)
    parentFrame:SetScript("OnShow", function(self)
        self:UpdateVisibilityCheckboxes()
    end)
end

local CleanupFrame = CreateFrame("Frame")
CleanupFrame:RegisterEvent("PLAYER_LOGIN")
CleanupFrame:SetScript("OnEvent", function(self)
    C_Timer.After(1, function()
        local E = GetElvUI()
        if E and RestoreAccidentallyForcedGroupVisibility(E) then
            RefreshElvUIUnitFrames(E)
        end
    end)
    self:UnregisterEvent("PLAYER_LOGIN")
end)
