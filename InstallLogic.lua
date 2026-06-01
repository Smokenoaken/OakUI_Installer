local addonName, addonTable = ...
local P = addonTable.Profiles

addonTable.Injectors = {}

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
        _G.Platynator.API.ImportString(P.PLATYNATOR_PROFILE, profileName)
        addonTable.DisableEllesmereNameplatesForPlatynator(false)
    end
end

function addonTable.Injectors.XIV(profileName, role)
    local AceAddon = _G.LibStub("AceAddon-3.0", true)
    if not AceAddon then return end
    local XIVBar = AceAddon:GetAddon("XIV_Databar_Continued", true)
    if XIVBar and type(XIVBar.ImportProfile) == "function" then XIVBar:ImportProfile(P.XIV_PROFILE) end
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

local function TrimProfileString(profileString)
    return string.gsub(profileString or "", "^%s+", ""):gsub("%s+$", "")
end

local function GetRoleString(defaultString, healerString, role)
    if role == "heals" then
        return healerString or defaultString
    end
    return defaultString
end

local function IsAddonInstalled(folder)
    if not C_AddOns or not C_AddOns.GetAddOnInfo then return false end
    local name, _, _, _, reason = C_AddOns.GetAddOnInfo(folder)
    return name ~= nil and reason ~= "MISSING"
end

local function IsAddonEnabledOrLoaded(folder)
    if not IsAddonInstalled(folder) then return false end
    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(folder) then return true end
    if C_AddOns.GetAddOnEnableState then
        return (C_AddOns.GetAddOnEnableState(folder, UnitName("player")) or 0) > 0
    end
    return true
end

function addonTable.DisableEllesmereNameplatesForPlatynator(quiet)
    if not IsAddonEnabledOrLoaded("Platynator") or not IsAddonEnabledOrLoaded("EllesmereUINameplates") then
        return false
    end

    local disabled = false
    if C_AddOns.DisableAddOn then
        local ok = pcall(C_AddOns.DisableAddOn, "EllesmereUINameplates", UnitName("player"))
        if not ok then
            ok = pcall(C_AddOns.DisableAddOn, "EllesmereUINameplates")
        end
        disabled = ok
    end

    if disabled and not quiet and not addonTable._platynatorNameplateNoticeShown then
        addonTable._platynatorNameplateNoticeShown = true
        print("|cff17ee15[OakUI]|r Platynator detected; EllesmereUI Nameplates will be disabled after reload.")
    end

    return disabled
end

local function RefreshEllesmereAfterProfileImport()
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshAllAddons) == "function" then
        pcall(_G.EllesmereUI.RefreshAllAddons, _G.EllesmereUI)
    end
end

local function DeepCopyTable(src, seen)
    if type(src) ~= "table" then return src end
    if seen and seen[src] then return seen[src] end
    seen = seen or {}
    local copy = {}
    seen[src] = copy
    for k, v in pairs(src) do
        copy[DeepCopyTable(k, seen)] = DeepCopyTable(v, seen)
    end
    return copy
end

local function DeepMergeTable(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMergeTable(dst[k], v)
        else
            dst[k] = DeepCopyTable(v)
        end
    end
end

local function ApplyEllesmereProfileSupplement(profileName)
    local supplement = P.ELLESMERE_PROFILE_SUPPLEMENT
    if type(supplement) ~= "table" or type(_G.EllesmereUIDB) ~= "table" then return end

    local db = _G.EllesmereUIDB
    profileName = profileName or db.activeProfile or "OakUI"
    db.profiles = db.profiles or {}
    db.profiles[profileName] = db.profiles[profileName] or {}
    local profile = db.profiles[profileName]
    profile.addons = profile.addons or {}

    if type(supplement.addons) == "table" then
        for addonKey, addonProfile in pairs(supplement.addons) do
            profile.addons[addonKey] = profile.addons[addonKey] or {}
            DeepMergeTable(profile.addons[addonKey], addonProfile)
        end
    end

    local specProfiles = supplement.spellAssignments and supplement.spellAssignments.specProfiles
    if type(specProfiles) == "table" then
        db.spellAssignments = db.spellAssignments or {}
        db.spellAssignments.specProfiles = db.spellAssignments.specProfiles or {}
        for specID, specData in pairs(specProfiles) do
            db.spellAssignments.specProfiles[specID] = db.spellAssignments.specProfiles[specID] or {}
            DeepMergeTable(db.spellAssignments.specProfiles[specID], specData)
        end
    end
end

local platynatorConflictFrame = CreateFrame("Frame")
platynatorConflictFrame:RegisterEvent("PLAYER_LOGIN")
platynatorConflictFrame:RegisterEvent("ADDON_LOADED")
platynatorConflictFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Platynator" and addon ~= "EllesmereUINameplates" then
        return
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1, function()
            addonTable.DisableEllesmereNameplatesForPlatynator(true)
        end)
    else
        addonTable.DisableEllesmereNameplatesForPlatynator(true)
    end
end)

function addonTable.Injectors.Ellesmere(profileName, role)
    if not C_AddOns.IsAddOnLoaded("EllesmereUI") then return end

    ApplyBaseActionBarCVars()
    if addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end

    local encoded = TrimProfileString(P.ELLESMERE_PROFILE)
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
        local supplementOk, supplementErr = pcall(ApplyEllesmereProfileSupplement, profileName)
        if not supplementOk then
            print("|cffff0000[OakUI Error]|r Ellesmere supplement failed: " .. tostring(supplementErr))
        end
        pcall(addonTable.DisableEllesmereNameplatesForPlatynator, false)
        RefreshEllesmereAfterProfileImport()
    end
end

function addonTable.Injectors.BaseUI(profileName, role)
    return addonTable.Injectors.Ellesmere(profileName, role)
end

function addonTable.Injectors.Danders(profileName, role)
    if not C_AddOns.IsAddOnLoaded("DandersFrames") then return end

    local encoded = TrimProfileString(GetRoleString(P.DANDERS_PROFILE, P.DANDERS_PROFILE_HEALS, role))
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r Danders Frames profile string is missing or empty for this role.")
        return
    end

    if type(_G.DandersFrames_Import) == "function" then
        local ok, success, result = pcall(_G.DandersFrames_Import, encoded, profileName)
        if not ok then
            print("|cffff0000[OakUI Error]|r Danders Frames import failed: " .. tostring(success))
        elseif not success then
            print("|cffff0000[OakUI Error]|r Danders Frames import failed: " .. tostring(result))
        end
        return
    end

    print("|cffff0000[OakUI Error]|r Danders Frames import API is unavailable.")
end

function addonTable.Injectors.AyijeCDM(profileName, role)
    if not C_AddOns.IsAddOnLoaded("Ayije_CDM") then return end
    local encoded = string.gsub(P.AYIJE_CDM_PROFILE or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then
        print("|cffff0000[OakUI Error]|r Ayije CDM profile string is missing or empty.")
        return
    end

    local api = _G.Ayije_CDM_API or (_G.Ayije_CDM and _G.Ayije_CDM.API)
    if api and type(api.ImportProfile) == "function" then
        local ok, err = pcall(api.ImportProfile, api, encoded, profileName)
        if ok then return end
        print("|cffff0000[OakUI Error]|r Ayije CDM import failed: " .. tostring(err))
    elseif _G.Ayije_CDM and type(_G.Ayije_CDM.ImportProfileData) == "function" then
        print("|cffff0000[OakUI Error]|r Ayije CDM direct profile data import requires decoded profile data.")
    else
        print("|cffff0000[OakUI Error]|r Ayije CDM import API is unavailable.")
    end
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

    if addonTable.ApplyBlizzardTimelineFont then
        addonTable.ApplyBlizzardTimelineFont()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, addonTable.ApplyBlizzardTimelineFont)
            C_Timer.After(1.5, addonTable.ApplyBlizzardTimelineFont)
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
    local encoded = TrimProfileString(P.BLIZZI_PARTY_TOOLS_PROFILE)
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
        return
    end

    if BIT and type(BIT.ImportProfile) == "function" then
        local ok, success, result = pcall(BIT.ImportProfile, encoded)
        if not ok then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(success))
        elseif not success then
            print("|cffff0000[OakUI Error]|r Blizzi Party Tools import failed: " .. tostring(result))
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

    local importOk, importLayoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, GetOakEditModeString())
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

        if isReady and (not addon.manual or addon.includeInAll) then
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
