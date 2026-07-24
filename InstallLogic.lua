local addonName, addonTable = ...
local P = addonTable.Profiles

addonTable.Injectors = {}

local function TrimProfileString(profileString)
    return string.gsub(profileString or "", "^%s+", ""):gsub("%s+$", "")
end

function addonTable.Injectors.Details(profileName, role)
    local Details = _G._detalhes
    if not Details then return end
    local cleanStr = string.gsub(P.DETAILS_PROFILE, "%s+", "")
    Details:EraseProfile(profileName)
    Details:ImportProfile(cleanStr, profileName)
    if Details:GetCurrentProfileName() ~= profileName then Details:ApplyProfile(profileName) end
end

function addonTable.Injectors.Platynator(profileName, role)
    if _G.Platynator and _G.Platynator.API and type(_G.Platynator.API.ImportString) == "function" then
        local encoded = TrimProfileString(P.PLATYNATOR_PROFILE)
        if encoded == "" then
            print("|cffff0000[OakUI Error]|r Platynator profile string is missing or empty.")
            return
        end

        local ok, result = pcall(_G.Platynator.API.ImportString, encoded, profileName)
        if not ok then
            print("|cffff0000[OakUI Error]|r Platynator import failed: " .. tostring(result))
            return
        elseif result == false then
            print("|cffff0000[OakUI Error]|r Platynator import failed.")
            return
        end
    end
end

function addonTable.Injectors.XIV(profileName, role)
    local AceAddon = _G.LibStub("AceAddon-3.0", true)
    if not AceAddon then return end
    local XIVBar = AceAddon:GetAddon("XIV_Databar_Continued", true)
    if XIVBar and type(XIVBar.ImportProfile) == "function" then
        local encoded = TrimProfileString(P.XIV_PROFILE)
        if encoded == "" then
            print("|cffff0000[OakUI Error]|r XIV_Databar profile string is missing or empty.")
            return
        end

        local ok, result = pcall(XIVBar.ImportProfile, XIVBar, encoded)
        if not ok then
            print("|cffff0000[OakUI Error]|r XIV_Databar import failed: " .. tostring(result))
        elseif result == false then
            print("|cffff0000[OakUI Error]|r XIV_Databar import failed.")
        end
    end
end

local function DecodeChonkyProfile(encoded)
    local LibDeflate = _G.LibStub and _G.LibStub("LibDeflate", true)
    if not LibDeflate then return nil, "LibDeflate is unavailable." end

    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then return nil, "Could not decode the profile string." end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "Could not decompress the profile string." end

    local loader, err = loadstring("return " .. decompressed)
    if not loader then return nil, err or "Could not parse the profile data." end

    local ok, data = pcall(loader)
    if not ok or type(data) ~= "table" then
        return nil, data or "Profile data was not a table."
    end
    return data
end

local function GetChonkyProfileKey(profile)
    local playerKey = (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
    local useGlobal = true
    if ChonkyCharacterSheetDB and ChonkyCharacterSheetDB.profiles and ChonkyCharacterSheetDB.profiles[playerKey] then
        useGlobal = ChonkyCharacterSheetDB.profiles[playerKey].globalprofile
    end
    if profile and profile.globalprofile == false then useGlobal = false end
    return useGlobal == false and playerKey or "default"
end

function addonTable.Injectors.ChonkyCharacterSheet(profileName, role)
    if not C_AddOns.IsAddOnLoaded("ChonkyCharacterSheet") then return end
    local encoded = string.gsub(P.CHONKY_PROFILE or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r Chonky Character Sheet profile string is missing or empty.")
        return
    end

    local profile, err = DecodeChonkyProfile(encoded)
    if not profile then
        print("|cffff0000[OakUI Error]|r Chonky Character Sheet import failed: " .. tostring(err))
        return
    end

    ChonkyCharacterSheetDB = ChonkyCharacterSheetDB or { default = {}, profiles = {} }
    ChonkyCharacterSheetDB.profiles = ChonkyCharacterSheetDB.profiles or {}
    ChonkyCharacterSheetDB.profiles[GetChonkyProfileKey(profile)] = profile
end

function addonTable.Injectors.MPlusTimer(profileName, role)
    if not C_AddOns.IsAddOnLoaded("MPlusTimer") then return end
    local encoded = string.gsub(P.MPLUSTIMER_PROFILE or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r MPlusTimer profile string is missing or empty.")
        return
    end
    if not _G.MPTAPI or type(_G.MPTAPI.ImportProfile) ~= "function" then
        print("|cffff0000[OakUI Error]|r MPlusTimer import API is unavailable.")
        return
    end

    if MPTSV and MPTSV.Profiles then MPTSV.Profiles[profileName] = nil end
    local ok, result = pcall(_G.MPTAPI.ImportProfile, _G.MPTAPI, encoded, profileName, true)
    if not ok or result ~= true then
        print("|cffff0000[OakUI Error]|r MPlusTimer import failed: " .. tostring(result))
    end
end

local function ApplyBaseActionBarCVars()
    if SetActionBarToggles then SetActionBarToggles(1, 1, 1, 1, 1) end
    SetCVar("MultiBarBottomLeft", 1)
    SetCVar("MultiBarBottomRight", 1)
    SetCVar("MultiBarRight", 1)
    SetCVar("MultiBarLeft", 1)
    SetCVar("alwaysShowActionBars", 1)
    if Settings and Settings.SetValue then
        pcall(function()
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_2", true)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_3", true)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_4", true)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_5", true)
            Settings.SetValue("PROXY_ALWAYS_SHOW_ACTIONBARS", true)
        end)
    end
    if MultiActionBar_Update then MultiActionBar_Update() end
end

local function SetCVarSafe(name, value)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, tostring(value))
    elseif SetCVar then
        pcall(SetCVar, name, value)
    end
end

local function ApplyBaseNameplateCVars()
    SetCVarSafe("nameplateShowAll", 1)
    SetCVarSafe("nameplateShowEnemies", 1)

    local hyperframeSettings = _G.HF_SETTINGS
    if type(hyperframeSettings) ~= "table" then return end

    for key in pairs(hyperframeSettings) do
        if type(key) == "string" and key:match("_nameplateShowAll$") then
            hyperframeSettings[key] = true
        elseif type(key) == "string" and key:match("_nameplateShowAllDisable$") then
            hyperframeSettings[key] = true
        end
    end
end

local nameplateCVarFrame = CreateFrame("Frame")
nameplateCVarFrame:RegisterEvent("PLAYER_LOGIN")
nameplateCVarFrame:RegisterEvent("ADDON_LOADED")
nameplateCVarFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Hyperframe" then return end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1, ApplyBaseNameplateCVars)
    else
        ApplyBaseNameplateCVars()
    end
end)

local function GetElvUICore()
    local E = _G.ElvUI and _G.ElvUI[1]
    if not E and type(_G.ElvUI) == "table" then
        local ok, core = pcall(function() return unpack(_G.ElvUI) end)
        if ok then E = core end
    end
    return E
end

local function HideElvUIInstaller(E)
    if not E then return end
    if E.private then E.private.install_complete = E.version or true end
    if E.InstallFrame and E.InstallFrame.Hide then E.InstallFrame:Hide() end
    if _G.ElvUIInstallFrame and _G.ElvUIInstallFrame.Hide then _G.ElvUIInstallFrame:Hide() end
end

local function DisablePlatynatorConflictWarning(E)
    if not E then return end
    local addons = E.INCOMPATIBLE_ADDONS and E.INCOMPATIBLE_ADDONS.NamePlates
    if type(addons) == "table" then
        for i = #addons, 1, -1 do
            if addons[i] == "Platynator" then
                table.remove(addons, i)
            end
        end
    end

    if type(E.IncompatibleAddOn) == "function" and not E.OakUIIncompatibleHooked then
        local original = E.IncompatibleAddOn
        E.IncompatibleAddOn = function(self, addon, module, info)
            if addon == "Platynator" then return end
            return original(self, addon, module, info)
        end
        E.OakUIIncompatibleHooked = true
    end

    if E.StaticPopup_Hide then
        pcall(E.StaticPopup_Hide, E, "INCOMPATIBLE_ADDON")
    end
end

function addonTable.BypassElvUIInstaller()
    if not C_AddOns.IsAddOnLoaded("ElvUI") then return end
    local E = GetElvUICore()
    HideElvUIInstaller(E)
    DisablePlatynatorConflictWarning(E)
end

local function RefreshEllesmereAfterProfileImport()
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshAllAddons) == "function" then
        pcall(_G.EllesmereUI.RefreshAllAddons, _G.EllesmereUI)
    end
end

local function GetCurrentEllesmereSpecKey()
    if type(_G._ECME_GetCurrentSpecKey) == "function" then
        local ok, specKey = pcall(_G._ECME_GetCurrentSpecKey)
        if ok and specKey and tostring(specKey) ~= "0" then return tostring(specKey) end
    end

    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    return specID and tostring(specID) or nil
end

local function GetCurrentPlayerSpecRole()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return nil end

    if GetSpecializationInfo then
        local _, _, _, _, role = GetSpecializationInfo(specIndex)
        if role then return role end
    end

    if GetSpecializationRole then
        local ok, role = pcall(GetSpecializationRole, specIndex)
        if ok then return role end
    end
end

local function ForEachKnownSpec(callback)
    if type(callback) ~= "function" then return end
    if type(GetSpecializationInfoForClassID) == "function" then
        for classID = 1, 20 do
            for specIndex = 1, 4 do
                local specID, _, _, _, role = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and role then
                    callback(specID, role)
                end
            end
        end
        return
    end

    local specIndex = GetSpecialization and GetSpecialization()
    local specID, _, _, _, role = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    if specID and role then
        callback(specID, role)
    end
end

function addonTable.AssignOakEllesmereProfilesToSpecs(dpsProfileName, healerProfileName)
    if type(_G.EllesmereUIDB) ~= "table" then return false end
    local db = _G.EllesmereUIDB
    db.specProfiles = db.specProfiles or {}

    if addonTable.RegisterOakRoleProfileName then
        addonTable.RegisterOakRoleProfileName("dps", dpsProfileName)
        addonTable.RegisterOakRoleProfileName("heals", healerProfileName)
    end

    for specID, profileName in pairs(db.specProfiles) do
        if profileName == dpsProfileName or profileName == healerProfileName then
            db.specProfiles[specID] = nil
        end
    end

    ForEachKnownSpec(function(specID, role)
        if role == "HEALER" and healerProfileName and healerProfileName ~= "" then
            db.specProfiles[specID] = healerProfileName
        elseif dpsProfileName and dpsProfileName ~= "" then
            db.specProfiles[specID] = dpsProfileName
        end
    end)

    local currentSpec = GetCurrentEllesmereSpecKey()
    local currentProfile = currentSpec and db.specProfiles[tonumber(currentSpec) or currentSpec]
    if currentProfile and db.profiles and db.profiles[currentProfile] then
        db.activeProfile = currentProfile
    elseif dpsProfileName and db.profiles and db.profiles[dpsProfileName] then
        db.activeProfile = dpsProfileName
    end
    if db.activeProfile then
        db.lastNonSpecProfile = db.activeProfile
    end

    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshAllAddons) == "function" then
        pcall(_G.EllesmereUI.RefreshAllAddons, _G.EllesmereUI)
    end
    return true
end

function addonTable.SetOakInstallActiveEllesmereProfile(dpsProfileName, healerProfileName, installedDPS, installedHeals)
    if type(_G.EllesmereUIDB) ~= "table" then return false end
    local db = _G.EllesmereUIDB
    local profiles = db.profiles
    if type(profiles) ~= "table" then return false end

    local targetProfile
    if installedDPS and installedHeals then
        targetProfile = GetCurrentPlayerSpecRole() == "HEALER" and healerProfileName or dpsProfileName
    elseif installedHeals then
        targetProfile = healerProfileName
    elseif installedDPS then
        targetProfile = dpsProfileName
    end

    if not targetProfile or targetProfile == "" or type(profiles[targetProfile]) ~= "table" then
        return false
    end

    local EUI = _G.EllesmereUI
    local switched = false
    if EUI and type(EUI.SwitchProfile) == "function" then
        switched = pcall(EUI.SwitchProfile, targetProfile)
    end

    if not switched then
        db.activeProfile = targetProfile
    end
    db.lastNonSpecProfile = targetProfile

    if EUI and type(EUI.RefreshAllAddons) == "function" then
        pcall(EUI.RefreshAllAddons, EUI)
    end
    return true
end

local OAK_CDM_RACE_RACIALS = {
    Scourge = { 7744 },
    Tauren = { 20549 },
    Orc = { 20572, 33697, 33702 },
    BloodElf = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
    Dwarf = { 20594 },
    Troll = { 26297 },
    Draenei = { 28880, 59543, 59545, 121093, 59544, 370626, 59547, 59548, 59542, 416250 },
    NightElf = { 58984 },
    Human = { 59752 },
    DarkIronDwarf = { 265221 },
    Gnome = { 20589 },
    HighmountainTauren = { 255654 },
    Worgen = { 68992 },
    Goblin = { 69070 },
    Pandaren = { 107079 },
    MagharOrc = { 274738 },
    LightforgedDraenei = { 255647 },
    VoidElf = { 256948 },
    KulTiran = { 287712 },
    ZandalariTroll = { 291944 },
    Vulpera = { 312411 },
    Mechagnome = { 312924 },
    Nightborne = { 260364 },
    Dracthyr = { { 357214, notClass = "EVOKER" } },
    EarthenDwarf = { 436344 },
    Haranir = { 1237885 },
}

local function OakDeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[OakDeepCopy(k, seen)] = OakDeepCopy(v, seen)
    end
    return copy
end

local function GetCurrentRacialSet()
    local race = select(2, UnitRace("player"))
    local class = select(2, UnitClass("player"))
    local set = {}
    for _, entry in ipairs(OAK_CDM_RACE_RACIALS[race] or {}) do
        local spellID = type(entry) == "table" and entry[1] or entry
        local requiredClass = type(entry) == "table" and entry.class or nil
        local excludedClass = type(entry) == "table" and entry.notClass or nil
        if spellID and (not requiredClass or requiredClass == class) and (not excludedClass or excludedClass ~= class) then
            set[spellID] = true
        end
    end
    return set
end

local function GetActiveCDMSpecProfile(db, profileName, specKey)
    db.spellAssignments = db.spellAssignments or { profiles = {} }
    local spellStore = db.spellAssignments
    spellStore.profiles = spellStore.profiles or {}
    local bucket = spellStore.profiles[profileName]
    if type(bucket) ~= "table" then
        bucket = { specProfiles = {} }
        if not spellStore._perProfileSeeded and type(spellStore.specProfiles) == "table" and next(spellStore.specProfiles) then
            bucket.specProfiles = OakDeepCopy(spellStore.specProfiles)
        end
        spellStore.profiles[profileName] = bucket
    end
    bucket.specProfiles = bucket.specProfiles or {}
    local specProfile = bucket.specProfiles[specKey]
    if type(specProfile) ~= "table" then
        specProfile = { barSpells = {} }
        bucket.specProfiles[specKey] = specProfile
    end
    specProfile.barSpells = specProfile.barSpells or {}
    return specProfile
end

local function GetCDMBarSpellData(specProfile, barKey)
    if not specProfile or not barKey then return nil end
    local spellData = specProfile.barSpells[barKey]
    if type(spellData) ~= "table" then
        spellData = {}
        specProfile.barSpells[barKey] = spellData
    end
    return spellData
end

local function IsOakCDMUserAddedSpell(spellData, spellID, racialSet)
    if type(spellID) ~= "number" or spellID == 0 then return false end
    if spellID < 0 then return true end
    if spellData.customSpellIDs and spellData.customSpellIDs[spellID] then return true end
    if racialSet and racialSet[spellID] then return true end
    if spellData.spellDurations and (spellData.spellDurations[spellID] or 0) > 0 then return true end
    return false
end

local function FilterCDMListPreservingUserAdded(spellData, list, racialSet)
    if type(spellData) ~= "table" or type(list) ~= "table" then return false end
    local changed = false
    local writeIndex = 1
    for readIndex = 1, #list do
        local spellID = list[readIndex]
        if IsOakCDMUserAddedSpell(spellData, spellID, racialSet) then
            list[writeIndex] = spellID
            writeIndex = writeIndex + 1
        else
            changed = true
        end
    end
    for index = writeIndex, #list do
        list[index] = nil
        changed = true
    end
    return changed
end

local function FilterCDMSetPreservingUserAdded(spellData, set, racialSet)
    if type(spellData) ~= "table" or type(set) ~= "table" then return false end
    local changed = false
    for spellID in pairs(set) do
        if not IsOakCDMUserAddedSpell(spellData, spellID, racialSet) then
            set[spellID] = nil
            changed = true
        end
    end
    return changed
end

local function ShouldOakRepopulateCDMBar(barData)
    if type(barData) ~= "table" or barData.isGhostBar or barData.key == "buffs" then return false end
    return barData.barType == "cooldowns"
        or barData.barType == "utility"
        or barData.barType == "buffs"
        or barData.key == "cooldowns"
        or barData.key == "utility"
        or barData.key == "__ghost_cd"
end

local function FrameHasText(frame, text)
    if not frame or not text then return false end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            local value = region:GetText()
            if value == text or (type(value) == "string" and value:find(text, 1, true)) then
                return true
            end
        end
    end
    return false
end

local function FindButtonByText(frame, text)
    if not frame then return nil end
    if frame.GetObjectType and frame:GetObjectType() == "Button" and FrameHasText(frame, text) then
        return frame
    end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        local found = FindButtonByText(child, text)
        if found then return found end
    end
    return nil
end

local function TryEllesmereNativeCDMRepopulate()
    if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("EllesmereUICooldownManager") then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "EllesmereUICooldownManager")
        end
    end

    local EUI = _G.EllesmereUI
    local module = EUI and EUI._modules and EUI._modules.EllesmereUICooldownManager
    if not EUI or not module or type(module.buildPage) ~= "function" or type(EUI.ShowConfirmPopup) ~= "function" then
        return false
    end

    local hidden = CreateFrame("Frame", nil, UIParent)
    hidden:SetSize(1200, 2200)
    hidden:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -3000, -3000)
    hidden:SetAlpha(0)
    hidden:Hide()

    local oldPrebuilding = EUI._prebuilding
    local oldBuildingModule = EUI._buildingModule
    local oldBuildingPage = EUI._buildingPage
    local oldShowConfirmPopup = EUI.ShowConfirmPopup
    local repopulated = false

    EUI._prebuilding = true
    EUI._buildingModule = "EllesmereUICooldownManager"
    EUI._buildingPage = "CDM Bars"
    EUI.ShowConfirmPopup = function(self, opts)
        if type(opts) == "table" and opts.title == "Repopulate Bars" and type(opts.onConfirm) == "function" then
            repopulated = true
            opts.onConfirm()
            return
        end
        return oldShowConfirmPopup(self, opts)
    end

    local ok = pcall(module.buildPage, "CDM Bars", hidden, -10)
    if ok then
        local button = FindButtonByText(hidden, "Repopulate from Blizzard CDM") or FindButtonByText(hidden, "Repopulate")
        if button then
            local click = button:GetScript("OnClick")
            if type(click) == "function" then
                pcall(click, button, "LeftButton")
            elseif button.Click then
                pcall(button.Click, button)
            end
        end
    end

    EUI.ShowConfirmPopup = oldShowConfirmPopup
    EUI._prebuilding = oldPrebuilding
    EUI._buildingModule = oldBuildingModule
    EUI._buildingPage = oldBuildingPage
    hidden:Hide()
    hidden:SetParent(nil)

    return repopulated == true
end

function addonTable.RepopulateActiveEllesmereCDMFromBlizzard(quiet)
    if TryEllesmereNativeCDMRepopulate() then
        if not quiet then
            print("|cff17ee15[OakUI]|r Repopulated Ellesmere CDM from Blizzard CDM.")
        end
        return true
    end
    if quiet then return false end
    if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("EllesmereUICooldownManager") then return false end

    local db = _G.EllesmereUIDB
    if type(db) ~= "table" then return false end

    local profileName = db.activeProfile or "Default"
    local profile = db.profiles and db.profiles[profileName]
    local cdmProfile = profile
        and profile.addons
        and profile.addons.EllesmereUICooldownManager
    local bars = cdmProfile and cdmProfile.cdmBars and cdmProfile.cdmBars.bars
    if type(bars) ~= "table" then return false end

    local specKey = GetCurrentEllesmereSpecKey()
    if not specKey or specKey == "0" then return false end
    local specProfile = GetActiveCDMSpecProfile(db, profileName, specKey)
    local racialSet = GetCurrentRacialSet()
    local changed = false

    for _, barData in ipairs(bars) do
        if ShouldOakRepopulateCDMBar(barData) and barData.key then
            local spellData = GetCDMBarSpellData(specProfile, barData.key)
            changed = FilterCDMListPreservingUserAdded(spellData, spellData.assignedSpells, racialSet) or changed
            changed = FilterCDMSetPreservingUserAdded(spellData, spellData.removedSpells, racialSet) or changed
        end
    end

    local ghostSpellData = GetCDMBarSpellData(specProfile, "__ghost_cd")
    changed = FilterCDMListPreservingUserAdded(ghostSpellData, ghostSpellData.assignedSpells, racialSet) or changed
    changed = FilterCDMSetPreservingUserAdded(ghostSpellData, ghostSpellData.removedSpells, racialSet) or changed

    local buffSpellData = GetCDMBarSpellData(specProfile, "buffs")
    if buffSpellData then
        if buffSpellData.buffDisplayOrder ~= nil then changed = true end
        if buffSpellData._buffDisplayOrderUserModified ~= nil then changed = true end
        buffSpellData.buffDisplayOrder = nil
        buffSpellData._buffDisplayOrderUserModified = nil
    end

    if type(_G._ECME_Apply) == "function" then
        pcall(_G._ECME_Apply)
    end
    if _G.EllesmereUI and type(_G.EllesmereUI.CDMReconcileActiveSpecSpells) == "function" then
        pcall(_G.EllesmereUI.CDMReconcileActiveSpecSpells)
    end
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshAllAddons) == "function" then
        pcall(_G.EllesmereUI.RefreshAllAddons, _G.EllesmereUI)
    end

    if not quiet then
        print("|cff17ee15[OakUI]|r Repopulated Ellesmere CDM from Blizzard CDM.")
    end
    return true
end

function addonTable.Injectors.Ellesmere(profileName, role)
    if not C_AddOns.IsAddOnLoaded("EllesmereUI") then return end
    profileName = profileName or "OakUI"

    ApplyBaseActionBarCVars()
    if addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end

    local healerEncoded = role == "heals" and TrimProfileString(P.ELLESMERE_PROFILE_HEALS) or ""
    local encoded = healerEncoded ~= "" and healerEncoded or TrimProfileString(P.ELLESMERE_PROFILE)
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r EllesmereUI profile string is missing or empty.")
        return
    end

    if not _G.EllesmereUI or type(_G.EllesmereUI.ImportProfile) ~= "function" then
        print("|cffff0000[OakUI Error]|r EllesmereUI import API is unavailable.")
        return
    end

    local ok, success, err = pcall(_G.EllesmereUI.ImportProfile, encoded, profileName)
    if not ok then
        print("|cffff0000[OakUI Error]|r EllesmereUI import failed: " .. tostring(success))
    elseif not success then
        print("|cffff0000[OakUI Error]|r EllesmereUI import failed: " .. tostring(err))
    else
        if addonTable.RegisterOakRoleProfileName then
            addonTable.RegisterOakRoleProfileName(role, profileName)
        end
        if type(_G.EllesmereUIDB) == "table" and addonTable.ApplyOakEllesmereUIScale then
            addonTable.ApplyOakEllesmereUIScale(_G.EllesmereUIDB)
        end
        if type(_G.EllesmereUIDB) == "table" and addonTable.ApplyOakEllesmereLayoutAdjustments then
            addonTable.ApplyOakEllesmereLayoutAdjustments(_G.EllesmereUIDB, profileName, role)
        end
        if addonTable.ApplyOakRoundThinBordersIfEnabled then
            local borderOk, borderErr = pcall(addonTable.ApplyOakRoundThinBordersIfEnabled, profileName)
            if not borderOk then
                print("|cffff0000[OakUI Error]|r Ellesmere round thin borders failed: " .. tostring(borderErr))
            end
        end
        if addonTable.ApplyOakRoundThinDamageMetersIfEnabled then
            local damageBorderOk, damageBorderErr = pcall(addonTable.ApplyOakRoundThinDamageMetersIfEnabled, profileName)
            if not damageBorderOk then
                print("|cffff0000[OakUI Error]|r Damage Meter round thin borders failed: " .. tostring(damageBorderErr))
            end
        end
        if addonTable.ApplyOakRoundThinTrackingBarsIfEnabled then
            local trackingBorderOk, trackingBorderErr = pcall(addonTable.ApplyOakRoundThinTrackingBarsIfEnabled, profileName)
            if not trackingBorderOk then
                print("|cffff0000[OakUI Error]|r Tracking Bar round thin borders failed: " .. tostring(trackingBorderErr))
            end
        end
        if addonTable.ApplyOakRoundThinCastBarsIfEnabled then
            local castBorderOk, castBorderErr = pcall(addonTable.ApplyOakRoundThinCastBarsIfEnabled, profileName)
            if not castBorderOk then
                print("|cffff0000[OakUI Error]|r Cast Bar round thin borders failed: " .. tostring(castBorderErr))
            end
        end
        if addonTable.ApplyOakRoundThinNameplatesIfEnabled then
            local nameplateBorderOk, nameplateBorderErr = pcall(addonTable.ApplyOakRoundThinNameplatesIfEnabled, profileName)
            if not nameplateBorderOk then
                print("|cffff0000[OakUI Error]|r Nameplate round thin borders failed: " .. tostring(nameplateBorderErr))
            end
        end
        if addonTable.ApplyOakRoundThinBossFramesIfEnabled then
            local bossBorderOk, bossBorderErr = pcall(addonTable.ApplyOakRoundThinBossFramesIfEnabled, profileName)
            if not bossBorderOk then
                print("|cffff0000[OakUI Error]|r Boss Frame round thin borders failed: " .. tostring(bossBorderErr))
            end
        end
        RefreshEllesmereAfterProfileImport()
    end
end

function addonTable.Injectors.BaseUI(profileName, role)
    return addonTable.Injectors.Ellesmere(profileName, role)
end

local function SetBigWigsTimelineCVar(name, enabled)
    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar(name, enabled and "1" or "0")
    end
end

local function ApplyBigWigsTimelineSettings(profileName)
    SetBigWigsTimelineCVar("combatWarningsEnabled", true)
    SetBigWigsTimelineCVar("encounterTimelineEnabled", true)
    SetBigWigsTimelineCVar("encounterTimelineHideLongCountdowns", true)
    SetBigWigsTimelineCVar("encounterTimelineHideQueuedCountdowns", true)
    SetBigWigsTimelineCVar("encounterTimelineHideForOtherRoles", true)
    SetBigWigsTimelineCVar("encounterTimelineIconographyEnabled", true)

    if C_CVar and C_CVar.SetCVarBitfield and Enum and Enum.EncounterTimelineIconSet then
        for _, iconSet in pairs(Enum.EncounterTimelineIconSet) do
            if type(iconSet) == "number" then
                C_CVar.SetCVarBitfield("encounterTimelineIconographyHiddenMask", iconSet, false)
            end
        end
    else
        SetBigWigsTimelineCVar("encounterTimelineIconographyHiddenMask", false)
    end

    local timelinePlugin = _G.BigWigs and _G.BigWigs.GetPlugin and _G.BigWigs:GetPlugin("Timeline", true)
    if timelinePlugin and timelinePlugin.db and timelinePlugin.db.profile then
        timelinePlugin.db.profile.blizzTimeline = true
        timelinePlugin.db.profile.timersMode = "enhanced"
    end

    if type(BigWigs3DB) == "table" then
        BigWigs3DB.namespaces = BigWigs3DB.namespaces or {}
        local timelineDB = BigWigs3DB.namespaces.BigWigs_Plugins_Timeline
        if type(timelineDB) == "table" then
            timelineDB.profiles = timelineDB.profiles or {}
            profileName = profileName or "OakUI"
            timelineDB.profiles[profileName] = timelineDB.profiles[profileName] or {}
            timelineDB.profiles[profileName].blizzTimeline = true
            timelineDB.profiles[profileName].timersMode = "enhanced"
        end
    end
end

function addonTable.Injectors.BigWigs(profileName, role)
    if not C_AddOns.IsAddOnLoaded("BigWigs") then return end
    local encoded = string.gsub(P.BIGWIGS_PROFILE or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then return end

    -- Use the official BigWigs Import API
    if _G.BigWigsAPI and type(_G.BigWigsAPI.RegisterProfile) == "function" then
        pcall(function()
            _G.BigWigsAPI.RegisterProfile("OakUI", encoded, profileName)
        end)
        ApplyBigWigsTimelineSettings(profileName)
        if addonTable.ApplyOakRoundThinBossModBarsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBossModBarsIfEnabled)
        end
    else
        print("|cffff0000[OakUI]|r Your version of BigWigs is too old. Please update BigWigs to import the profile.")
    end
end

local function DecodeDBMProfile(encoded)
    if not encoded or encoded == "" then return nil, "Profile string is empty." end

    if C_EncodingUtil then
        local ok, deserialized = pcall(function()
            local decoded = C_EncodingUtil.DecodeBase64 and C_EncodingUtil.DecodeBase64(encoded, 0)
            local decompressed = decoded and C_EncodingUtil.DecompressString and C_EncodingUtil.DecompressString(decoded, 0)
            return decompressed and C_EncodingUtil.DeserializeCBOR and C_EncodingUtil.DeserializeCBOR(decompressed)
        end)
        if ok and type(deserialized) == "table" then
            return deserialized
        end
    end

    local LibStub = _G.LibStub
    local LibDeflate = LibStub and LibStub("LibDeflate", true)
    local LibSerialize = LibStub and LibStub("LibSerialize", true)
    if LibDeflate and LibSerialize then
        local legacyDecoded = LibDeflate:DecodeForPrint(encoded)
        local legacyDecompressed = legacyDecoded and LibDeflate:DecompressDeflate(legacyDecoded)
        if legacyDecompressed then
            local ok, legacyDeserialized = LibSerialize:Deserialize(legacyDecompressed)
            if ok and type(legacyDeserialized) == "table" then
                return legacyDeserialized
            end
        end
    end

    return nil, "Could not decode the DBM profile string."
end

function addonTable.Injectors.DBM(profileName, role)
    if not C_AddOns.IsAddOnLoaded("DBM-Core") then return end
    local encoded = TrimProfileString(P.DBM_PROFILE)
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r DBM profile string is missing or empty.")
        return
    end

    local importTable, err = DecodeDBMProfile(encoded)
    if type(importTable) ~= "table" then
        print("|cffff0000[OakUI Error]|r DBM import failed: " .. tostring(err))
        return
    end
    if type(importTable.DBM) ~= "table" or type(importTable.DBT) ~= "table" or type(importTable.minimap) ~= "table" then
        print("|cffff0000[OakUI Error]|r DBM profile string is not a DBM core profile export.")
        return
    end

    profileName = profileName or "OakUI"
    DBM_AllSavedOptions = DBM_AllSavedOptions or {}
    DBT_AllPersistentOptions = DBT_AllPersistentOptions or {}
    DBM_AllSavedOptions[profileName] = importTable.DBM
    DBT_AllPersistentOptions[profileName] = importTable.DBT
    DBM_MinimapIcon = importTable.minimap

    DBM_UsedProfile = profileName
    if _G.DBM and type(_G.DBM.ApplyProfile) == "function" then
        _G.DBM:ApplyProfile(profileName)
    end
    if addonTable.ApplyOakRoundThinBossModBarsIfEnabled then
        pcall(addonTable.ApplyOakRoundThinBossModBarsIfEnabled)
    end

    if _G.LibStub and type(importTable.minimap.hide) == "boolean" then
        local LibDBIcon = _G.LibStub("LibDBIcon-1.0", true)
        if LibDBIcon then
            if importTable.minimap.hide then
                LibDBIcon:Hide("DBM")
            else
                LibDBIcon:Show("DBM")
            end
        end
    end
end

function addonTable.Injectors.BlizziPartyTools(profileName, role)
    if not C_AddOns.IsAddOnLoaded("BliZzi_Interrupts") then return end
    local healerEncoded = role == "heals" and TrimProfileString(P.BLIZZI_PARTY_TOOLS_HEALS_PROFILE) or ""
    local encoded = healerEncoded ~= "" and healerEncoded or TrimProfileString(P.BLIZZI_PARTY_TOOLS_PROFILE)
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r Blizzi Party Tools profile string is missing or empty.")
        return
    end

    local BIT = _G.BIT
    if BIT and BIT.Profiles and type(BIT.Profiles.Import) == "function" then
        local ok, success, result = pcall(BIT.Profiles.Import, BIT.Profiles, profileName or "OakUI", encoded)
        if not ok then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(success))
        elseif not success then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(result))
        end
        if addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled)
        end
        if ok and success and addonTable.RegisterOakRoleProfileName then
            addonTable.RegisterOakRoleProfileName(role, profileName or "OakUI")
        end
        return
    end

    if BIT and type(BIT.ImportProfile) == "function" then
        local ok, success, result = pcall(BIT.ImportProfile, encoded)
        if not ok then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(success))
        elseif not success then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(result))
        end
        if addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled then
            pcall(addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled)
        end
        return
    end

    print("|cffff0000[OakUI Error]|r Blizzi Party Tools import API is unavailable.")
end

local OAK_EDIT_MODE_STRING = "2 50 0 0 0 4 4 UIParent -0.0 -560.0 -1 ##$$%/&%'%)$+$,$ 0 1 0 6 8 MainActionBar 4.0 0.0 -1 ##$&%,&%'%(#,$ 0 2 0 8 2 MainActionBar 0.0 4.0 -1 ##$$%/&%'%(#,$ 0 3 0 8 6 MainActionBar -4.0 0.0 -1 ##$&%,&%'%(#,$ 0 4 0 7 7 UIParent 360.0 42.0 -1 #$$'%)&&'%(#,# 0 5 0 4 4 UIParent 240.0 -400.0 -1 ##$%%)&%'%(#,# 0 6 0 0 0 UIParent 548.7 -1122.3 -1 ##$$%)&#'%(&,# 0 7 0 4 4 UIParent -448.0 -560.0 -1 ##$$%)&#'%(&,# 0 10 0 6 0 MultiBarBottomRight 0.0 4.0 -1 ##$$&%'% 0 11 0 7 7 UIParent 84.2 97.8 -1 ##$$&%'%,# 0 12 0 0 0 UIParent 870.0 -1040.8 -1 ##$$&('% 1 -1 0 7 7 UIParent 0.0 134.0 -1 ##$#%$ 2 -1 0 1 1 UIParent 949.4 -1.8 -1 ##$#%) 3 0 0 1 1 UIParent -261.0 -806.0 -1 $#3# 3 1 0 1 1 UIParent 260.0 -804.0 -1 %$3# 3 2 0 0 0 UIParent 1353.8 -878.3 -1 %#&#3# 3 3 0 0 0 UIParent 516.7 -1142.0 -1 '$(#)#-k.)/#1#3&5#6(7-7$ 3 4 0 0 0 UIParent 211.0 -1092.0 -1 ,#-#.'/#0$1#2(5#6(7-7$ 3 5 0 2 2 UIParent -251.8 -98.7 -1 &$*$3, 3 6 0 2 2 UIParent -296.0 -321.2 -1 -#.#/#4&5#6(7-7$ 3 7 0 5 5 UIParent -1364.7 -312.7 -1 3# 4 -1 0 7 7 UIParent 0.0 1082.0 -1 # 5 -1 0 8 8 UIParent -384.2 30.3 -1 # 6 0 0 1 1 UIParent -497.2 -2.0 -1 ##$#%$&C(()( 6 1 0 1 7 BuffFrame -275.3 -4.0 -1 ##$#%$'3(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 0 4 4 UIParent 0.0 -379.5 -1 # 8 -1 0 6 6 UIParent 4.0 54.4 -1 #'$q%$&T 9 -1 0 7 7 UIParent 325.8 2.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 0 5 5 UIParent -296.3 99.5 -1 # 12 -1 0 0 0 UIParent 1913.3 -192.3 -1 #4$#%# 13 -1 0 6 8 MainMenuBarVehicleLeaveButton 4.0 0.0 -1 ##$#%#&( 14 -1 0 6 8 MicroMenuContainer 3.5 -0.5 -1 #$$#%# 15 0 0 1 1 UIParent 0.0 -2.0 -1 # 15 1 0 2 8 MainStatusTrackingBarContainer 0.0 -4.0 -1 # 16 -1 0 6 8 VehicleSeatIndicator 3.5 0.5 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 0 6 8 ChatFrame1 28.2 -32.8 -1 #( 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 0 1 4 UIParent 0.0 -222.0 -1 ##$7%$&(''(-($)#+$,$-$ 20 1 0 1 4 UIParent 0.0 -262.0 -1 ##$+%$&(''(=)#+$,$-$ 20 2 0 7 4 UIParent 0.0 -193.0 -1 ##$$%$&(''(-($)#+$,$-$ 20 3 0 1 4 UIParent 0.0 -322.0 -1 #$$$%#&('#(-($)#*#+$,$-$.$.$ 21 -1 0 4 4 UIParent -414.5 -150.0 -1 ##$# 22 0 0 4 4 UIParent 416.0 34.8 -1 #$$$%$&(''(-($)5*$+$,$-#.#/U0% 22 1 0 1 1 UIParent 0.0 -282.0 -1 &('()U*#+$ 22 2 0 4 4 UIParent 0.0 340.0 -1 &('()U*#+$ 22 3 0 4 4 UIParent -0.0 380.0 -1 &('()U*#+$ 23 -1 0 0 0 UIParent 1810.5 -1007.0 -1 ##$#%$&7'P($)U+$,$-$.(/"
local function GetOakEditModeString()
    return P.EDITMODE_PROFILE or OAK_EDIT_MODE_STRING
end

function addonTable.Injectors.GetEditMode() return GetOakEditModeString() end

local function GetEditModePresetCount()
    if Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues then
        return Enum.EditModePresetLayoutsMeta.NumValues
    end
    return 2
end

local function FindEditModeLayoutIndex(layouts, layoutName)
    for index, layout in ipairs(layouts or {}) do
        if layout.layoutName == layoutName then
            return index
        end
    end
end

function addonTable.Injectors.EditMode()
    local layoutName = "OakUI"

    if InCombatLockdown and InCombatLockdown() then
        print("|cffff0000[OakUI Error]|r Leave combat before importing the Blizzard Edit Mode layout.")
        return false
    end

    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.ConvertStringToLayoutInfo) then
        print("|cffff0000[OakUI Error]|r Blizzard Edit Mode import APIs are unavailable.")
        return false
    end

    local ok, editModeLayouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(editModeLayouts) ~= "table" or type(editModeLayouts.layouts) ~= "table" then
        print("|cffff0000[OakUI Error]|r Could not read Blizzard Edit Mode layouts.")
        return false
    end

    for index = #editModeLayouts.layouts, 1, -1 do
        if editModeLayouts.layouts[index].layoutName == layoutName then
            table.remove(editModeLayouts.layouts, index)
        end
    end

    local editModeString = GetOakEditModeString()
    if addonTable.ApplyOakEditModeLayoutAdjustmentsString then
        editModeString = addonTable.ApplyOakEditModeLayoutAdjustmentsString(editModeString)
    end

    local importOk, importLayoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, editModeString)
    if not importOk or type(importLayoutInfo) ~= "table" then
        print("|cffff0000[OakUI Error]|r Could not convert the OakUI Edit Mode layout string.")
        return false
    end

    importLayoutInfo.layoutName = layoutName
    importLayoutInfo.layoutType = Enum.EditModeLayoutType.Account
    table.insert(editModeLayouts.layouts, importLayoutInfo)

    local saveOk, saveErr = pcall(C_EditMode.SaveLayouts, editModeLayouts)
    if not saveOk then
        print("|cffff0000[OakUI Error]|r Could not save the OakUI Edit Mode layout: " .. tostring(saveErr))
        return false
    end

    ok, editModeLayouts = pcall(C_EditMode.GetLayouts)
    local customIndex
    if ok and type(editModeLayouts) == "table" and type(editModeLayouts.layouts) == "table" then
        customIndex = FindEditModeLayoutIndex(editModeLayouts.layouts, layoutName)
    end
    if customIndex then
        local activeIndex = GetEditModePresetCount() + customIndex
        if C_EditMode.OnLayoutAdded then
            pcall(C_EditMode.OnLayoutAdded, activeIndex)
        end
        if C_EditMode.SetActiveLayout then
            pcall(C_EditMode.SetActiveLayout, activeIndex)
        end
    end

    if EditModeManagerFrame then
        pcall(EditModeManagerFrame.Show, EditModeManagerFrame)
        pcall(EditModeManagerFrame.Hide, EditModeManagerFrame)
    end

    print("|cff17ee15[OakUI]|r Blizzard Edit Mode layout imported as OakUI.")
    return true
end

-- EXECUTION ENGINE
function addonTable.Injectors.ExecuteInstallAll(addonList, profileName, role, callback)
    local anyReload = false
    local installedCount = 0
    for i, addon in ipairs(addonList) do
        local isReady = true
        if addon.folder then
            local name, _, _, _, reason = C_AddOns.GetAddOnInfo(addon.folder)
            if not name or reason == "MISSING" or reason == "DISABLED" or C_AddOns.GetAddOnEnableState(addon.folder, UnitName("player")) == 0 then
                isReady = false
            end
        end

        if isReady and addon.includeInAll then
            -- Pass the role dynamically to the injector function
            addon.func(profileName, role)
            if addon.rowBtn then
                addon.rowBtn:SetText(addon.installedText or "Installed")
                addon.rowBtn:Disable()
            end
            if addon.rowBtn2 then
                addon.rowBtn2:SetText("Installed")
                addon.rowBtn2:Disable()
            end
            if addon.requiresReload then anyReload = true end
            installedCount = installedCount + 1
        end
    end
    if installedCount > 0 then
        if callback then callback(anyReload) end
    end
end
