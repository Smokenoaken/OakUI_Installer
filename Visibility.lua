local addonName, addonTable = ...

local _, playerClass = UnitClass("player")
local classColor = C_ClassColor.GetClassColor(playerClass)
local r, g, b = classColor.r, classColor.g, classColor.b
local cWrap = "|c" .. classColor:GenerateHexColor()

local function MakeVisibilityCheckbox(parent, text, updateFunc, getStateFunc, skipReloadPrompt)
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

        if skipReloadPrompt then
            return
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

local oakErrorFrameOriginalHandler
local oakErrorFrameHooked
local OAK_ALLOWED_ERROR_MESSAGES = {}

local function BuildAllowedErrorMessages()
    for key in pairs(OAK_ALLOWED_ERROR_MESSAGES) do
        OAK_ALLOWED_ERROR_MESSAGES[key] = nil
    end
    local allowed = {
        "ERR_INV_FULL",
        "ERR_QUEST_LOG_FULL",
        "ERR_RAID_GROUP_ONLY",
        "ERR_PARTY_LFG_BOOT_LIMIT",
        "ERR_PARTY_LFG_BOOT_DUNGEON_COMPLETE",
        "ERR_PARTY_LFG_BOOT_IN_COMBAT",
        "ERR_PARTY_LFG_BOOT_IN_PROGRESS",
        "ERR_PARTY_LFG_BOOT_LOOT_ROLLS",
        "ERR_PARTY_LFG_TELEPORT_IN_COMBAT",
        "ERR_PET_SPELL_DEAD",
        "ERR_PLAYER_DEAD",
        "SPELL_FAILED_TARGET_NO_POCKETS",
        "ERR_ALREADY_PICKPOCKETED",
    }
    for _, globalName in ipairs(allowed) do
        local message = _G[globalName]
        if type(message) == "string" then
            OAK_ALLOWED_ERROR_MESSAGES[message] = true
        end
    end
end

local function IsAllowedErrorMessage(message)
    if type(message) ~= "string" then return false end
    if not next(OAK_ALLOWED_ERROR_MESSAGES) then
        BuildAllowedErrorMessages()
    end
    if OAK_ALLOWED_ERROR_MESSAGES[message] then return true end

    if type(ERR_PARTY_LFG_BOOT_NOT_ELIGIBLE_S) == "string" then
        local prefix = ERR_PARTY_LFG_BOOT_NOT_ELIGIBLE_S:match("^(.-)%%s")
        if prefix and prefix ~= "" and message:find(prefix, 1, true) then
            return true
        end
    end

    return false
end

local function SetErrorMessagesHidden(state)
    local db = EnsureVisibilityDB()
    db.errorMessagesHidden = state == true

    local frame = _G.UIErrorsFrame
    if not frame or type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function" then return end

    if state then
        if not oakErrorFrameHooked then
            oakErrorFrameOriginalHandler = frame:GetScript("OnEvent")
            oakErrorFrameHooked = true
        end
        frame:SetScript("OnEvent", function(self, event, id, message, ...)
            if event == "UI_ERROR_MESSAGE" and not IsAllowedErrorMessage(message) then
                if self.Clear then self:Clear() end
                return
            end
            if oakErrorFrameOriginalHandler then
                return oakErrorFrameOriginalHandler(self, event, id, message, ...)
            end
        end)
        if frame.Clear then frame:Clear() end
    elseif oakErrorFrameHooked then
        frame:SetScript("OnEvent", oakErrorFrameOriginalHandler)
        oakErrorFrameHooked = false
        oakErrorFrameOriginalHandler = nil
    end
end

local function GetErrorMessagesHidden()
    return EnsureVisibilityDB().errorMessagesHidden == true
end

function addonTable.ApplyOakErrorMessageVisibility()
    SetErrorMessagesHidden(GetErrorMessagesHidden())
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

local function GetEllesmereUnitHideNoTarget(unit)
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    local settings = unitFrames and unitFrames[unit]
    if type(settings) ~= "table" or settings.visHideNoTarget == nil then return nil end
    return settings.visHideNoTarget == true
end

local ELLESMERE_VISIBILITY_OPTION_KEYS = {
    "visOnlyInstances",
    "visHideHousing",
    "visHideMounted",
    "visHideNoTarget",
    "visHideNoEnemy",
}

local function SetEllesmereHideNoTargetOption(settings, state)
    if type(settings) ~= "table" then return end
    for _, key in ipairs(ELLESMERE_VISIBILITY_OPTION_KEYS) do
        settings[key] = false
    end
    settings.visHideNoTarget = state == true
end

local function RefreshEllesmereOptionsPage()
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshPage) == "function" then
        pcall(_G.EllesmereUI.RefreshPage, _G.EllesmereUI)
    end
end

local OAK_BORDER_NIL = "__OAKUI_NIL__"
local OAK_RESOURCE_BORDER_FIELDS = {
    "borderSize",
    "borderR", "borderG", "borderB", "borderA",
    "borderTexture", "borderTextureOffset", "borderTextureOffsetY",
    "borderTextureShiftX", "borderTextureShiftY", "borderBehind",
}
local OAK_UNIT_BORDER_FIELDS = {
    "borderSize", "borderColor", "borderAlpha", "borderTexture", "borderBehind",
    "borderTextureOffset", "borderTextureOffsetY", "borderTextureShiftX", "borderTextureShiftY",
}
local OAK_DAMAGE_METER_BORDER_FIELDS = {
    "borderSize",
    "borderR", "borderG", "borderB", "borderA",
    "borderTexture", "borderTextureOffset", "borderTextureOffsetY",
    "borderTextureShiftX", "borderTextureShiftY",
}
local OAK_TRACKING_BAR_BORDER_FIELDS = {
    "borderSize",
    "borderR", "borderG", "borderB", "borderA",
    "borderClassColor", "borderTexture", "borderTextureOffset", "borderTextureOffsetY",
    "borderTextureShiftX", "borderTextureShiftY", "borderBehind", "borderThickness",
}
local OAK_RESOURCE_BORDER_KEYS = { "health", "primary", "secondary", "castBar", "totemBar" }
local OAK_UNIT_FRAME_KEYS = { "player", "target", "targettarget", "pet", "totPet", "focus", "focustarget", "boss" }

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return copy
end

local function GetActiveEllesmereProfileName(profileName)
    if profileName and profileName ~= "" then return profileName end
    if type(_G.EllesmereUIDB) ~= "table" then return nil end
    return _G.EllesmereUIDB.activeProfile
end

local function GetOakRoundThinBorderKey()
    if addonTable.RegisterOakMedia then
        addonTable.RegisterOakMedia()
    elseif addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end

    local mediaName = addonTable.OAK_ROUND_THIN_BORDER_NAME or "OakUI Round Thin"
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Fetch and LSM:Fetch("border", mediaName, true) then
        return "sm:" .. mediaName
    end
    return addonTable.OAK_ROUND_THIN_BORDER_PATH or "Interface\\AddOns\\OakUI_Installer\\Media\\Borders\\OakRoundThinBorder.png"
end

local function GetFrameChildrenSafe(frame)
    if not frame or type(frame.GetChildren) ~= "function" then return nil end
    local ok, children = pcall(function()
        return { frame:GetChildren() }
    end)
    if ok then return children end
    return nil
end

local function CallFrameMethodSafe(frame, methodName)
    if not frame or type(frame[methodName]) ~= "function" then return nil end
    local ok, result = pcall(frame[methodName], frame)
    if ok then return result end
    return nil
end

local function GetFrameNameSafe(frame)
    return CallFrameMethodSafe(frame, "GetName")
end

local function GetFrameParentSafe(frame)
    return CallFrameMethodSafe(frame, "GetParent")
end

local function GetFrameLevelSafe(frame)
    return CallFrameMethodSafe(frame, "GetFrameLevel")
end

local function EnsureOakRoundThinRenderer()
    if addonTable.RegisterOakMedia then
        addonTable.RegisterOakMedia()
    elseif addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end
    if addonTable.RegisterOakRoundThinBorderRenderer then
        addonTable.RegisterOakRoundThinBorderRenderer()
    end
end

local function SaveBorderFields(backup, settings, fields)
    if type(settings) ~= "table" or type(fields) ~= "table" or type(backup) ~= "table" then return end
    for _, field in ipairs(fields) do
        local value = settings[field]
        backup[field] = value == nil and OAK_BORDER_NIL or DeepCopy(value)
    end
end

local function RestoreBorderFields(backup, settings, fields)
    if type(settings) ~= "table" or type(fields) ~= "table" then return end
    if type(backup) ~= "table" then return end
    for _, field in ipairs(fields) do
        local value = backup[field]
        if value == OAK_BORDER_NIL then
            settings[field] = nil
        elseif value ~= nil then
            settings[field] = DeepCopy(value)
        else
            settings[field] = nil
        end
    end
    return true
end

local function IsOakRoundThinBorderValue(value)
    if not value or value == "" then return false end
    if addonTable.IsOakRoundThinBorderKey and addonTable.IsOakRoundThinBorderKey(value) then
        return true
    end
    local mediaName = addonTable.OAK_ROUND_THIN_BORDER_NAME or "OakUI Round Thin"
    local mediaPath = addonTable.OAK_ROUND_THIN_BORDER_PATH or "Interface\\AddOns\\OakUI_Installer\\Media\\Borders\\OakRoundThinBorder.png"
    return value == mediaName or value == ("sm:" .. mediaName) or value == mediaPath
end

local function RestoreBorderFieldsOrFallback(backup, settings, fields, fallbackFunc)
    RestoreBorderFields(backup, settings, fields)
    if fallbackFunc and type(settings) == "table" and IsOakRoundThinBorderValue(settings.borderTexture) then
        fallbackFunc(settings)
    end
end

local function ApplyResourceRoundThin(settings, borderKey)
    if type(settings) ~= "table" then return end
    settings.borderSize = settings.borderSize and math.max(settings.borderSize, 1) or 1
    settings.borderR, settings.borderG, settings.borderB, settings.borderA = 0, 0, 0, 1
    settings.borderTexture = borderKey
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
    settings.borderBehind = false
end

local function FallbackResourceBorder(settings)
    if type(settings) ~= "table" then return end
    settings.borderSize = settings.borderSize and math.max(settings.borderSize, 1) or 1
    settings.borderR, settings.borderG, settings.borderB, settings.borderA = 0, 0, 0, 1
    settings.borderTexture = "solid"
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
    settings.borderBehind = false
end

local function ApplyUnitRoundThin(settings, borderKey)
    if type(settings) ~= "table" then return end
    settings.borderSize = settings.borderSize and math.max(settings.borderSize, 1) or 1
    settings.borderColor = { r = 0, g = 0, b = 0 }
    settings.borderAlpha = 1
    settings.borderTexture = borderKey
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
    settings.borderBehind = false
end

local function FallbackUnitBorder(settings)
    if type(settings) ~= "table" then return end
    settings.borderSize = settings.borderSize and math.max(settings.borderSize, 1) or 1
    settings.borderColor = settings.borderColor or { r = 0, g = 0, b = 0 }
    settings.borderAlpha = settings.borderAlpha or 1
    settings.borderTexture = "solid"
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
    settings.borderBehind = false
end

local function ApplyDamageMeterRoundThin(settings, borderKey)
    if type(settings) ~= "table" then return end
    settings.borderSize = settings.borderSize and math.max(settings.borderSize, 1) or 1
    settings.borderR, settings.borderG, settings.borderB, settings.borderA = 0, 0, 0, 1
    settings.borderTexture = borderKey
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
end

local function FallbackDamageMeterBorder(settings)
    if type(settings) ~= "table" then return end
    settings.borderSize = 0
    settings.borderR, settings.borderG, settings.borderB, settings.borderA = 0, 0, 0, 1
    settings.borderTexture = "solid"
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
end

local function ApplyTrackingBarRoundThin(settings, borderKey)
    if type(settings) ~= "table" then return end
    settings.borderSize = 1
    settings.borderR, settings.borderG, settings.borderB, settings.borderA = 0, 0, 0, 1
    settings.borderClassColor = false
    settings.borderTexture = borderKey
    settings.borderTextureOffset = 0
    settings.borderTextureOffsetY = 0
    settings.borderTextureShiftX = nil
    settings.borderTextureShiftY = nil
    settings.borderBehind = false
    settings.borderThickness = "thin"
end

local function FallbackTrackingBarBorder(settings)
    FallbackResourceBorder(settings)
    settings.borderClassColor = false
    settings.borderThickness = "thin"
end

local function RefreshEllesmereBorderTargets()
    if _G._EUF_ReloadFrames then pcall(_G._EUF_ReloadFrames) end
    if _G._ERB_Apply then pcall(_G._ERB_Apply) end
    if _G._ERF_RefreshAll then pcall(_G._ERF_RefreshAll) end

    local ERF = type(_G.EllesmereUIRaidFrames) == "table" and _G.EllesmereUIRaidFrames
    if ERF then
        if type(ERF.ReloadFrames) == "function" then
            pcall(ERF.ReloadFrames)
        elseif type(ERF.UpdateAllFrames) == "function" then
            pcall(ERF.UpdateAllFrames, ERF)
        end
    end
    RefreshEllesmereOptionsPage()
end

local function ApplyEllesmereRoundThinBorders(state, profileName, skipRefresh)
    local db = EnsureVisibilityDB()
    db.roundThinBorders = state == true

    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    local profile = activeProfile and profiles and profiles[activeProfile]
    if type(profile) ~= "table" then return end

    profile.addons = profile.addons or {}
    db.roundThinBorderBackups = db.roundThinBorderBackups or {}
    local allBackups = db.roundThinBorderBackups
    local profileBackup = allBackups[activeProfile]

    if state then
        if type(profileBackup) ~= "table" then
            profileBackup = {}
            allBackups[activeProfile] = profileBackup
        end
    end

    local borderKey = GetOakRoundThinBorderKey()

    local resourceBars = profile.addons.EllesmereUIResourceBars
    if type(resourceBars) == "table" then
        if state then profileBackup.resourcebars = profileBackup.resourcebars or {} end
        for _, key in ipairs(OAK_RESOURCE_BORDER_KEYS) do
            local settings = resourceBars[key]
            if type(settings) == "table" then
                if state then
                    if type(profileBackup.resourcebars[key]) ~= "table" then
                        profileBackup.resourcebars[key] = {}
                        SaveBorderFields(profileBackup.resourcebars[key], settings, OAK_RESOURCE_BORDER_FIELDS)
                    end
                    ApplyResourceRoundThin(settings, borderKey)
                else
                    RestoreBorderFieldsOrFallback(profileBackup and profileBackup.resourcebars and profileBackup.resourcebars[key], settings, OAK_RESOURCE_BORDER_FIELDS, FallbackResourceBorder)
                end
            end
        end
    end

    local liveResourceBars = type(_G._ERB_AceDB) == "table" and type(_G._ERB_AceDB.profile) == "table" and _G._ERB_AceDB.profile
    if type(liveResourceBars) == "table" and liveResourceBars ~= resourceBars then
        if state then profileBackup.resourcebarsLive = profileBackup.resourcebarsLive or {} end
        for _, key in ipairs(OAK_RESOURCE_BORDER_KEYS) do
            local settings = liveResourceBars[key]
            if type(settings) == "table" then
                if state then
                    if type(profileBackup.resourcebarsLive[key]) ~= "table" then
                        profileBackup.resourcebarsLive[key] = {}
                        SaveBorderFields(profileBackup.resourcebarsLive[key], settings, OAK_RESOURCE_BORDER_FIELDS)
                    end
                    ApplyResourceRoundThin(settings, borderKey)
                else
                    RestoreBorderFieldsOrFallback(profileBackup and profileBackup.resourcebarsLive and profileBackup.resourcebarsLive[key], settings, OAK_RESOURCE_BORDER_FIELDS, FallbackResourceBorder)
                end
            end
        end
    end

    local unitFrames = profile.addons.EllesmereUIUnitFrames
    if type(unitFrames) == "table" then
        if state then profileBackup.unitframes = profileBackup.unitframes or {} end
        for _, key in ipairs(OAK_UNIT_FRAME_KEYS) do
            local settings = unitFrames[key]
            if type(settings) == "table" then
                if state then
                    if type(profileBackup.unitframes[key]) ~= "table" then
                        profileBackup.unitframes[key] = {}
                        SaveBorderFields(profileBackup.unitframes[key], settings, OAK_UNIT_BORDER_FIELDS)
                    end
                    ApplyUnitRoundThin(settings, borderKey)
                else
                    RestoreBorderFieldsOrFallback(profileBackup and profileBackup.unitframes and profileBackup.unitframes[key], settings, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
                end
            end
        end
    end

    local unitFrameAddon = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    local liveUnitFrames = unitFrameAddon and type(unitFrameAddon.db) == "table" and type(unitFrameAddon.db.profile) == "table" and unitFrameAddon.db.profile
    if type(liveUnitFrames) == "table" and liveUnitFrames ~= unitFrames then
        if state then profileBackup.unitframesLive = profileBackup.unitframesLive or {} end
        for _, key in ipairs(OAK_UNIT_FRAME_KEYS) do
            local settings = liveUnitFrames[key]
            if type(settings) == "table" then
                if state then
                    if type(profileBackup.unitframesLive[key]) ~= "table" then
                        profileBackup.unitframesLive[key] = {}
                        SaveBorderFields(profileBackup.unitframesLive[key], settings, OAK_UNIT_BORDER_FIELDS)
                    end
                    ApplyUnitRoundThin(settings, borderKey)
                else
                    RestoreBorderFieldsOrFallback(profileBackup and profileBackup.unitframesLive and profileBackup.unitframesLive[key], settings, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
                end
            end
        end
    end

    local raidFrames = profile.addons.EllesmereUIRaidFrames
    if type(raidFrames) == "table" then
        if state then
            profileBackup.raidframes = profileBackup.raidframes or {}
            if type(profileBackup.raidframes.root) ~= "table" then
                profileBackup.raidframes.root = {}
                SaveBorderFields(profileBackup.raidframes.root, raidFrames, OAK_UNIT_BORDER_FIELDS)
            end
            ApplyUnitRoundThin(raidFrames, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.raidframes and profileBackup.raidframes.root, raidFrames, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
        end
    end

    local raidFrameAddon = type(_G.EllesmereUIRaidFrames) == "table" and _G.EllesmereUIRaidFrames
    local liveRaidFrames = raidFrameAddon and type(raidFrameAddon.db) == "table" and type(raidFrameAddon.db.profile) == "table" and raidFrameAddon.db.profile
    if type(liveRaidFrames) == "table" and liveRaidFrames ~= raidFrames then
        if state then
            profileBackup.raidframesLive = profileBackup.raidframesLive or {}
            if type(profileBackup.raidframesLive.root) ~= "table" then
                profileBackup.raidframesLive.root = {}
                SaveBorderFields(profileBackup.raidframesLive.root, liveRaidFrames, OAK_UNIT_BORDER_FIELDS)
            end
            ApplyUnitRoundThin(liveRaidFrames, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.raidframesLive and profileBackup.raidframesLive.root, liveRaidFrames, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
        end
    end

    if not state and activeProfile then
        allBackups[activeProfile] = nil
    end

    if not skipRefresh then
        RefreshEllesmereBorderTargets()
    end
end

local function SetEllesmereRoundThinBorders(state)
    ApplyEllesmereRoundThinBorders(state)
end

local function GetEllesmereRoundThinBorders()
    return EnsureVisibilityDB().roundThinBorders == true
end

function addonTable.ApplyOakRoundThinBordersIfEnabled(profileName)
    local db = EnsureVisibilityDB()
    if db.roundThinBorders ~= true then return end
    local activeProfile = GetActiveEllesmereProfileName(profileName)
    if activeProfile then
        db.roundThinBorderBackups = db.roundThinBorderBackups or {}
        db.roundThinBorderBackups[activeProfile] = nil
    end
    ApplyEllesmereRoundThinBorders(true, profileName)
end

local function IsDamageMeterHeaderFrame(frame)
    if not frame or not frame._hdrBg or not frame.GetParent or not frame.GetChildren then return false end
    local parent = GetFrameParentSafe(frame)
    if not parent or not parent._bg then return false end
    local children = GetFrameChildrenSafe(frame)
    if not children then return false end
    for _, child in ipairs(children) do
        if child and child.IsObjectType and child:IsObjectType("Button") then
            return true
        end
    end
    return false
end

local function ForEachDamageMeterHeader(root, callback, depth)
    if not root or not root.GetChildren or (depth or 0) <= 0 then return end
    local children = GetFrameChildrenSafe(root)
    if not children then return end
    for _, child in ipairs(children) do
        if IsDamageMeterHeaderFrame(child) then
            callback(child)
        end
        ForEachDamageMeterHeader(child, callback, depth - 1)
    end
end

local function EnsureDamageMeterHeaderMaskTools()
    if addonTable.RegisterOakMedia then
        addonTable.RegisterOakMedia()
    elseif addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end
    if addonTable.RegisterOakRoundThinBorderRenderer then
        addonTable.RegisterOakRoundThinBorderRenderer()
    end
end

local function ApplyDamageMeterHeaderMasks(state)
    EnsureDamageMeterHeaderMaskTools()
    local root = _G.UIParent
    if not root then return end

    ForEachDamageMeterHeader(root, function(header)
        if state then
            if addonTable.ApplyOakRoundThinMaskOnly then
                addonTable.ApplyOakRoundThinMaskOnly(header, header._hdrBg, GetFrameParentSafe(header) or header)
            end
        elseif addonTable.RemoveOakRoundThinMaskOnly then
            addonTable.RemoveOakRoundThinMaskOnly(header)
        end
    end, 5)
end

local function ForEachDamageMeterWindow(callback)
    local root = _G.UIParent
    if not root then return end
    local seen = {}
    ForEachDamageMeterHeader(root, function(header)
        local window = GetFrameParentSafe(header)
        if window and not seen[window] then
            seen[window] = true
            callback(window)
        end
    end, 5)
end

local function ForEachDamageMeterChildFrame(root, callback, depth)
    if not root or not root.GetChildren or (depth or 0) <= 0 then return end
    local children = GetFrameChildrenSafe(root)
    if not children then return end
    for _, child in ipairs(children) do
        if child then
            callback(child)
            ForEachDamageMeterChildFrame(child, callback, depth - 1)
        end
    end
end

local function RemoveDamageMeterRoundThinArtifacts()
    ForEachDamageMeterWindow(function(window)
        if addonTable.RemoveOakRoundThinMaskOnly then
            pcall(addonTable.RemoveOakRoundThinMaskOnly, window)
        end
        ForEachDamageMeterChildFrame(window, function(frame)
            if addonTable.HideOakRoundThinBorderFrame and frame._oakRoundThinBorderTexture then
                pcall(addonTable.HideOakRoundThinBorderFrame, frame)
            end
            if addonTable.RemoveOakRoundThinMaskOnly and frame._oakRoundThinMaskOnlyEntries then
                pcall(addonTable.RemoveOakRoundThinMaskOnly, frame)
            end
        end, 6)
    end)
end

local ApplyStandaloneStatusBarRoundThin
local RemoveStandaloneStatusBarRoundThin

local function FindDamageMeterRowStatusBar(row)
    if not row or not row.IsObjectType or not row:IsObjectType("Button") then return nil end
    local children = GetFrameChildrenSafe(row)
    if not children then return nil end
    for _, child in ipairs(children) do
        if child and child.GetStatusBarTexture then
            return child
        end
    end
end

local function FindDamageMeterRowBackground(row)
    if not row or not row.GetRegions then return nil end
    local regions = { row:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.AddMaskTexture then
            return region
        end
    end
end

local function ApplyDamageMeterLiveRowBorders(state)
    ForEachDamageMeterWindow(function(window)
        ForEachDamageMeterChildFrame(window, function(frame)
            local statusbar = FindDamageMeterRowStatusBar(frame)
            if statusbar then
                if state then
                    ApplyStandaloneStatusBarRoundThin(statusbar, FindDamageMeterRowBackground(frame))
                else
                    RemoveStandaloneStatusBarRoundThin(statusbar)
                end
            end
        end, 4)
    end)
end

local function EnsureDamageMeterHeaderMaskHook()
    if type(_G._EDM_Apply) ~= "function" or _G._OAK_DMHeaderMaskHooked then return end
    local originalApply = _G._EDM_Apply
    _G._EDM_Apply = function(...)
        local results = { originalApply(...) }
        if EnsureVisibilityDB().roundThinDamageMeters == true and _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0, function()
                ApplyDamageMeterHeaderMasks(true)
                ApplyDamageMeterLiveRowBorders(true)
            end)
        end
        return unpack(results)
    end
    _G._OAK_DMHeaderMaskHooked = true
end

local function RefreshDamageMeterBorders()
    EnsureDamageMeterHeaderMaskHook()
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshPage) == "function" then
        pcall(_G.EllesmereUI.RefreshPage, _G.EllesmereUI)
    end
    local enabled = EnsureVisibilityDB().roundThinDamageMeters == true
    ApplyDamageMeterHeaderMasks(enabled)
    ApplyDamageMeterLiveRowBorders(enabled)
    if not enabled then
        RemoveDamageMeterRoundThinArtifacts()
    end
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            local delayedEnabled = EnsureVisibilityDB().roundThinDamageMeters == true
            ApplyDamageMeterHeaderMasks(delayedEnabled)
            ApplyDamageMeterLiveRowBorders(delayedEnabled)
            if not delayedEnabled then
                RemoveDamageMeterRoundThinArtifacts()
            end
        end)
    end
end

local function ApplyDamageMeterRoundThinBorders(state, profileName, skipRefresh)
    local db = EnsureVisibilityDB()
    db.roundThinDamageMeters = state == true

    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    local profile = activeProfile and profiles and profiles[activeProfile]
    if type(profile) ~= "table" then return end

    profile.addons = profile.addons or {}
    db.roundThinDamageMeterBackups = db.roundThinDamageMeterBackups or {}
    local allBackups = db.roundThinDamageMeterBackups
    local profileBackup = allBackups[activeProfile]

    if state and type(profileBackup) ~= "table" then
        profileBackup = {}
        allBackups[activeProfile] = profileBackup
    end

    local borderKey = GetOakRoundThinBorderKey()
    local damageMeters = profile.addons.EllesmereUIDamageMeters
    local damageSettings = type(damageMeters) == "table" and damageMeters.dm
    if type(damageSettings) == "table" then
        if state then
            if type(profileBackup.profile) ~= "table" then
                profileBackup.profile = {}
                SaveBorderFields(profileBackup.profile, damageSettings, OAK_DAMAGE_METER_BORDER_FIELDS)
            end
            ApplyDamageMeterRoundThin(damageSettings, borderKey)
        else
            FallbackDamageMeterBorder(damageSettings)
        end
    end

    local liveDB = type(_G._EDM_DB) == "table" and _G._EDM_DB
    local liveSettings = liveDB and type(liveDB.profile) == "table" and liveDB.profile.dm
    if type(liveSettings) == "table" and liveSettings ~= damageSettings then
        if state then
            if type(profileBackup.live) ~= "table" then
                profileBackup.live = {}
                SaveBorderFields(profileBackup.live, liveSettings, OAK_DAMAGE_METER_BORDER_FIELDS)
            end
            ApplyDamageMeterRoundThin(liveSettings, borderKey)
        else
            FallbackDamageMeterBorder(liveSettings)
        end
    end

    if not state and activeProfile then
        allBackups[activeProfile] = nil
    end

    if not skipRefresh then
        RefreshDamageMeterBorders()
    end
end

local function SetDamageMeterRoundThinBorders(state)
    ApplyDamageMeterRoundThinBorders(state)
end

local function GetDamageMeterRoundThinBorders()
    return EnsureVisibilityDB().roundThinDamageMeters == true
end

function addonTable.ApplyOakRoundThinDamageMetersIfEnabled(profileName)
    local db = EnsureVisibilityDB()
    if db.roundThinDamageMeters ~= true then return end
    local activeProfile = GetActiveEllesmereProfileName(profileName)
    if activeProfile then
        db.roundThinDamageMeterBackups = db.roundThinDamageMeterBackups or {}
        db.roundThinDamageMeterBackups[activeProfile] = nil
    end
    ApplyDamageMeterRoundThinBorders(true, profileName)
end

local function RefreshEllesmereTrackingBars()
    local cdm = type(_G.EllesmereUICooldownManager) == "table" and _G.EllesmereUICooldownManager
    if cdm and type(cdm.BuildTrackedBuffBars) == "function" then
        pcall(cdm.BuildTrackedBuffBars)
    end
    if type(_G._ECME_Apply) == "function" then
        pcall(_G._ECME_Apply)
    elseif type(_G._ECME_ApplyVisibility) == "function" then
        pcall(_G._ECME_ApplyVisibility)
    end
    RefreshEllesmereOptionsPage()
end

local function ForEachTrackedBuffBarSpecStore(profileName, callback)
    local db = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB
    local assignments = db and db.spellAssignments
    if type(assignments) ~= "table" then return end

    if type(assignments.specProfiles) == "table" then
        callback("legacy", assignments.specProfiles)
    end

    local activeProfile = GetActiveEllesmereProfileName(profileName)
    local profileStore = activeProfile
        and type(assignments.profiles) == "table"
        and assignments.profiles[activeProfile]
    if type(profileStore) == "table" and type(profileStore.specProfiles) == "table" then
        callback("profile", profileStore.specProfiles)
    end
end

local function ApplyTrackingBarRoundThinBorders(state, profileName, skipRefresh)
    local db = EnsureVisibilityDB()
    db.roundThinTrackingBars = state == true

    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    db.roundThinTrackingBarBackups = db.roundThinTrackingBarBackups or {}
    local allBackups = db.roundThinTrackingBarBackups
    local profileBackup = allBackups[activeProfile]

    if state and type(profileBackup) ~= "table" then
        profileBackup = {}
        allBackups[activeProfile] = profileBackup
    end

    local borderKey = GetOakRoundThinBorderKey()
    ForEachTrackedBuffBarSpecStore(profileName, function(storeKey, specProfiles)
        if state then profileBackup[storeKey] = profileBackup[storeKey] or {} end
        for specKey, specData in pairs(specProfiles) do
            local bars = type(specData) == "table"
                and type(specData.trackedBuffBars) == "table"
                and specData.trackedBuffBars.bars
            if type(bars) == "table" then
                if state then profileBackup[storeKey][specKey] = profileBackup[storeKey][specKey] or {} end
                for index, settings in ipairs(bars) do
                    if type(settings) == "table" then
                        if state then
                            if type(profileBackup[storeKey][specKey][index]) ~= "table" then
                                profileBackup[storeKey][specKey][index] = {}
                                SaveBorderFields(profileBackup[storeKey][specKey][index], settings, OAK_TRACKING_BAR_BORDER_FIELDS)
                            end
                            ApplyTrackingBarRoundThin(settings, borderKey)
                        else
                            local backup = profileBackup
                                and profileBackup[storeKey]
                                and profileBackup[storeKey][specKey]
                                and profileBackup[storeKey][specKey][index]
                            RestoreBorderFieldsOrFallback(backup, settings, OAK_TRACKING_BAR_BORDER_FIELDS, FallbackTrackingBarBorder)
                        end
                    end
                end
            end
        end
    end)

    if not state then
        allBackups[activeProfile] = nil
    end

    if not skipRefresh then
        RefreshEllesmereTrackingBars()
    end
end

local function SetTrackingBarRoundThinBorders(state)
    ApplyTrackingBarRoundThinBorders(state)
end

local function GetTrackingBarRoundThinBorders()
    return EnsureVisibilityDB().roundThinTrackingBars == true
end

function addonTable.ApplyOakRoundThinTrackingBarsIfEnabled(profileName)
    local db = EnsureVisibilityDB()
    if db.roundThinTrackingBars ~= true then return end
    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    db.roundThinTrackingBarBackups = db.roundThinTrackingBarBackups or {}
    db.roundThinTrackingBarBackups[activeProfile] = nil
    ApplyTrackingBarRoundThinBorders(true, profileName)
end

local function HideFramePPBorders(frame)
    local PP = _G.EllesmereUI and _G.EllesmereUI.PP
    if not frame or not PP or type(PP.GetBorders) ~= "function" then return end
    local ppContainer = PP.GetBorders(frame)
    if not ppContainer then return end
    if type(PP.HideBorder) == "function" then
        pcall(PP.HideBorder, frame)
    end
    if ppContainer._top then ppContainer._top:SetAlpha(0) end
    if ppContainer._bottom then ppContainer._bottom:SetAlpha(0) end
    if ppContainer._left then ppContainer._left:SetAlpha(0) end
    if ppContainer._right then ppContainer._right:SetAlpha(0) end
end

local function FindFirstTextureRegion(frame)
    if not frame or not frame.GetRegions then return nil end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.AddMaskTexture then
            return region
        end
    end
end

ApplyStandaloneStatusBarRoundThin = function(statusbar, bgTexture)
    if not statusbar or not statusbar.GetStatusBarTexture then return false end
    EnsureOakRoundThinRenderer()
    if not addonTable.ApplyOakRoundThinBorderFrame then return false end

    if bgTexture and bgTexture.AddMaskTexture then
        statusbar._bg = bgTexture
    end
    HideFramePPBorders(statusbar)

    local borderFrame = statusbar._oakRoundThinStandaloneBorder
    if not borderFrame then
        borderFrame = CreateFrame("Frame", nil, statusbar)
        statusbar._oakRoundThinStandaloneBorder = borderFrame
    end
    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(statusbar)
    borderFrame:SetFrameLevel((GetFrameLevelSafe(statusbar) or 0) + 8)
    borderFrame:EnableMouse(false)

    addonTable.ApplyOakRoundThinBorderFrame(borderFrame, 1, 0, 0, 0, 1, 0, 0, 0, 0)

    local auxParent = GetFrameParentSafe(bgTexture)
    if bgTexture and auxParent and auxParent ~= statusbar and addonTable.ApplyOakRoundThinMaskOnly then
        statusbar._oakRoundThinStandaloneMaskParent = auxParent
        addonTable.ApplyOakRoundThinMaskOnly(auxParent, bgTexture, statusbar)
    end
    return true
end

RemoveStandaloneStatusBarRoundThin = function(statusbar)
    if not statusbar then return end
    if statusbar._oakRoundThinStandaloneBorder and addonTable.HideOakRoundThinBorderFrame then
        addonTable.HideOakRoundThinBorderFrame(statusbar._oakRoundThinStandaloneBorder)
        statusbar._oakRoundThinStandaloneBorder:Hide()
    end
    if statusbar._oakRoundThinStandaloneMaskParent and addonTable.RemoveOakRoundThinMaskOnly then
        addonTable.RemoveOakRoundThinMaskOnly(statusbar._oakRoundThinStandaloneMaskParent)
    end
    statusbar._oakRoundThinStandaloneMaskParent = nil
end

local function ForEachChildFrame(root, callback, depth)
    if not root or not root.GetChildren or (depth or 0) <= 0 then return end
    local children = GetFrameChildrenSafe(root)
    if not children then return end
    for _, child in ipairs(children) do
        if child then
            callback(child)
            ForEachChildFrame(child, callback, depth - 1)
        end
    end
end

local function ApplyEllesmereCastbarRoundThinLive(state)
    local root = _G.UIParent
    if not root then return end
    ForEachChildFrame(root, function(frame)
        local castbar = frame.Castbar
        if castbar and castbar.GetStatusBarTexture then
            local bg = FindFirstTextureRegion(GetFrameParentSafe(castbar))
            if state then
                ApplyStandaloneStatusBarRoundThin(castbar, bg)
            else
                RemoveStandaloneStatusBarRoundThin(castbar)
            end
        end
    end, 7)
end

local function EnsureEllesmereCastbarRoundThinHook()
    if type(_G._EUF_ReloadFrames) ~= "function" or _G._OAK_EUFCastbarRoundThinHooked then return end
    local originalReloadFrames = _G._EUF_ReloadFrames
    _G._EUF_ReloadFrames = function(...)
        local results = { originalReloadFrames(...) }
        if EnsureVisibilityDB().roundThinCastBars == true and _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0, function()
                ApplyEllesmereCastbarRoundThinLive(true)
            end)
        end
        return unpack(results)
    end
    _G._OAK_EUFCastbarRoundThinHooked = true
end

local function RefreshEllesmereCastbarBorders()
    EnsureEllesmereCastbarRoundThinHook()
    ApplyEllesmereCastbarRoundThinLive(EnsureVisibilityDB().roundThinCastBars == true)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            ApplyEllesmereCastbarRoundThinLive(EnsureVisibilityDB().roundThinCastBars == true)
        end)
    end
end

local function ApplyCastBarRoundThinBorders(state, profileName, skipRefresh)
    local db = EnsureVisibilityDB()
    db.roundThinCastBars = state == true

    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    local profile = activeProfile and profiles and profiles[activeProfile]
    local borderKey = GetOakRoundThinBorderKey()

    db.roundThinCastBarBackups = db.roundThinCastBarBackups or {}
    local allBackups = db.roundThinCastBarBackups
    local profileBackup = allBackups[activeProfile]
    if state and type(profileBackup) ~= "table" then
        profileBackup = {}
        allBackups[activeProfile] = profileBackup
    end

    local resourceBars = type(profile) == "table"
        and type(profile.addons) == "table"
        and profile.addons.EllesmereUIResourceBars
    local castSettings = type(resourceBars) == "table" and resourceBars.castBar
    if type(castSettings) == "table" then
        if state then
            if type(profileBackup.resourceCastBar) ~= "table" then
                profileBackup.resourceCastBar = {}
                SaveBorderFields(profileBackup.resourceCastBar, castSettings, OAK_RESOURCE_BORDER_FIELDS)
            end
            ApplyResourceRoundThin(castSettings, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.resourceCastBar, castSettings, OAK_RESOURCE_BORDER_FIELDS, FallbackResourceBorder)
        end
    end

    local liveResourceBars = type(_G._ERB_AceDB) == "table" and type(_G._ERB_AceDB.profile) == "table" and _G._ERB_AceDB.profile
    local liveCastSettings = type(liveResourceBars) == "table" and liveResourceBars.castBar
    if type(liveCastSettings) == "table" and liveCastSettings ~= castSettings then
        if state then
            if type(profileBackup.liveResourceCastBar) ~= "table" then
                profileBackup.liveResourceCastBar = {}
                SaveBorderFields(profileBackup.liveResourceCastBar, liveCastSettings, OAK_RESOURCE_BORDER_FIELDS)
            end
            ApplyResourceRoundThin(liveCastSettings, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.liveResourceCastBar, liveCastSettings, OAK_RESOURCE_BORDER_FIELDS, FallbackResourceBorder)
        end
    end

    if not state and activeProfile then
        allBackups[activeProfile] = nil
    end

    if not skipRefresh then
        if type(_G._ERB_Apply) == "function" then pcall(_G._ERB_Apply) end
        RefreshEllesmereCastbarBorders()
        if not state then RefreshEllesmereBorderTargets() end
    end
end

local function SetCastBarRoundThinBorders(state)
    ApplyCastBarRoundThinBorders(state)
end

local function GetCastBarRoundThinBorders()
    return EnsureVisibilityDB().roundThinCastBars == true
end

function addonTable.ApplyOakRoundThinCastBarsIfEnabled(profileName)
    local db = EnsureVisibilityDB()
    if db.roundThinCastBars ~= true then return end
    local activeProfile = GetActiveEllesmereProfileName(profileName) or "__default"
    if activeProfile then
        db.roundThinCastBarBackups = db.roundThinCastBarBackups or {}
        db.roundThinCastBarBackups[activeProfile] = nil
    end
    ApplyCastBarRoundThinBorders(true, profileName)
end

local function ApplyBossFrameRoundThinBorders(state, profileName, skipRefresh)
    local db = EnsureVisibilityDB()
    db.roundThinBossFrames = state == true

    local activeProfile = GetActiveEllesmereProfileName(profileName)
    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    local profile = activeProfile and profiles and profiles[activeProfile]
    if type(profile) ~= "table" then return end

    profile.addons = profile.addons or {}
    db.roundThinBossFrameBackups = db.roundThinBossFrameBackups or {}
    local allBackups = db.roundThinBossFrameBackups
    local profileBackup = allBackups[activeProfile]
    if state and type(profileBackup) ~= "table" then
        profileBackup = {}
        allBackups[activeProfile] = profileBackup
    end

    local borderKey = GetOakRoundThinBorderKey()
    local unitFrames = profile.addons.EllesmereUIUnitFrames
    local settings = type(unitFrames) == "table" and unitFrames.boss
    if type(settings) == "table" then
        if state then
            if type(profileBackup.profile) ~= "table" then
                profileBackup.profile = {}
                SaveBorderFields(profileBackup.profile, settings, OAK_UNIT_BORDER_FIELDS)
            end
            ApplyUnitRoundThin(settings, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.profile, settings, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
        end
    end

    local unitFrameAddon = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    local liveUnitFrames = unitFrameAddon and type(unitFrameAddon.db) == "table" and type(unitFrameAddon.db.profile) == "table" and unitFrameAddon.db.profile
    local liveSettings = type(liveUnitFrames) == "table" and liveUnitFrames.boss
    if type(liveSettings) == "table" and liveSettings ~= settings then
        if state then
            if type(profileBackup.live) ~= "table" then
                profileBackup.live = {}
                SaveBorderFields(profileBackup.live, liveSettings, OAK_UNIT_BORDER_FIELDS)
            end
            ApplyUnitRoundThin(liveSettings, borderKey)
        else
            RestoreBorderFieldsOrFallback(profileBackup and profileBackup.live, liveSettings, OAK_UNIT_BORDER_FIELDS, FallbackUnitBorder)
        end
    end

    if not state and activeProfile then
        allBackups[activeProfile] = nil
    end

    if not skipRefresh then
        RefreshEllesmereBorderTargets()
    end
end

local function SetBossFrameRoundThinBorders(state)
    ApplyBossFrameRoundThinBorders(state)
end

local function GetBossFrameRoundThinBorders()
    return EnsureVisibilityDB().roundThinBossFrames == true
end

function addonTable.ApplyOakRoundThinBossFramesIfEnabled(profileName)
    local db = EnsureVisibilityDB()
    if db.roundThinBossFrames ~= true then return end
    local activeProfile = GetActiveEllesmereProfileName(profileName)
    if activeProfile then
        db.roundThinBossFrameBackups = db.roundThinBossFrameBackups or {}
        db.roundThinBossFrameBackups[activeProfile] = nil
    end
    ApplyBossFrameRoundThinBorders(true, profileName)
end

local function HideDBMSquareBorder(frame)
    local name = GetFrameNameSafe(frame)
    if type(name) ~= "string" then return end
    for _, suffix in ipairs({ "BarBorderTop", "BarBorderBottom", "BarBorderLeft", "BarBorderRight" }) do
        local texture = _G[name .. suffix]
        if texture and texture.Hide then texture:Hide() end
    end
end

local function ApplyDBMRoundThinBar(frame)
    local name = GetFrameNameSafe(frame)
    if type(name) ~= "string" or not name:match("^DBT_Bar_") then return false end
    local bar = _G[name .. "Bar"]
    if not bar or not bar.GetStatusBarTexture then return false end
    HideDBMSquareBorder(frame)
    return ApplyStandaloneStatusBarRoundThin(bar, _G[name .. "BarBackground"])
end

local function ApplyBigWigsRoundThinBar(frame)
    if not frame or not frame.candyBarBar or not frame.candyBarBar.GetStatusBarTexture then return false end
    if frame.candyBarBackdrop and frame.candyBarBackdrop.Hide then
        frame._oakRoundThinHiddenCandyBackdrop = true
        frame.candyBarBackdrop:Hide()
    end
    return ApplyStandaloneStatusBarRoundThin(frame.candyBarBar, frame.candyBarBackground)
end

local function RemoveBigWigsRoundThinBar(frame)
    if not frame then return end
    RemoveStandaloneStatusBarRoundThin(frame.candyBarBar)
    if frame._oakRoundThinHiddenCandyBackdrop and frame.candyBarBackdrop and frame.candyBarBackdrop.Show then
        frame.candyBarBackdrop:Show()
    end
    frame._oakRoundThinHiddenCandyBackdrop = nil
end

local function ApplyBossModRoundThinLive(state)
    local DBT = _G.DBT
    if type(DBT) == "table" and type(DBT.GetBarIterator) == "function" then
        local ok, iterator, tbl, key = pcall(DBT.GetBarIterator, DBT)
        if ok and iterator then
            while true do
                local barObj
                key, barObj = iterator(tbl, key)
                if key == nil then break end
                local dbmBar = key
                if type(dbmBar) == "table" and dbmBar.frame then
                    if state then
                        ApplyDBMRoundThinBar(dbmBar.frame)
                    else
                        local frameName = GetFrameNameSafe(dbmBar.frame)
                        RemoveStandaloneStatusBarRoundThin(type(frameName) == "string" and _G[frameName .. "Bar"] or nil)
                    end
                end
            end
        end
    end

    local root = _G.UIParent
    if not root then return end
    ForEachChildFrame(root, function(frame)
        local name = GetFrameNameSafe(frame)
        if type(name) == "string" and name:match("^DBT_Bar_") then
            local bar = _G[name .. "Bar"]
            if state then
                ApplyDBMRoundThinBar(frame)
            else
                RemoveStandaloneStatusBarRoundThin(bar)
            end
        elseif frame.candyBarBar then
            if state then
                ApplyBigWigsRoundThinBar(frame)
            else
                RemoveBigWigsRoundThinBar(frame)
            end
        end
    end, 7)
end

local function IsBossModRoundThinEnabled()
    return EnsureVisibilityDB().roundThinBossModBars == true
end

local function ScheduleBossModRoundThinRefresh()
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            ApplyBossModRoundThinLive(IsBossModRoundThinEnabled())
        end)
    else
        ApplyBossModRoundThinLive(IsBossModRoundThinEnabled())
    end
end

local function EnsureBossModRoundThinHooks()
    local DBT = _G.DBT
    if type(DBT) == "table" and type(DBT.CreateBar) == "function" and not DBT._oakRoundThinCreateBarHooked then
        local originalCreateBar = DBT.CreateBar
        DBT.CreateBar = function(self, ...)
            local results = { originalCreateBar(self, ...) }
            if IsBossModRoundThinEnabled() and results[1] and results[1].frame then
                ApplyDBMRoundThinBar(results[1].frame)
            end
            return unpack(results)
        end
        DBT._oakRoundThinCreateBarHooked = true
    end
    if type(DBT) == "table" and type(DBT.ApplyStyle) == "function" and not DBT._oakRoundThinApplyStyleHooked then
        local originalApplyStyle = DBT.ApplyStyle
        DBT.ApplyStyle = function(self, ...)
            local results = { originalApplyStyle(self, ...) }
            if IsBossModRoundThinEnabled() then ScheduleBossModRoundThinRefresh() end
            return unpack(results)
        end
        DBT._oakRoundThinApplyStyleHooked = true
    end

    local plugin = _G.BigWigs and _G.BigWigs.GetPlugin and _G.BigWigs:GetPlugin("Bars", true)
    if type(plugin) == "table" and type(plugin.BigWigs_StartBar) == "function" and not plugin._oakRoundThinStartBarHooked then
        hooksecurefunc(plugin, "BigWigs_StartBar", function()
            if IsBossModRoundThinEnabled() then ScheduleBossModRoundThinRefresh() end
        end)
        plugin._oakRoundThinStartBarHooked = true
    end
    if type(plugin) == "table" and type(plugin.EmphasizeBar) == "function" and not plugin._oakRoundThinEmphasizeHooked then
        hooksecurefunc(plugin, "EmphasizeBar", function()
            if IsBossModRoundThinEnabled() then ScheduleBossModRoundThinRefresh() end
        end)
        plugin._oakRoundThinEmphasizeHooked = true
    end
end

local function RefreshBossModRoundThinBorders()
    EnsureBossModRoundThinHooks()
    ApplyBossModRoundThinLive(IsBossModRoundThinEnabled())
    if not IsBossModRoundThinEnabled() then
        local DBT = _G.DBT
        if type(DBT) == "table" and type(DBT.ApplyStyle) == "function" then
            pcall(DBT.ApplyStyle, DBT)
        end
    end
end

local function SetBossModRoundThinBorders(state)
    EnsureVisibilityDB().roundThinBossModBars = state == true
    RefreshBossModRoundThinBorders()
end

local function GetBossModRoundThinBorders()
    return EnsureVisibilityDB().roundThinBossModBars == true
end

function addonTable.ApplyOakRoundThinBossModBarsIfEnabled()
    if EnsureVisibilityDB().roundThinBossModBars ~= true then return end
    RefreshBossModRoundThinBorders()
end

local function IsBlizziRoundThinEnabled()
    return EnsureVisibilityDB().roundThinBlizziInterrupts == true
end

local function ApplyBlizziRoundThinBorderFrame(BIT, frame)
    if not BIT or not frame then return false end
    local UI = BIT.UI
    if addonTable.RegisterOakMedia then
        addonTable.RegisterOakMedia()
    elseif addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end
    if addonTable.RegisterOakRoundThinBorderRenderer then
        addonTable.RegisterOakRoundThinBorderRenderer()
    end

    local borderFrame = frame.borderOverlay
    if not borderFrame or not addonTable.ApplyOakRoundThinBorderFrame then return false end
    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(frame)
    if borderFrame.SetBackdrop then borderFrame:SetBackdrop(nil) end

    local bitDB = BIT.db or {}
    addonTable.ApplyOakRoundThinBorderFrame(
        borderFrame,
        1,
        bitDB.borderColorR or 0,
        bitDB.borderColorG or 0,
        bitDB.borderColorB or 0,
        bitDB.borderColorA or 1,
        0, 0, 0, 0
    )

    if frame.iconBorderOverlay then
        if frame.iconBorderOverlay.SetBackdrop then frame.iconBorderOverlay:SetBackdrop(nil) end
        if addonTable.HideOakRoundThinBorderFrame then
            addonTable.HideOakRoundThinBorderFrame(frame.iconBorderOverlay)
        end
    end

    frame._effectiveBorderSize = 0
    if frame._iconS and UI and type(UI.ApplyBarContentInset) == "function" then
        UI:ApplyBarContentInset(frame)
    end
    return true
end

local function EnsureBlizziRoundThinHook()
    local BIT = _G.BIT
    if type(BIT) ~= "table" or type(BIT.UI) ~= "table" or type(BIT.UI.ApplyBorderToFrame) ~= "function" then return end
    local UI = BIT.UI
    if UI._oakRoundThinApplyBorderHooked then return end

    local originalApplyBorderToFrame = UI.ApplyBorderToFrame
    UI._oakRoundThinOriginalApplyBorderToFrame = originalApplyBorderToFrame
    UI.ApplyBorderToFrame = function(self, frame, ...)
        if IsBlizziRoundThinEnabled() then
            if ApplyBlizziRoundThinBorderFrame(BIT, frame) then
                return
            end
        end

        if frame and frame.borderOverlay and addonTable.HideOakRoundThinBorderFrame then
            addonTable.HideOakRoundThinBorderFrame(frame.borderOverlay)
        end
        return originalApplyBorderToFrame(self, frame, ...)
    end
    UI._oakRoundThinApplyBorderHooked = true
end

local function RefreshBlizziRoundThinBorders()
    EnsureBlizziRoundThinHook()
    local BIT = _G.BIT
    if type(BIT) == "table" and type(BIT.UI) == "table" and type(BIT.UI.ApplyBorderToAll) == "function" then
        pcall(BIT.UI.ApplyBorderToAll, BIT.UI)
    end
end

local function SetBlizziRoundThinBorders(state)
    EnsureVisibilityDB().roundThinBlizziInterrupts = state == true
    RefreshBlizziRoundThinBorders()
end

local function GetBlizziRoundThinBorders()
    return EnsureVisibilityDB().roundThinBlizziInterrupts == true
end

function addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled()
    if EnsureVisibilityDB().roundThinBlizziInterrupts ~= true then return end
    RefreshBlizziRoundThinBorders()
end

local function SetAllRoundedBorders(state)
    state = state == true
    SetEllesmereRoundThinBorders(state)
    SetCastBarRoundThinBorders(state)
    SetBossFrameRoundThinBorders(state)
    SetTrackingBarRoundThinBorders(state)
    SetBossModRoundThinBorders(state)
    SetBlizziRoundThinBorders(state)
    SetDamageMeterRoundThinBorders(state)
end

local function GetAllRoundedBorders()
    return GetEllesmereRoundThinBorders()
        and GetCastBarRoundThinBorders()
        and GetBossFrameRoundThinBorders()
        and GetTrackingBarRoundThinBorders()
        and GetBossModRoundThinBorders()
        and GetBlizziRoundThinBorders()
        and GetDamageMeterRoundThinBorders()
end

local function RefreshEllesmereUnitFrameSettings()
    local ns = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    if ns and type(ns.UpdateFrameVisibility) == "function" then
        pcall(ns.UpdateFrameVisibility)
    end
    RefreshEllesmereOptionsPage()
end

local function SyncEllesmerePlayerFrameState()
    local playerHidden = GetEllesmereUnitHideNoTarget("player")
    local petHidden = GetEllesmereUnitHideNoTarget("pet")
    if playerHidden ~= nil or petHidden ~= nil then
        local enabled = playerHidden == true and petHidden == true
        EnsureVisibilityDB().playerFrameHidden = enabled
        return enabled
    end
    return EnsureVisibilityDB().playerFrameHidden == true
end

local function SetEllesmerePlayerFrame(state)
    local db = EnsureVisibilityDB()
    db.playerFrameHidden = state == true
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    if unitFrames then
        unitFrames.player = unitFrames.player or {}
        unitFrames.pet = unitFrames.pet or {}
        SetEllesmereHideNoTargetOption(unitFrames.player, state)
        SetEllesmereHideNoTargetOption(unitFrames.pet, state)
        RefreshEllesmereUnitFrameSettings()
    end
    if addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end
end

local function GetEllesmerePlayerFrame()
    return SyncEllesmerePlayerFrameState()
end

local function RefreshEllesmereActionBars()
    local EAB = type(_G.EllesmereUIActionBars) == "table" and _G.EllesmereUIActionBars
    if EAB then
        if type(EAB.RefreshRuntimeVisibility) == "function" then pcall(EAB.RefreshRuntimeVisibility, EAB) end
        if type(EAB.RefreshMouseover) == "function" then pcall(EAB.RefreshMouseover, EAB) end
        if type(EAB.ApplyCombatVisibility) == "function" then pcall(EAB.ApplyCombatVisibility, EAB) end
        if type(EAB.UpdateHousingVisibility) == "function" then pcall(EAB.UpdateHousingVisibility, EAB) end
    end
    RefreshEllesmereOptionsPage()
end

local function SetEllesmereActionBars(state)
    EnsureVisibilityDB().actionBarsHidden = state == true
    local actionBars = GetEllesmereAddonProfile("EllesmereUIActionBars")
    if not actionBars then return end

    actionBars.mouseoverShowAll = state == true
    actionBars.bars = actionBars.bars or {}
    local alwaysVisibleSpecialBars = {
        ExtraActionButton = true,
        QueueStatus = true,
    }
    for key, settings in pairs(actionBars.bars) do
        if type(settings) == "table" then
            if alwaysVisibleSpecialBars[key] then
                settings.barVisibility = "always"
                settings.mouseoverEnabled = false
                settings.alwaysHidden = false
                settings.combatHideEnabled = false
                settings.combatShowEnabled = false
                settings.mouseoverAlpha = settings._savedBarAlpha or settings.mouseoverAlpha or 1
            else
                local visibility = settings.barVisibility or "always"
                local isEnabled = settings.enabled ~= false and visibility ~= "never" and settings.alwaysHidden ~= true
                if isEnabled then
                    SetEllesmereHideNoTargetOption(settings, false)
                    if state then
                        settings.barVisibility = "mouseover"
                        settings.mouseoverEnabled = true
                        settings.alwaysHidden = false
                        settings.combatHideEnabled = false
                        settings.combatShowEnabled = false
                        if settings._savedBarAlpha == nil then settings._savedBarAlpha = settings.mouseoverAlpha or 1 end
                        settings.mouseoverAlpha = 0
                    else
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
    RefreshEllesmereActionBars()
    if addonTable.RefreshEllesmereSpecialActionBarVisibility then
        addonTable.RefreshEllesmereSpecialActionBarVisibility()
    end
end

local function GetEllesmereActionBars()
    local actionBars = GetEllesmereAddonProfile("EllesmereUIActionBars")
    local bars = actionBars and actionBars.bars
    if type(bars) == "table" then
        local found = false
        for key, settings in pairs(bars) do
            if type(settings) == "table" and key ~= "ExtraActionButton" and key ~= "QueueStatus" then
                local visibility = settings.barVisibility or "always"
                local isEnabled = settings.enabled ~= false and visibility ~= "never" and settings.alwaysHidden ~= true
                if isEnabled then
                    found = true
                    if visibility ~= "mouseover" then
                        EnsureVisibilityDB().actionBarsHidden = false
                        return false
                    end
                end
            end
        end
        if found then
            EnsureVisibilityDB().actionBarsHidden = true
            return true
        end
    end
    return EnsureVisibilityDB().actionBarsHidden == true
end

local function GetEllesmereChatAddon()
    if _G.EllesmereUI and _G.EllesmereUI.Lite and _G.EllesmereUI.Lite.GetAddon then
        local addon = _G.EllesmereUI.Lite.GetAddon("EllesmereUIChat", true)
        if addon then return addon end
    end
    return nil
end

local function RefreshEllesmereChat()
    local ECHAT = GetEllesmereChatAddon()
    if ECHAT then
        if type(ECHAT.ApplyBackground) == "function" then pcall(ECHAT.ApplyBackground) end
        if type(ECHAT.ApplyFonts) == "function" then pcall(ECHAT.ApplyFonts) end
        if type(ECHAT.RefreshVisibility) == "function" then pcall(ECHAT.RefreshVisibility) end
        if type(ECHAT.ResetIdleTimer) == "function" then pcall(ECHAT.ResetIdleTimer) end
    end
    RefreshEllesmereOptionsPage()
end

local function SetEllesmereChatBackground(state)
    EnsureVisibilityDB().chatBackgroundHidden = state == true
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    if chat then
        chat.chat = chat.chat or {}
        chat.chat.bgAlpha = state and 0 or 0.65
        chat.chat.idleFadeStrength = state and 100 or 40
        RefreshEllesmereChat()
    end
end

local function GetEllesmereChatBackground()
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    if chat and chat.chat then
        local hidden = (chat.chat.bgAlpha or 0.65) <= 0.01 and (chat.chat.idleFadeStrength or 40) >= 100
        EnsureVisibilityDB().chatBackgroundHidden = hidden
        return hidden
    end
    return EnsureVisibilityDB().chatBackgroundHidden == true
end

local function RefreshEllesmereCDM()
    local cdm = type(_G.EllesmereUICooldownManager) == "table" and _G.EllesmereUICooldownManager
    if cdm and type(cdm.CDMApplyVisibility) == "function" then
        pcall(cdm.CDMApplyVisibility)
    elseif type(_G._ECME_ApplyVisibility) == "function" then
        pcall(_G._ECME_ApplyVisibility)
    end
    RefreshEllesmereOptionsPage()
end

local function GetEllesmereResourceBarsProfile()
    if type(_G._ERB_AceDB) == "table" and type(_G._ERB_AceDB.profile) == "table" then
        return _G._ERB_AceDB.profile
    end
    return GetEllesmereAddonProfile("EllesmereUIResourceBars")
end

local function RefreshEllesmereResourceBars()
    if type(_G._ERB_Apply) == "function" then
        pcall(_G._ERB_Apply)
    end
    RefreshEllesmereOptionsPage()
end

local function SetEllesmereResourceBarsVisibility(state)
    local profile = GetEllesmereResourceBarsProfile()
    if type(profile) ~= "table" then return end

    for _, key in ipairs({ "health", "primary", "secondary" }) do
        local settings = profile[key]
        if type(settings) == "table" then
            settings.visibility = "always"
            SetEllesmereHideNoTargetOption(settings, state)
        end
    end
    RefreshEllesmereResourceBars()
end

local function GetEllesmereResourceBarsVisibility()
    local profile = GetEllesmereResourceBarsProfile()
    if type(profile) ~= "table" then return nil end

    local found = false
    for _, key in ipairs({ "health", "primary", "secondary" }) do
        local settings = profile[key]
        if type(settings) == "table" then
            found = true
            if settings.visHideNoTarget ~= true then return false end
        end
    end
    if found then return true end
    return nil
end

local function SetEllesmereCDM(state)
    EnsureVisibilityDB().cdmFading = state == true
    local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) == "table" then
        local wanted = { cooldowns = true, utility = true, buffs = true }
        for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
            if type(bars[key]) == "table" then
                bars[key].barVisibility = "always"
                SetEllesmereHideNoTargetOption(bars[key], state)
            end
        end
        for _, bar in ipairs(bars) do
            if type(bar) == "table" and wanted[bar.key] then
                bar.barVisibility = "always"
                SetEllesmereHideNoTargetOption(bar, state)
            end
        end
        RefreshEllesmereCDM()
    end

    SetEllesmereResourceBarsVisibility(state)
end

local function GetEllesmereCDM()
    local resourceHidden = GetEllesmereResourceBarsVisibility()
    local cdm = GetEllesmereAddonProfile("EllesmereUICooldownManager")
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) == "table" then
        local seen = { cooldowns = false, utility = false, buffs = false }
        for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
            if type(bars[key]) == "table" then
                if bars[key].visHideNoTarget ~= true then
                    EnsureVisibilityDB().cdmFading = false
                    return false
                end
                seen[key] = true
            end
        end
        for _, bar in ipairs(bars) do
            if type(bar) == "table" and seen[bar.key] ~= nil then
                if bar.visHideNoTarget ~= true then
                    EnsureVisibilityDB().cdmFading = false
                    return false
                end
                seen[bar.key] = true
            end
        end
        for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
            if not seen[key] then
                EnsureVisibilityDB().cdmFading = false
                return false
            end
        end
        if resourceHidden == false then
            EnsureVisibilityDB().cdmFading = false
            return false
        end
        EnsureVisibilityDB().cdmFading = true
        return true
    end
    if resourceHidden ~= nil then
        EnsureVisibilityDB().cdmFading = resourceHidden
        return resourceHidden
    end
    return EnsureVisibilityDB().cdmFading == true
end

local function SetEllesmereSmartPlayerPetVisibility(state)
    local db = EnsureVisibilityDB()
    db.smartPlayerPetVisibility = state == true
    db.showPlayerWhenInjured = nil
    if addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end
end

local function GetEllesmereSmartPlayerPetVisibility()
    local db = EnsureVisibilityDB()
    return db.smartPlayerPetVisibility == true or db.showPlayerWhenInjured == true
end

local function SetEllesmereShowPlayerInParty(state)
    EnsureVisibilityDB().showPlayerInParty = state == true
    if addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end
end

local function GetEllesmereShowPlayerInParty()
    return EnsureVisibilityDB().showPlayerInParty == true
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

local function SetEllesmereTooltipAnchor(state)
    EnsureVisibilityDB().tooltipAnchor = false
    if addonTable.RefreshEllesmereTooltipAnchor then
        addonTable.RefreshEllesmereTooltipAnchor()
    end
end

local function GetEllesmereTooltipAnchor()
    return false
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
        SetEllesmereShowPlayerInParty(state)
        SetEllesmereChatLineFade(state)
        SetEllesmereTooltipAnchor(state)
    end
    EnsureVisibilityDB().allHidden = state == true
end

local function GetAllHidden()
    local baseState = GetUnitframes() and GetMouseover() and GetChatBackgroundHidden() and GetCDMFading()
    if IsEllesmereProvider() then
        return baseState and GetEllesmereSmartPlayerPetVisibility() and GetEllesmereShowPlayerInParty() and GetEllesmereChatLineFade() and GetEllesmereTooltipAnchor()
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
    Title:SetText(cWrap .. (IsEllesmereProvider() and "Ellesmere Tweaks" or "Visibility") .. "|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10)
    Desc:SetJustifyH("LEFT")
    Desc:SetText(IsEllesmereProvider() and "Tune OakUI's Ellesmere visibility and fade behavior." or "Control OakUI visibility behavior for the selected base UI.")

    local checkboxes = {}
    local function AddTooltip(frame, title, tooltip)
        if not tooltip or tooltip == "" then return end
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 0.82, 0, 1, true)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local function AddOption(text, updateFunc, getStateFunc, tooltip, x, y, width, skipReloadPrompt)
        local cb, lbl = MakeVisibilityCheckbox(parentFrame, cWrap .. text .. "|r", updateFunc, getStateFunc, skipReloadPrompt)
        cb:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        lbl:SetFontObject("GameFontHighlight")
        lbl:SetWidth((width or 215) - 32)
        lbl:SetJustifyH("LEFT")
        AddTooltip(cb, text, tooltip)
        AddTooltip(lbl, text, tooltip)
        table.insert(checkboxes, cb)
        return cb
    end

    local function AddSection(text, x, y, width)
        local section = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        section:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        section:SetWidth(width or 465)
        section:SetJustifyH("LEFT")
        section:SetText(cWrap .. text .. "|r")
        return section
    end

    if IsEllesmereProvider() then
        local leftX, rightX = 15, 255
        local colWidth = 225
        local rowGap = -40

        AddOption("Apply All", SetAllHidden, GetAllHidden, nil, 300, -23, 150)

        AddSection("Visibility", leftX, -92)
        AddOption("Hide Player/Pet", SetUnitframes, GetUnitframes, "Toggles Ellesmere's Visibility Options between None and Hide without Target for Player/Pet.", leftX, -116, colWidth, true)
        AddOption("Hide CDM", SetCDMFading, GetCDMFading, "Toggles Ellesmere's Cooldown Manager and Resource Bars Visibility Options between None and Hide without Target.", rightX, -116, colWidth, true)
        AddOption("Hide Action Bars", SetMouseover, GetMouseover, "Toggles Ellesmere's Action Bar Visibility between Always and Mouseover.", leftX, -116 + rowGap, colWidth)
        AddOption("Hide Chat Background", SetChatBackgroundHidden, GetChatBackgroundHidden, "Toggles Ellesmere's Chat Settings to make a transparent background and fade.", rightX, -116 + rowGap, colWidth)
        AddOption("Chat Line Fade", SetEllesmereChatLineFade, GetEllesmereChatLineFade, "Uses Blizzard's per-line fading to hide chat lines instead of Ellesmere's entire chat fade.", leftX, -116 + rowGap * 2, colWidth)
        AddOption("Smart Player", SetEllesmereSmartPlayerPetVisibility, GetEllesmereSmartPlayerPetVisibility, "Player/Pet unit frames will show if hidden when the player or pet is not at full health.", rightX, -116 + rowGap * 2, colWidth)
        AddOption("Hide Error Messages", SetErrorMessagesHidden, GetErrorMessagesHidden, "Suppresses most red UI error text from UIErrorsFrame, useful for GSE macro spam. Important errors like full bags, full quest log, dead player/pet, and LFG boot/teleport messages still show.", leftX, -116 + rowGap * 3, colWidth, true)

        AddSection("Player Frame", leftX, -260)
        AddOption("Show Player In Group", SetEllesmereShowPlayerInParty, GetEllesmereShowPlayerInParty, "If the Player Unitframe is hidden, joining a party or raid will show the Player Unitframe.", leftX, -286, colWidth)
        AddSection("Rounded Borders", leftX, -328)
        AddOption("All Rounded Borders", SetAllRoundedBorders, GetAllRoundedBorders, "Toggles every OakUI rounded-border option in this section.", leftX, -354, colWidth, true)
        AddOption("Blizzi Interrupts", SetBlizziRoundThinBorders, GetBlizziRoundThinBorders, "Applies the OakUI round thin renderer to Blizzi Party Tools interrupt bars. Turning it off immediately falls back to Blizzi's own border settings.", rightX, -354, colWidth, true)
        AddOption("EUI Frames/Bars", SetEllesmereRoundThinBorders, GetEllesmereRoundThinBorders, "Applies the OakUI rounded border style to Ellesmere Resource Bars, Unit Frames, and Raid/Party Frames.", leftX, -384, colWidth, true)
        AddOption("Damage Meters", SetDamageMeterRoundThinBorders, GetDamageMeterRoundThinBorders, "Applies the OakUI rounded border style to Ellesmere Damage Meters. Turning it off restores the base no-border Damage Meter look.", rightX, -384, colWidth, true)
        AddOption("Cast Bars", SetCastBarRoundThinBorders, GetCastBarRoundThinBorders, "Applies the OakUI very thin rounded border to Ellesmere cast bars, including unit-frame cast bars and the resource cast bar.", leftX, -414, colWidth, true)
        AddOption("Boss Frames", SetBossFrameRoundThinBorders, GetBossFrameRoundThinBorders, "Applies the OakUI very thin rounded border to Ellesmere boss frames without enabling the full EUI Frames/Bars option.", rightX, -414, colWidth, true)
        AddOption("Tracking Bars", SetTrackingBarRoundThinBorders, GetTrackingBarRoundThinBorders, "Applies the OakUI very thin rounded border to Ellesmere Tracking Bars. Turning it off restores their previous saved border settings.", leftX, -444, colWidth, true)
        AddOption("Boss Mods", SetBossModRoundThinBorders, GetBossModRoundThinBorders, "Applies removable OakUI very thin rounded borders to live DBM and BigWigs timer bars.", rightX, -444, colWidth, true)

        parentFrame.UpdateVisibilityCheckboxes = function()
            for _, cb in ipairs(checkboxes) do cb:UpdateState() end
        end
        addonTable.RefreshVisibilityCheckboxes = function()
            if parentFrame:IsShown() then
                parentFrame:UpdateVisibilityCheckboxes()
            end
        end

        parentFrame:UpdateVisibilityCheckboxes()
        parentFrame:SetScript("OnShow", function(self)
            self:UpdateVisibilityCheckboxes()
        end)
        return
    end

    local cbAll, lblAll = MakeVisibilityCheckbox(parentFrame, cWrap .. "Apply All|r", SetAllHidden, GetAllHidden)
    cbAll:SetPoint("TOPLEFT", Desc, "BOTTOMLEFT", 0, -40)
    local dAll = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dAll:SetPoint("LEFT", lblAll, "RIGHT", 15, 0); dAll:SetText("- Applies every visibility toggle below."); dAll:SetTextColor(0.6, 0.6, 0.6)
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

    local cb5, lbl5 = MakeVisibilityCheckbox(parentFrame, cWrap .. "Hide Error Messages|r", SetErrorMessagesHidden, GetErrorMessagesHidden, true)
    cb5:SetPoint("TOPLEFT", cb4, "BOTTOMLEFT", 0, -30)
    local d5 = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d5:SetPoint("LEFT", lbl5, "RIGHT", 15, 0); d5:SetText("- Suppresses most red UI error text while keeping important errors visible."); d5:SetTextColor(0.6, 0.6, 0.6)
    table.insert(checkboxes, cb5)

    parentFrame.UpdateVisibilityCheckboxes = function()
        for _, cb in ipairs(checkboxes) do cb:UpdateState() end
    end
    addonTable.RefreshVisibilityCheckboxes = function()
        if parentFrame:IsShown() then
            parentFrame:UpdateVisibilityCheckboxes()
        end
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
        if addonTable.ApplyOakRoundThinBordersIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBordersIfEnabled)
        end
        if addonTable.ApplyOakRoundThinDamageMetersIfEnabled then
            pcall(addonTable.ApplyOakRoundThinDamageMetersIfEnabled)
        end
        if addonTable.ApplyOakRoundThinTrackingBarsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinTrackingBarsIfEnabled)
        end
        if addonTable.ApplyOakRoundThinCastBarsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinCastBarsIfEnabled)
        end
        if addonTable.ApplyOakRoundThinBossFramesIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBossFramesIfEnabled)
        end
        if addonTable.ApplyOakRoundThinBossModBarsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBossModBarsIfEnabled)
        end
        if addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled)
        end
        if addonTable.ApplyOakErrorMessageVisibility then
            pcall(addonTable.ApplyOakErrorMessageVisibility)
        end
    end)
    self:UnregisterEvent("PLAYER_LOGIN")
end)
