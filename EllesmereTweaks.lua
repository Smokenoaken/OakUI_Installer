local addonName, addonTable = ...

local function IsEllesmereProvider()
    return addonTable.Profiles and addonTable.Profiles.BASE_UI_PROVIDER == "Ellesmere"
end

local function EnsureVisibilityDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.visibility then OakUI_DB.visibility = {} end
    return OakUI_DB.visibility
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

local function GetEllesmereChatConfig()
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    return chat and chat.chat
end

local function UnitIsInjured(unit)
    if not UnitExists(unit) then return false end
    local ok, injured = pcall(function()
        local maxHealth = UnitHealthMax(unit) or 0
        local health = UnitHealth(unit) or maxHealth
        return maxHealth > 0 and health < maxHealth
    end)
    return ok and injured == true
end

local playerHealthBelowMax = false
local playerHealthStableTimer
local lastPlayerHealthEventTime = 0
local HEALTH_STABLE_DURATION = 3

local function SetPlayerHealthChanging()
    local wasBelowMax = playerHealthBelowMax
    playerHealthBelowMax = true
    lastPlayerHealthEventTime = GetTime and GetTime() or 0

    if not wasBelowMax and addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end

    if playerHealthStableTimer or not C_Timer or not C_Timer.NewTicker then return end
    playerHealthStableTimer = C_Timer.NewTicker(1, function()
        if InCombatLockdown and InCombatLockdown() then return end
        local now = GetTime and GetTime() or 0
        if now - lastPlayerHealthEventTime < HEALTH_STABLE_DURATION then return end

        playerHealthStableTimer:Cancel()
        playerHealthStableTimer = nil
        playerHealthBelowMax = false
        if addonTable.RefreshEllesmereVisibilityTweaks then
            addonTable.RefreshEllesmereVisibilityTweaks()
        end
    end)
end

local function PlayerHealthBelowMax()
    return playerHealthBelowMax or UnitIsInjured("player")
end

local ellesmereUnitFrameVisibilityHooked
local applyingEllesmereVisibility
local playerVisibilityWatchFrame

local function SetFrameVisible(frame, visible)
    if not frame then return end
    frame:SetAlpha(visible and 1 or 0)
end

local function SetPetFrameVisible(frame, visible)
    if not frame then return end
    SetFrameVisible(frame, visible)
    frame.dfPetHidden = not visible or nil
    if not InCombatLockdown or not InCombatLockdown() then
        if visible then
            if frame.Show then frame:Show() end
        else
            if frame.Hide then frame:Hide() end
        end
    end
end

local function GetDandersPlayerPetFrame()
    local DF = _G.DandersFrames
    if DF and DF.petFrames and DF.petFrames.player then
        return DF.petFrames.player
    end
    return _G.DandersFrames_Pet_Pet
end

local function PlayerPetVisibilityEnabled()
    if not IsEllesmereProvider() then return false end
    local db = EnsureVisibilityDB()
    if db.smartPlayerPetVisibility ~= true and db.showPlayerWhenInjured ~= true and db.showPlayerInParty ~= true then return false end
    if EnsureVisibilityDB().playerFrameHidden == true then return true end

    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    local player = unitFrames and unitFrames.player
    return player and player.visHideNoTarget == true
end

local function PlayerIsInGroup()
    return (type(IsInGroup) == "function" and IsInGroup()) or (type(IsInRaid) == "function" and IsInRaid())
end

local function GetEllesmerePlayerVisibilityTarget()
    local frame = _G.EllesmereUIUnitFrames_Player
    return frame and (frame._visWrap or frame)
end

local function HookEllesmereUnitFrameVisibility()
    if ellesmereUnitFrameVisibilityHooked then return end
    local ns = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    if not ns or type(ns.UpdateFrameVisibility) ~= "function" or not hooksecurefunc then return end

    ellesmereUnitFrameVisibilityHooked = true
    hooksecurefunc(ns, "UpdateFrameVisibility", function()
        if applyingEllesmereVisibility then return end
        C_Timer.After(0, function()
            if addonTable.RefreshEllesmereVisibilityTweaks then
                addonTable.RefreshEllesmereVisibilityTweaks(true)
            end
        end)
    end)
end

local function ShouldForcePlayerFrameShown()
    if not PlayerPetVisibilityEnabled() then return false end
    local db = EnsureVisibilityDB()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if (db.smartPlayerPetVisibility == true or db.showPlayerWhenInjured == true) and PlayerHealthBelowMax() then return true end
    if db.showPlayerInParty == true and PlayerIsInGroup() then return true end
    if db.smartPlayerPetVisibility == true and UnitIsInjured("pet") then return true end
    return false
end

local function ApplyPlayerFrameVisibilityOverride()
    local target = GetEllesmerePlayerVisibilityTarget()
    if not target then return end
    if ShouldForcePlayerFrameShown() then
        target:SetAlpha(1)
    end
end

local function UpdatePlayerVisibilityWatcher()
    if not playerVisibilityWatchFrame then
        playerVisibilityWatchFrame = CreateFrame("Frame")
        playerVisibilityWatchFrame.elapsed = 0
        playerVisibilityWatchFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed < 0.05 then return end
            self.elapsed = 0
            if ShouldForcePlayerFrameShown() then
                ApplyPlayerFrameVisibilityOverride()
            else
                self:Hide()
            end
        end)
    end

    if ShouldForcePlayerFrameShown() then
        playerVisibilityWatchFrame:Show()
    else
        playerVisibilityWatchFrame:Hide()
    end
end

function addonTable.RefreshEllesmereVisibilityTweaks()
    HookEllesmereUnitFrameVisibility()
    if not PlayerPetVisibilityEnabled() then
        local playerFrame = _G.EllesmereUIUnitFrames_Player
        SetFrameVisible(playerFrame and playerFrame._visWrap or playerFrame, true)
        SetFrameVisible(_G.EllesmereUIUnitFrames_Pet, true)
        SetPetFrameVisible(GetDandersPlayerPetFrame(), true)
        UpdatePlayerVisibilityWatcher()
        return
    end

    local db = EnsureVisibilityDB()
    local hasTarget = UnitExists("target")
    if InCombatLockdown and InCombatLockdown() then
        ApplyPlayerFrameVisibilityOverride()
        SetPetFrameVisible(_G.EllesmereUIUnitFrames_Pet, UnitExists("pet"))
        SetPetFrameVisible(GetDandersPlayerPetFrame(), UnitExists("pet"))
        UpdatePlayerVisibilityWatcher()
        return
    end

    local showPlayerForInjury = (db.smartPlayerPetVisibility == true or db.showPlayerWhenInjured == true) and PlayerHealthBelowMax()
    local showPlayerForParty = db.showPlayerInParty == true and PlayerIsInGroup()
    local showPetForInjury = db.smartPlayerPetVisibility == true and UnitIsInjured("pet")
    local shouldShowPlayer = hasTarget or showPlayerForInjury or showPlayerForParty or showPetForInjury
    local shouldShowPet = hasTarget or showPetForInjury or showPlayerForInjury
    local playerFrame = _G.EllesmereUIUnitFrames_Player
    local petFrame = _G.EllesmereUIUnitFrames_Pet
    local dandersPetFrame = GetDandersPlayerPetFrame()

    local ns = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    if ns and type(ns.UpdateFrameVisibility) == "function" and not applyingEllesmereVisibility then
        applyingEllesmereVisibility = true
        pcall(ns.UpdateFrameVisibility)
        applyingEllesmereVisibility = nil
    end

    SetFrameVisible(playerFrame and playerFrame._visWrap or playerFrame, shouldShowPlayer)
    SetPetFrameVisible(petFrame, shouldShowPet and UnitExists("pet"))
    SetPetFrameVisible(dandersPetFrame, shouldShowPet and UnitExists("pet"))
    UpdatePlayerVisibilityWatcher()
end

local function FindCDMBarData(key)
    local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) ~= "table" then return nil end
    if type(bars[key]) == "table" then return bars[key] end
    for _, bar in ipairs(bars) do
        if type(bar) == "table" and bar.key == key then
            return bar
        end
    end
    return nil
end

local function DisableEllesmereUtilityAnchor()
    local utilityData = FindCDMBarData("utility")
    if utilityData then
        utilityData.anchorTo = "none"
        utilityData.anchorPosition = utilityData.anchorPosition or "left"
        utilityData.anchorOffsetX = 0
        utilityData.anchorOffsetY = 0
    end

    if type(_G.EllesmereUIDB) == "table" and type(_G.EllesmereUIDB.unlockAnchors) == "table" then
        _G.EllesmereUIDB.unlockAnchors.CDM_utility = nil
    end
end

local chatFadeHooked = {}
local originalResetIdleTimer
local chatFadeApplied

local function GetEllesmereChatAddon()
    if _G.EllesmereUI and _G.EllesmereUI.Lite and _G.EllesmereUI.Lite.GetAddon then
        local addon = _G.EllesmereUI.Lite.GetAddon("EllesmereUIChat", true)
        return addon and addon.ECHAT
    end
    return nil
end

local function ChatLineFadeEnabled()
    return IsEllesmereProvider() and EnsureVisibilityDB().chatLineFade == true
end

local function GetChatLineFadeDelay()
    local cfg = GetEllesmereChatConfig()
    return (cfg and cfg.idleFadeDelay) or 15
end

local function ApplyChatLineFadeToFrame(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end

    if ChatLineFadeEnabled() then
        chatFrame:SetAlpha(1)
        chatFrame:SetFading(true)
        chatFrame:SetTimeVisible(GetChatLineFadeDelay())
        if chatFrame.SetFadeDuration then
            chatFrame:SetFadeDuration(0.35)
        end
    else
        chatFrame:SetFading(false)
    end

    if not chatFadeHooked[chatFrame] then
        chatFadeHooked[chatFrame] = true
        if hooksecurefunc then
            hooksecurefunc(chatFrame, "SetFading", function(self, fading)
                if ChatLineFadeEnabled() and fading == false then
                    C_Timer.After(0, function()
                        ApplyChatLineFadeToFrame(self)
                    end)
                end
            end)
            hooksecurefunc(chatFrame, "AddMessage", function(self)
                if ChatLineFadeEnabled() then
                    C_Timer.After(0, function()
                        ApplyChatLineFadeToFrame(self)
                    end)
                end
            end)
        end
    end
end

local function ApplyChatLineFade()
    local enabled = ChatLineFadeEnabled()
    for i = 1, NUM_CHAT_WINDOWS or 20 do
        ApplyChatLineFadeToFrame(_G["ChatFrame" .. i])
    end

    local ECHAT = GetEllesmereChatAddon()
    if ECHAT and type(ECHAT.ResetIdleTimer) == "function" and not originalResetIdleTimer then
        originalResetIdleTimer = ECHAT.ResetIdleTimer
    end

    if ECHAT and originalResetIdleTimer then
        if enabled then
            ECHAT.ResetIdleTimer = function()
                if ECHAT.SetIdleFadeAlpha then
                    ECHAT.SetIdleFadeAlpha(1)
                end
                for i = 1, NUM_CHAT_WINDOWS or 20 do
                    local cf = _G["ChatFrame" .. i]
                    if cf then cf:SetAlpha(1) end
                end
            end
            if ECHAT.SetIdleFadeAlpha then
                ECHAT.SetIdleFadeAlpha(1)
            end
        elseif ECHAT.ResetIdleTimer ~= originalResetIdleTimer then
            ECHAT.ResetIdleTimer = originalResetIdleTimer
        end
    end
end

function addonTable.RefreshEllesmereChatLineFade()
    if not ChatLineFadeEnabled() and not chatFadeApplied then return end
    ApplyChatLineFade()
    chatFadeApplied = ChatLineFadeEnabled()
end

local function GetCDMFrame(key)
    if type(_G._ECME_GetBarFrame) == "function" then
        local frame = _G._ECME_GetBarFrame(key)
        if frame then return frame end
    end
    if key == "cooldowns" then return _G.EssentialCooldownViewer end
    if key == "utility" then return _G.UtilityCooldownViewer end
    return nil
end

local function GetBlizzardCDMViewer(key)
    if key == "cooldowns" then return _G.EssentialCooldownViewer end
    if key == "utility" then return _G.UtilityCooldownViewer end
    if key == "buffs" then return _G.BuffIconCooldownViewer end
    return nil
end

local function GetCDMIcons(key)
    local ns = type(_G.EllesmereUICooldownManager) == "table" and _G.EllesmereUICooldownManager
    if ns and type(ns.GetCDMBarIcons) == "function" then
        local icons = ns.GetCDMBarIcons(key)
        if type(icons) == "table" then return icons end
    end
    return nil
end

local function CollectVisibleIcons(key)
    local icons = GetCDMIcons(key)
    local visible = {}
    local seen = {}
    local function AddIcon(icon)
        if icon and not seen[icon] and icon.IsShown and icon:IsShown() and icon.GetCenter and icon:GetCenter() and icon.GetBottom and icon:GetBottom() then
            seen[icon] = true
            visible[#visible + 1] = icon
        end
    end

    if type(icons) == "table" then
        for _, icon in ipairs(icons) do
            AddIcon(icon)
        end
    end
    if #visible > 0 then return visible end

    for _, frame in ipairs({ GetCDMFrame(key), GetBlizzardCDMViewer(key) }) do
        if frame and frame.GetChildren then
            for i = 1, frame:GetNumChildren() do
                local child = select(i, frame:GetChildren())
                if child and child.GetWidth and child.GetHeight and child:GetWidth() > 8 and child:GetHeight() > 8 then
                    AddIcon(child)
                end
            end
        end
    end

    return visible
end

local function CollectAllVisibleChildren(frame, visible, seen)
    if not frame or not frame.GetChildren then return end
    for i = 1, frame:GetNumChildren() do
        local child = select(i, frame:GetChildren())
        if child and not seen[child] then
            seen[child] = true
            if child.IsShown and child:IsShown() and child.GetCenter and child:GetCenter() and child.GetBottom and child:GetBottom() and child.GetWidth and child:GetWidth() > 8 and child.GetHeight and child:GetHeight() > 8 then
                visible[#visible + 1] = child
            end
            CollectAllVisibleChildren(child, visible, seen)
        end
    end
end

local function CollectViewerIconDescendants(key)
    local visible, seen = {}, {}
    CollectAllVisibleChildren(GetBlizzardCDMViewer(key), visible, seen)
    return visible
end

local function GetVisibleCooldownIcons()
    local icons = CollectVisibleIcons("cooldowns")
    if #icons > 0 then return icons end
    return CollectViewerIconDescendants("cooldowns")
end

local function GetLowestVisibleRowBottom(icons)
    local lowestBottom
    for _, icon in ipairs(icons) do
        local bottom = icon:GetBottom()
        if bottom and (not lowestBottom or bottom < lowestBottom) then
            lowestBottom = bottom
        end
    end
    return lowestBottom
end

local function GetUtilityFrame()
    return GetCDMFrame("utility") or GetBlizzardCDMViewer("utility")
end

local utilityWasCompacted
local utilitySavedPoint
local utilitySavedViewerPoint
local anchor = CreateFrame("Frame", "OakUI_EllesmereCDMUtilityAnchor", UIParent)
anchor:SetSize(1, 1)

local function MoveUtilityFrameTo(frame, centerX, bottomY, gap)
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, bottomY - gap)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", anchor, "CENTER", 0, 0)

    local viewer = GetBlizzardCDMViewer("utility")
    if viewer and viewer ~= frame then
        viewer:ClearAllPoints()
        viewer:SetPoint("TOP", anchor, "CENTER", 0, 0)
    end
end

local function RestoreUtilityViewerPoint()
    local frame = GetBlizzardCDMViewer("utility")
    if not utilityWasCompacted or not frame or not utilitySavedViewerPoint or not utilitySavedViewerPoint[1] then return end
    frame:ClearAllPoints()
    frame:SetPoint(unpack(utilitySavedViewerPoint))
end

local function SaveUtilityViewerPoint()
    local frame = GetBlizzardCDMViewer("utility")
    if utilitySavedViewerPoint or not frame or frame:GetNumPoints() == 0 then return end
    utilitySavedViewerPoint = { frame:GetPoint(1) }
end

local function SaveUtilityPoint(frame)
    if utilitySavedPoint or not frame or frame:GetNumPoints() == 0 then return end
    utilitySavedPoint = { frame:GetPoint(1) }
    SaveUtilityViewerPoint()
end

local function RestoreUtilityPoint(frame)
    if not utilityWasCompacted or not frame then return end
    utilityWasCompacted = nil
    if utilitySavedPoint and utilitySavedPoint[1] then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(utilitySavedPoint))
    end
    RestoreUtilityViewerPoint()
end

local lastUtilitySignature

function addonTable.RefreshEllesmereCDMUtilityAnchor(force)
    if InCombatLockdown and InCombatLockdown() then return end

    local utilityFrame = GetUtilityFrame()
    local cooldownFrame = GetCDMFrame("cooldowns") or GetBlizzardCDMViewer("cooldowns")
    if not utilityFrame or not cooldownFrame then return end

    local db = EnsureVisibilityDB()
    local cooldownData = FindCDMBarData("cooldowns")
    local numRows = cooldownData and cooldownData.numRows or 2
    if not IsEllesmereProvider() or db.compactUtilityAnchor ~= true or numRows ~= 2 then
        RestoreUtilityPoint(utilityFrame)
        return
    end
    DisableEllesmereUtilityAnchor()

    local icons = GetVisibleCooldownIcons()
    local lowestBottom = GetLowestVisibleRowBottom(icons)
    if not lowestBottom then
        lastUtilitySignature = nil
        RestoreUtilityPoint(utilityFrame)
        return
    end

    local centerX = cooldownFrame:GetCenter()
    if not centerX then return end

    local utilityData = FindCDMBarData("utility")
    local gap = (utilityData and utilityData.spacing) or (cooldownData and cooldownData.spacing) or 2
    local signature = table.concat({ centerX, lowestBottom, gap, numRows }, ":")
    if not force and utilityWasCompacted and signature == lastUtilitySignature then return end

    SaveUtilityPoint(utilityFrame)
    MoveUtilityFrameTo(utilityFrame, centerX, lowestBottom, gap)
    lastUtilitySignature = signature
    utilityWasCompacted = true
end

local resourceWasCompacted
local resourceSavedPoint

local function GetResourceBarsProfile()
    if type(_G._ERB_AceDB) == "table" and type(_G._ERB_AceDB.profile) == "table" then
        return _G._ERB_AceDB.profile
    end
    return GetEllesmereAddonProfile("EllesmereUIResourceBars")
end

local function DisableEllesmereClassResourceAnchor()
    local profile = GetResourceBarsProfile()
    local secondary = profile and profile.secondary
    if type(secondary) == "table" then
        secondary.anchorTo = "none"
        secondary.anchorPosition = secondary.anchorPosition or "center"
        secondary.anchorOffsetX = 0
        secondary.anchorOffsetY = 0
        secondary.offsetX = secondary.offsetX or 0
    end

    if type(_G.EllesmereUIDB) == "table" and type(_G.EllesmereUIDB.unlockAnchors) == "table" then
        _G.EllesmereUIDB.unlockAnchors.ERB_ClassResource = nil
    end
end

local function HasClassResource()
    if type(_G._ERB_GetSecondaryResource) ~= "function" then
        return _G.ERB_SecondaryFrame ~= nil
    end
    local ok, resource = pcall(_G._ERB_GetSecondaryResource)
    return ok and resource ~= nil
end

local function HasVisiblePowerBar()
    if type(_G._ERB_GetPrimaryPowerType) == "function" then
        local ok, powerType = pcall(_G._ERB_GetPrimaryPowerType)
        if ok then return powerType ~= nil end
    end

    local frame = _G.ERB_PrimaryBar
    if not frame then return false end
    if frame.IsShown and not frame:IsShown() then return false end
    if frame.GetAlpha then
        local ok, alpha = pcall(frame.GetAlpha, frame)
        if ok and alpha and alpha <= 0.01 then return false end
    end
    if frame.GetHeight and frame:GetHeight() <= 1 then return false end
    return true
end

local function SaveResourcePoint(frame)
    if resourceSavedPoint or not frame or frame:GetNumPoints() == 0 then return end
    resourceSavedPoint = { frame:GetPoint(1) }
end

local function RestoreResourcePoint(frame)
    if not resourceWasCompacted or not frame then return end
    resourceWasCompacted = nil
    if resourceSavedPoint and resourceSavedPoint[1] then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(resourceSavedPoint))
    end
end

local lastResourceSignature

function addonTable.RefreshEllesmereResourceAnchor(force)
    if InCombatLockdown and InCombatLockdown() then return end

    local resourceFrame = _G.ERB_SecondaryFrame
    local cooldownFrame = GetCDMFrame("cooldowns") or GetBlizzardCDMViewer("cooldowns")
    if not resourceFrame then return end

    local db = EnsureVisibilityDB()
    if not IsEllesmereProvider() or db.compactClassResource ~= true or not cooldownFrame or not HasClassResource() or HasVisiblePowerBar() then
        lastResourceSignature = nil
        RestoreResourcePoint(resourceFrame)
        return
    end

    local signature
    if cooldownFrame.GetTop and cooldownFrame.GetCenter then
        signature = table.concat({ cooldownFrame:GetCenter() or 0, cooldownFrame:GetTop() or 0 }, ":")
        if not force and resourceWasCompacted and signature == lastResourceSignature then return end
    end

    DisableEllesmereClassResourceAnchor()
    SaveResourcePoint(resourceFrame)
    resourceFrame:ClearAllPoints()
    resourceFrame:SetPoint("BOTTOM", cooldownFrame, "TOP", 0, 2)
    lastResourceSignature = signature
    resourceWasCompacted = true
end

local frame = CreateFrame("Frame")
local pending = {}
local lastRefresh = {}

local function ScheduleRefresh(key, delay, func, minInterval)
    if pending[key] then return end
    local now = GetTime and GetTime() or 0
    if minInterval and lastRefresh[key] then
        local remaining = minInterval - (now - lastRefresh[key])
        if remaining > 0 then
            delay = math.max(delay or 0, remaining)
        end
    end
    pending[key] = true
    C_Timer.After(delay or 0, function()
        pending[key] = nil
        lastRefresh[key] = GetTime and GetTime() or 0
        func()
    end)
end

local function ScheduleLayoutRefresh()
    ScheduleRefresh("visibility", 0, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("visibilityInit", 0.5, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("visibilityLate", 1.5, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("utility", 0.1, function() addonTable.RefreshEllesmereCDMUtilityAnchor(true) end, 0.75)
    ScheduleRefresh("resource", 0.15, function() addonTable.RefreshEllesmereResourceAnchor(true) end, 0.75)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_POWER_FREQUENT")
frame:RegisterEvent("UNIT_MAXPOWER")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        if unit ~= "player" and unit ~= "pet" then return end
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ScheduleLayoutRefresh()
        ScheduleRefresh("chat", 0.1, addonTable.RefreshEllesmereChatLineFade, 1)
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" then
        if event == "UNIT_HEALTH" and unit == "player" then
            SetPlayerHealthChanging()
        end
        ScheduleRefresh("visibility", 0, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        ScheduleRefresh("utility", 0.1, function() addonTable.RefreshEllesmereCDMUtilityAnchor(true) end, 0.75)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
        ScheduleRefresh("resource", 0.15, function() addonTable.RefreshEllesmereResourceAnchor(true) end, 0.75)
    end
end)
