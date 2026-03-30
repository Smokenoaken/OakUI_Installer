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

function addonTable.Injectors.QUI(profileName, role)
    if not C_AddOns.IsAddOnLoaded("QUI") then return end
    
    -- BRUTE FORCE ACTION BARS
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
    
    -- EXPLICIT ROLE SELECTION
    local profileString = P.QUI_PROFILE
    if role == "heals" then
        profileString = P.QUI_PROFILE_HEALS or P.QUI_PROFILE_Heals
    end
    
    local encoded = string.gsub(profileString or "", "^%s+", ""):gsub("%s+$", "")
    if encoded == "" then 
        print("|cffff0000[OakUI Error]|r QUI profile string is missing or empty for this role!")
        return 
    end
    
    local LibDeflate = _G.LibStub("LibDeflate", true)
    local AceSerializer = _G.LibStub("AceSerializer-3.0", true)
    if not LibDeflate or not AceSerializer then return end
    local cleanEncoded = encoded
    if string.find(cleanEncoded, ":") then cleanEncoded = string.match(cleanEncoded, ":(.*)$") or cleanEncoded
    elseif string.find(cleanEncoded, "_") then cleanEncoded = string.match(cleanEncoded, "_(.*)$") or cleanEncoded end
    
    local decoded = LibDeflate:DecodeForPrint(cleanEncoded) or LibDeflate:DecodeForPrint(encoded)
    if type(decoded) ~= "string" then return end 
    
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    local ok, payload = false, nil
    if decompressed then ok, payload = AceSerializer:Deserialize(decompressed) end
    if ok and type(payload) == "table" then
        if not _G.QUIDB then _G.QUIDB = { profiles = {}, profileKeys = {} } end
        _G.QUIDB.profiles = _G.QUIDB.profiles or {}
        _G.QUIDB.profiles[profileName] = payload.profile or payload
        
        -- FORCE ACE3 TO SET AND BIND THE PROFILE IMMEDIATELY
        if _G.QUI and _G.QUI.db and type(_G.QUI.db.SetProfile) == "function" then
            _G.QUI.db:SetProfile(profileName)
        else
            -- Fallback if Ace3 hasn't fully initialized
            _G.QUIDB.profileKeys = _G.QUIDB.profileKeys or {}
            _G.QUIDB.profileKeys[UnitName("player") .. " - " .. GetRealmName()] = profileName
        end
    end
end

function addonTable.Injectors.Danders(profileName, role)
    -- EXPLICIT ROLE SELECTION
    local profileString = P.DANDERS_PROFILE
    if role == "heals" then
        profileString = P.DANDERS_PROFILE_HEALS or P.DANDERS_PROFILE_Heals
    end
    
    local encodedStr = string.gsub(profileString or "", "^%s+", ""):gsub("%s+$", "")
    if not C_AddOns.IsAddOnLoaded("DandersFrames") or not encodedStr or encodedStr == "" then 
        if encodedStr == "" then print("|cffff0000[OakUI Error]|r Danders profile string is missing or empty for this role!") end
        return 
    end
    
    local DF = _G.DandersFrames

    -- Helper function to force Danders to active the profile
    local function ForceActivateDanders()
        if not DF then return end
        if type(DF.LoadProfile) == "function" then pcall(DF.LoadProfile, DF, profileName) end
        if type(DF.ApplyProfile) == "function" then pcall(DF.ApplyProfile, DF, profileName) end
    end

    if DF and type(DF.ValidateImportString) == "function" and type(DF.ApplyImportedProfile) == "function" then
        local data, err = DF:ValidateImportString(encodedStr)
        if data then 
            DF:ApplyImportedProfile(data, nil, nil, profileName, true, true)
            ForceActivateDanders()
            return 
        end
    end
    
    local LibDeflate = _G.LibStub("LibDeflate", true)
    local LibSerialize = _G.LibStub("LibSerialize", true) 
    if not LibDeflate or not LibSerialize then return end
    if string.sub(encodedStr, 1, 6) == "!DFP1!" then
        local payloadStr = string.sub(encodedStr, 7)
        local decoded = LibDeflate:DecodeForPrint(payloadStr)
        if type(decoded) ~= "string" then return end
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        local ok, data = false, nil
        if decompressed then ok, data = LibSerialize:Deserialize(decompressed) end
        if ok and type(data) == "table" and (data.party or data.raid) then
            if not _G.DandersFramesDB_v2 then _G.DandersFramesDB_v2 = { profiles = {}, currentProfile = "Default" } end
            _G.DandersFramesDB_v2.profiles[profileName] = {
                party = data.party, raid = data.raid, classColors = data.classColors or {},
                powerColors = data.powerColors or {}, raidAutoProfiles = data.raidAutoProfiles or {}
            }
            _G.DandersFramesDB_v2.currentProfile = profileName
            
            -- Force character binding
            if not _G.DandersFramesDB_v2.characterProfiles then _G.DandersFramesDB_v2.characterProfiles = {} end
            _G.DandersFramesDB_v2.characterProfiles[UnitName("player") .. "-" .. GetRealmName()] = profileName
            _G.DandersFramesDB_v2.characterProfiles[UnitName("player") .. "-" .. GetNormalizedRealmName()] = profileName
            
            ForceActivateDanders()
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