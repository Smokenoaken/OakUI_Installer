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

local function IsEllesmereProvider()
    return addonTable.Profiles and addonTable.Profiles.BASE_UI_PROVIDER == "Ellesmere"
end

local function GetEllesmereAddonProfile(addonKey)
    if type(_G.EllesmereUIDB) ~= "table" then return nil end
    local profileKey = _G.EllesmereUIDB.activeProfile
    local profiles = _G.EllesmereUIDB.profiles
    local profile = profileKey and profiles and profiles[profileKey]
    if type(profile) ~= "table" then return nil end
    profile.addons = profile.addons or {}
    profile.addons[addonKey] = profile.addons[addonKey] or {}
    return profile.addons[addonKey]
end

local function SetEllesmerePlayerFrame(state)
    local db = EnsureVisibilityDB()
    db.playerFrameHidden = state == true
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    if unitFrames then
        unitFrames.player = unitFrames.player or {}
        unitFrames.pet = unitFrames.pet or {}
        unitFrames.player.visHideNoTarget = state == true
        unitFrames.pet.visHideNoTarget = state == true
    end
    if addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end
end

local function GetEllesmerePlayerFrame()
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    if unitFrames and unitFrames.player and unitFrames.player.visHideNoTarget ~= nil then
        return unitFrames.player.visHideNoTarget == true
    end
    return EnsureVisibilityDB().playerFrameHidden == true
end

local function SetEllesmereActionBars(state)
    EnsureVisibilityDB().actionBarsHidden = state == true
    local actionBars = GetEllesmereAddonProfile("EllesmereUIActionBars")
    if not actionBars then return end

    actionBars.mouseoverShowAll = state == true
    actionBars.bars = actionBars.bars or {}
    for key, settings in pairs(actionBars.bars) do
        if type(settings) == "table" then
            local visibility = settings.barVisibility or "always"
            local isEnabled = settings.enabled ~= false and visibility ~= "never" and settings.alwaysHidden ~= true
            if isEnabled then
                if state then
                    settings.barVisibility = "mouseover"
                    settings.mouseoverEnabled = true
                    settings.alwaysHidden = false
                    settings.combatHideEnabled = false
                    settings.combatShowEnabled = false
                    if settings._savedBarAlpha == nil then settings._savedBarAlpha = settings.mouseoverAlpha or 1 end
                    settings.mouseoverAlpha = 0
                elseif settings.barVisibility == "mouseover" then
                    settings.barVisibility = "always"
                    settings.mouseoverEnabled = false
                    settings.mouseoverAlpha = settings._savedBarAlpha or 1
                end
            elseif key == "PetBar" or key == "StanceBar" then
                settings.alwaysHidden = true
                settings.barVisibility = "never"
                settings.mouseoverEnabled = false
            end
        end
    end
end

local function GetEllesmereActionBars()
    local actionBars = GetEllesmereAddonProfile("EllesmereUIActionBars")
    if actionBars and actionBars.mouseoverShowAll ~= nil then
        return actionBars.mouseoverShowAll == true
    end
    return EnsureVisibilityDB().actionBarsHidden == true
end

local function SetEllesmereChatBackground(state)
    EnsureVisibilityDB().chatBackgroundHidden = state == true
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    if chat then
        chat.chat = chat.chat or {}
        chat.chat.bgAlpha = state and 0 or 0.65
        chat.chat.idleFadeStrength = state and 100 or 40
    end
end

local function GetEllesmereChatBackground()
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    if chat and chat.chat then
        return (chat.chat.bgAlpha or 0.65) <= 0.01 and (chat.chat.idleFadeStrength or 40) >= 100
    end
    return EnsureVisibilityDB().chatBackgroundHidden == true
end

local function SetEllesmereCDM(state)
    EnsureVisibilityDB().cdmFading = state == true
    local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) ~= "table" then return end

    local wanted = { cooldowns = true, utility = true, buffs = true }
    for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
        if type(bars[key]) == "table" then
            bars[key].barVisibility = "always"
            bars[key].visHideNoTarget = state == true
        end
    end
    for _, bar in ipairs(bars) do
        if type(bar) == "table" and wanted[bar.key] then
            bar.barVisibility = "always"
            bar.visHideNoTarget = state == true
        end
    end
end

local function GetEllesmereCDM()
    local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) == "table" then
        local seen = { cooldowns = false, utility = false, buffs = false }
        for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
            if type(bars[key]) == "table" then
                if bars[key].visHideNoTarget ~= true then return false end
                seen[key] = true
            end
        end
        for _, bar in ipairs(bars) do
            if type(bar) == "table" and seen[bar.key] ~= nil then
                if bar.visHideNoTarget ~= true then return false end
                seen[bar.key] = true
            end
        end
        for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
            if not seen[key] then return false end
        end
        return true
    end
    return EnsureVisibilityDB().cdmFading == true
end

local function SetEllesmereCompactUtilityAnchor(state)
    EnsureVisibilityDB().compactUtilityAnchor = state == true
    if state then
        local utility = nil
        local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
        local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
        if type(bars) == "table" then
            utility = type(bars.utility) == "table" and bars.utility or nil
            if not utility then
                for _, bar in ipairs(bars) do
                    if type(bar) == "table" and bar.key == "utility" then
                        utility = bar
                        break
                    end
                end
            end
        end
        if utility then
            utility.anchorTo = "none"
            utility.anchorPosition = utility.anchorPosition or "left"
            utility.anchorOffsetX = 0
            utility.anchorOffsetY = 0
        end
        if type(_G.EllesmereUIDB) == "table" and type(_G.EllesmereUIDB.unlockAnchors) == "table" then
            _G.EllesmereUIDB.unlockAnchors.CDM_utility = nil
        end
    end
    if addonTable.RefreshEllesmereCDMUtilityAnchor then
        addonTable.RefreshEllesmereCDMUtilityAnchor()
    end
end

local function GetEllesmereCompactUtilityAnchor()
    return EnsureVisibilityDB().compactUtilityAnchor == true
end

local function SetEllesmereSmartPlayerPetVisibility(state)
    EnsureVisibilityDB().smartPlayerPetVisibility = state == true
    if addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end
end

local function GetEllesmereSmartPlayerPetVisibility()
    return EnsureVisibilityDB().smartPlayerPetVisibility == true
end

local function SetEllesmereChatLineFade(state)
    EnsureVisibilityDB().chatLineFade = state == true
    if addonTable.RefreshEllesmereChatLineFade then
        addonTable.RefreshEllesmereChatLineFade()
    end
end

local function GetEllesmereChatLineFade()
    return EnsureVisibilityDB().chatLineFade == true
end

local function SetEllesmereCompactClassResource(state)
    EnsureVisibilityDB().compactClassResource = state == true
    if addonTable.RefreshEllesmereResourceAnchor then
        addonTable.RefreshEllesmereResourceAnchor()
    end
end

local function GetEllesmereCompactClassResource()
    return EnsureVisibilityDB().compactClassResource == true
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
    if IsEllesmereProvider() then
        SetEllesmerePlayerFrame(state)
        return
    end
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
    if IsEllesmereProvider() then
        return GetEllesmerePlayerFrame()
    end
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
    if IsEllesmereProvider() then
        SetEllesmereActionBars(state)
        return
    end
    if addonTable.SetActionBarsHidden then
        addonTable.SetActionBarsHidden(state)
    end
end

local function GetMouseover()
    if IsEllesmereProvider() then
        return GetEllesmereActionBars()
    end
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
    if IsEllesmereProvider() then
        SetEllesmereChatBackground(state)
        return
    end
    EnsureVisibilityDB().chatBackgroundHidden = state == true
    local E = GetElvUI()
    if E and E.db and E.db.chat then
        E.db.chat.panelBackdrop = state and "HIDEBOTH" or "SHOWBOTH"
        RefreshElvUIChat(E)
    end
end

local function GetChatBackgroundHidden()
    if IsEllesmereProvider() then
        return GetEllesmereChatBackground()
    end
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
    if IsEllesmereProvider() then
        SetEllesmereCDM(state)
        return
    end
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
    if IsEllesmereProvider() then
        return GetEllesmereCDM()
    end
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
    if IsEllesmereProvider() then
        SetEllesmereSmartPlayerPetVisibility(state)
        SetEllesmereCompactUtilityAnchor(state)
        SetEllesmereChatLineFade(state)
        SetEllesmereCompactClassResource(state)
    end
    EnsureVisibilityDB().allHidden = state == true
end

local function GetAllHidden()
    local baseState = GetUnitframes() and GetMouseover() and GetChatBackgroundHidden() and GetCDMFading()
    if IsEllesmereProvider() then
        return baseState and GetEllesmereSmartPlayerPetVisibility() and GetEllesmereCompactUtilityAnchor() and GetEllesmereChatLineFade() and GetEllesmereCompactClassResource()
    end
    return baseState
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
    d1:SetPoint("LEFT", lbl1, "RIGHT", 15, 0); d1:SetText(IsEllesmereProvider() and "- Sets player/pet Hide without Target." or "- Toggles ElvUI Player > Fader."); d1:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb1)

    local cb2, lbl2 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Action Bars|r", SetMouseover, GetMouseover)
    cb2:SetPoint("TOPLEFT", cb1, "BOTTOMLEFT", 0, -30)
    local d2 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d2:SetPoint("LEFT", lbl2, "RIGHT", 15, 0); d2:SetText("- Fades all action bars in together on mouseover."); d2:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb2)

    local cb3, lbl3 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Chat Background|r", SetChatBackgroundHidden, GetChatBackgroundHidden)
    cb3:SetPoint("TOPLEFT", cb2, "BOTTOMLEFT", 0, -30)
    local d3 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d3:SetPoint("LEFT", lbl3, "RIGHT", 15, 0); d3:SetText(IsEllesmereProvider() and "- Opacity 0, idle fade 100." or "- Sets ElvUI chat panels."); d3:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb3)

    local cb4, lbl4 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide CDM|r", SetCDMFading, GetCDMFading)
    cb4:SetPoint("TOPLEFT", cb3, "BOTTOMLEFT", 0, -30)
    local d4 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d4:SetPoint("LEFT", lbl4, "RIGHT", 15, 0); d4:SetText(IsEllesmereProvider() and "- Cooldowns hide without target." or "- Toggles Ayije CDM fading."); d4:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb4)

    if IsEllesmereProvider() then
        local cb5, lbl5 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Smart Player/Pet|r", SetEllesmereSmartPlayerPetVisibility, GetEllesmereSmartPlayerPetVisibility)
        cb5:SetPoint("TOPLEFT", cb4, "BOTTOMLEFT", 0, -30)
        local d5 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d5:SetPoint("LEFT", lbl5, "RIGHT", 15, 0); d5:SetText("- Shows both when either is injured."); d5:SetTextColor(0.6, 0.6, 0.6)
        table.insert(checkboxes, cb5)

        local cb6, lbl6 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Compact Utility CDs|r", SetEllesmereCompactUtilityAnchor, GetEllesmereCompactUtilityAnchor)
        cb6:SetPoint("TOPLEFT", cb5, "BOTTOMLEFT", 0, -30)
        local d6 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d6:SetPoint("LEFT", lbl6, "RIGHT", 15, 0); d6:SetText("- Anchors Utility CDM under bottom visible row of Cooldown CDM"); d6:SetTextColor(0.6, 0.6, 0.6)
        table.insert(checkboxes, cb6)

        local cb7, lbl7 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Chat Line Fade|r", SetEllesmereChatLineFade, GetEllesmereChatLineFade)
        cb7:SetPoint("TOPLEFT", cb6, "BOTTOMLEFT", 0, -30)
        local d7 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d7:SetPoint("LEFT", lbl7, "RIGHT", 15, 0); d7:SetText("- Uses Blizzard per-line chat fading."); d7:SetTextColor(0.6, 0.6, 0.6)
        table.insert(checkboxes, cb7)

        local cb8, lbl8 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Compact Resource|r", SetEllesmereCompactClassResource, GetEllesmereCompactClassResource)
        cb8:SetPoint("TOPLEFT", cb7, "BOTTOMLEFT", 0, -30)
        local d8 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        d8:SetPoint("LEFT", lbl8, "RIGHT", 15, 0); d8:SetText("- Anchors class resource above Essential CDM when no power bar."); d8:SetTextColor(0.6, 0.6, 0.6)
        table.insert(checkboxes, cb8)
    end

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
