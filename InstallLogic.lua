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
        _G.Platynator.API.ImportString(P.PLATYNATOR_PROFILE, profileName, true)
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

local function GetRoleString(defaultString, healerString, role)
    if role == "heals" then
        return healerString or defaultString
    end
    return defaultString
end

function addonTable.Injectors.ElvUI(profileName, role)
    if not C_AddOns.IsAddOnLoaded("ElvUI") then return end

    ApplyBaseActionBarCVars()

    local E = GetElvUICore()
    if not E then
        print("|cffff0000[OakUI Error]|r ElvUI is loaded, but its core API is unavailable.")
        return
    end
    HideElvUIInstaller(E)
    DisablePlatynatorConflictWarning(E)

    if type(E.SetupCVars) == "function" then pcall(E.SetupCVars, E, true) end

    local distributor = type(E.GetModule) == "function" and E:GetModule("Distributor", true)
    if not distributor or type(distributor.Decode) ~= "function" or type(distributor.SetImportedProfile) ~= "function" then
        print("|cffff0000[OakUI Error]|r ElvUI's profile import API is unavailable.")
        return
    end

    local function ImportElvString(label, importString, required)
        local encoded = string.gsub(importString or "", "^%s+", ""):gsub("%s+$", "")
        if encoded == "" then
            if required then
                print("|cffff0000[OakUI Error]|r ElvUI " .. label .. " string is missing or empty for this role.")
            end
            return false
        end

        local profileType, profileKey, profileData = distributor:Decode(encoded)
        if type(profileData) ~= "table" then
            print("|cffff0000[OakUI Error]|r ElvUI " .. label .. " import failed. Check the embedded string.")
            return false
        end

        if profileType == "profile" then profileKey = profileName end
        distributor:SetImportedProfile(profileType or "profile", profileKey or profileName, profileData, true)
        return true
    end

    local importedProfile = ImportElvString("profile", GetRoleString(P.ELVUI_PROFILE, P.ELVUI_PROFILE_HEALS, role), true)
    ImportElvString("private", GetRoleString(P.ELVUI_PRIVATE, P.ELVUI_PRIVATE_HEALS, role), true)

    if not importedProfile then return end
end

function addonTable.Injectors.Ellesmere(profileName, role)
    print("|cffff0000[OakUI Error]|r Ellesmere provider is not wired yet. Add its import API and profile string before enabling this base.")
end

function addonTable.Injectors.BaseUI(profileName, role)
    local provider = P.BASE_UI_PROVIDER or "ElvUI"
    if provider == "Ellesmere" then
        return addonTable.Injectors.Ellesmere(profileName, role)
    end
    return addonTable.Injectors.ElvUI(profileName, role)
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

function addonTable.Injectors.BigWigs(profileName, role)
    if not C_AddOns.IsAddOnLoaded("BigWigs") then return end
    local encoded = string.gsub(P.BIGWIGS_PROFILE or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then return end

    -- Use the official BigWigs Import API
    if _G.BigWigsAPI and type(_G.BigWigsAPI.RegisterProfile) == "function" then
        pcall(function()
            _G.BigWigsAPI.RegisterProfile("OakUI", encoded, profileName)
        end)
    else
        print("|cffff0000[OakUI]|r Your version of BigWigs is too old. Please update BigWigs to import the profile.")
    end
end

local OAK_EDIT_MODE_STRING = "2 50 0 0 0 4 4 UIParent -0.0 -560.0 -1 ##$$%/&%'%)$+$,$ 0 1 0 6 8 MainActionBar 4.0 0.0 -1 ##$&%,&%'%(#,$ 0 2 0 8 2 MainActionBar 0.0 4.0 -1 ##$$%/&%'%(#,$ 0 3 0 8 6 MainActionBar -4.0 0.0 -1 ##$&%,&%'%(#,$ 0 4 0 7 7 UIParent 360.0 42.0 -1 #$$'%)&&'%(#,# 0 5 0 4 4 UIParent 240.0 -400.0 -1 ##$%%)&%'%(#,# 0 6 0 0 0 UIParent 548.7 -1122.3 -1 ##$$%)&#'%(&,# 0 7 0 4 4 UIParent -448.0 -560.0 -1 ##$$%)&#'%(&,# 0 10 0 6 0 MultiBarBottomRight 0.0 4.0 -1 ##$$&%'% 0 11 0 7 7 UIParent 84.2 97.8 -1 ##$$&%'%,# 0 12 0 0 0 UIParent 870.0 -1040.8 -1 ##$$&('% 1 -1 0 7 7 UIParent 0.0 134.0 -1 ##$#%$ 2 -1 0 1 1 UIParent 949.4 -1.8 -1 ##$#%) 3 0 0 1 1 UIParent -261.0 -806.0 -1 $#3# 3 1 0 1 1 UIParent 260.0 -804.0 -1 %$3# 3 2 0 0 0 UIParent 1353.8 -878.3 -1 %#&#3# 3 3 0 0 0 UIParent 516.7 -1142.0 -1 '$(#)#-k.)/#1#3&5#6(7-7$ 3 4 0 0 0 UIParent 211.0 -1092.0 -1 ,#-#.'/#0$1#2(5#6(7-7$ 3 5 0 2 2 UIParent -251.8 -98.7 -1 &$*$3, 3 6 0 2 2 UIParent -296.0 -321.2 -1 -#.#/#4&5#6(7-7$ 3 7 0 5 5 UIParent -1364.7 -312.7 -1 3# 4 -1 0 7 7 UIParent 0.0 1082.0 -1 # 5 -1 0 8 8 UIParent -384.2 30.3 -1 # 6 0 0 1 1 UIParent -497.2 -2.0 -1 ##$#%$&C(()( 6 1 0 1 7 BuffFrame -275.3 -4.0 -1 ##$#%$'3(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 0 4 4 UIParent 0.0 -379.5 -1 # 8 -1 0 6 6 UIParent 4.0 54.4 -1 #'$q%$&T 9 -1 0 7 7 UIParent 325.8 2.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 0 5 5 UIParent -296.3 99.5 -1 # 12 -1 0 0 0 UIParent 1913.3 -192.3 -1 #4$#%# 13 -1 0 6 8 MainMenuBarVehicleLeaveButton 4.0 0.0 -1 ##$#%#&( 14 -1 0 6 8 MicroMenuContainer 3.5 -0.5 -1 #$$#%# 15 0 0 1 1 UIParent 0.0 -2.0 -1 # 15 1 0 2 8 MainStatusTrackingBarContainer 0.0 -4.0 -1 # 16 -1 0 6 8 VehicleSeatIndicator 3.5 0.5 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 0 6 8 ChatFrame1 28.2 -32.8 -1 #( 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 0 1 4 UIParent 0.0 -222.0 -1 ##$7%$&(''(-($)#+$,$-$ 20 1 0 1 4 UIParent 0.0 -262.0 -1 ##$+%$&(''(=)#+$,$-$ 20 2 0 7 4 UIParent 0.0 -193.0 -1 ##$$%$&(''(-($)#+$,$-$ 20 3 0 1 4 UIParent 0.0 -322.0 -1 #$$$%#&('#(-($)#*#+$,$-$.$.$ 21 -1 0 4 4 UIParent -414.5 -150.0 -1 ##$# 22 0 0 4 4 UIParent 416.0 34.8 -1 #$$$%$&(''(-($)5*$+$,$-#.#/U0% 22 1 0 1 1 UIParent 0.0 -282.0 -1 &('()U*#+$ 22 2 0 4 4 UIParent 0.0 340.0 -1 &('()U*#+$ 22 3 0 4 4 UIParent -0.0 380.0 -1 &('()U*#+$ 23 -1 0 0 0 UIParent 1810.5 -1007.0 -1 ##$#%$&7'P($)U+$,$-$.(/"
function addonTable.Injectors.GetEditMode() return OAK_EDIT_MODE_STRING end

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

        if isReady and not addon.manual then
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
