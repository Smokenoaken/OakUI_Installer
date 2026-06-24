local addonName, addonTable = ...

local syncingProfiles = false
local ellesmereHooked = false
local blizziHooked = false
local syncFrame

local function GetOakRoleProfileName(role)
    if addonTable.GetOakEllesmereRoleProfileName then
        return addonTable.GetOakEllesmereRoleProfileName(role)
    end
    return role == "heals" and "OakUI Healer" or "OakUI Tank/DPS"
end

local function GetOakProfileRole(profileName)
    if profileName == GetOakRoleProfileName("heals") then return "heals" end
    if profileName == GetOakRoleProfileName("dps") then return "dps" end
    return nil
end

local function IsAddonLoaded(folder)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(folder)
    end
    return IsAddOnLoaded and IsAddOnLoaded(folder)
end

local function GetEllesmereActiveProfile()
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.GetActiveProfileName) == "function" then
        local ok, profileName = pcall(EUI.GetActiveProfileName)
        if ok then return profileName end
    end
    return type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.activeProfile or nil
end

local function EllesmereProfileExists(profileName)
    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    return type(profiles) == "table" and type(profiles[profileName]) == "table"
end

local function GetBlizziProfiles()
    local BIT = _G.BIT
    return BIT and BIT.Profiles or nil
end

local function GetBlizziActiveProfile()
    local profiles = GetBlizziProfiles()
    if profiles and type(profiles.GetActiveName) == "function" then
        local ok, profileName = pcall(profiles.GetActiveName, profiles)
        if ok then return profileName end
    end
    return type(_G.BliZziInterruptsSavedVars) == "table" and _G.BliZziInterruptsSavedVars.activeProfile or nil
end

local function BlizziProfileExists(profileName)
    local profiles = GetBlizziProfiles()
    if profiles and type(profiles.Exists) == "function" then
        local ok, exists = pcall(profiles.Exists, profiles, profileName)
        return ok and exists == true
    end

    local svProfiles = type(_G.BliZziInterruptsSavedVars) == "table" and _G.BliZziInterruptsSavedVars.profiles
    return type(svProfiles) == "table" and type(svProfiles[profileName]) == "table"
end

local function CallWithSyncGuard(func, ...)
    syncingProfiles = true
    local ok = pcall(func, ...)
    syncingProfiles = false
    return ok
end

local function RefreshBlizziProfileVisuals()
    local BIT = _G.BIT
    if not BIT then return end

    if BIT.Profiles and type(BIT.Profiles.NotifyAllChanged) == "function" then
        pcall(BIT.Profiles.NotifyAllChanged, BIT.Profiles)
    end
    if BIT.UI then
        if type(BIT.UI.RebuildBars) == "function" then pcall(BIT.UI.RebuildBars, BIT.UI) end
        if type(BIT.UI.CheckZoneVisibility) == "function" then pcall(BIT.UI.CheckZoneVisibility, BIT.UI, true) end
        if BIT.UI.AttachedInterrupts and type(BIT.UI.AttachedInterrupts.Rebuild) == "function" then
            pcall(BIT.UI.AttachedInterrupts.Rebuild, BIT.UI.AttachedInterrupts)
        end
        if type(BIT.UI.ApplyFramePosition) == "function" then pcall(BIT.UI.ApplyFramePosition) end
    end
    if BIT.PartyCooldowns then
        if type(BIT.PartyCooldowns.ApplyVisibility) == "function" then pcall(BIT.PartyCooldowns.ApplyVisibility, BIT.PartyCooldowns) end
        if type(BIT.PartyCooldowns.RebuildAnchors) == "function" then pcall(BIT.PartyCooldowns.RebuildAnchors, BIT.PartyCooldowns) end
        if type(BIT.PartyCooldowns.RefreshFilter) == "function" then pcall(BIT.PartyCooldowns.RefreshFilter, BIT.PartyCooldowns) end
        if type(BIT.PartyCooldowns.RefreshCdTextStyle) == "function" then pcall(BIT.PartyCooldowns.RefreshCdTextStyle, BIT.PartyCooldowns) end
        if type(BIT.PartyCooldowns.RefreshCdGrayout) == "function" then pcall(BIT.PartyCooldowns.RefreshCdGrayout, BIT.PartyCooldowns) end
        if type(BIT.PartyCooldowns.RefreshChargeBadgeStyle) == "function" then pcall(BIT.PartyCooldowns.RefreshChargeBadgeStyle, BIT.PartyCooldowns) end
    end
    if BIT.SyncCD then
        if type(BIT.SyncCD.Rebuild) == "function" then pcall(BIT.SyncCD.Rebuild, BIT.SyncCD) end
        if type(BIT.SyncCD.ApplyBarsFrameSettings) == "function" then pcall(BIT.SyncCD.ApplyBarsFrameSettings, BIT.SyncCD) end
    end
    if BIT.OffensiveCDAlert and type(BIT.OffensiveCDAlert.Refresh) == "function" then
        pcall(BIT.OffensiveCDAlert.Refresh, BIT.OffensiveCDAlert)
    end
    if BIT.KeystoneList then
        if type(BIT.KeystoneList.OnSettingsChanged) == "function" then pcall(BIT.KeystoneList.OnSettingsChanged, BIT.KeystoneList) end
        if type(BIT.KeystoneList.RebuildDisplays) == "function" then pcall(BIT.KeystoneList.RebuildDisplays, BIT.KeystoneList) end
        if type(BIT.KeystoneList.SetEnabled) == "function" and BIT.db then
            pcall(BIT.KeystoneList.SetEnabled, BIT.KeystoneList, BIT.db.keystoneListEnabled and true or false)
        end
    end
    if BIT.SettingsUI and type(BIT.SettingsUI.RefreshActivePage) == "function" then
        pcall(BIT.SettingsUI.RefreshActivePage, BIT.SettingsUI)
    end
    if addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled then
        pcall(addonTable.ApplyOakRoundThinBlizziInterruptsIfEnabled)
    end
end

local function QueueBlizziProfileRefresh()
    RefreshBlizziProfileVisuals()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshBlizziProfileVisuals)
        C_Timer.After(0.25, RefreshBlizziProfileVisuals)
    end
end

local function SyncBlizziToProfile(profileName)
    if syncingProfiles or not profileName then return end
    if GetBlizziActiveProfile() == profileName then return end
    if not BlizziProfileExists(profileName) then return end

    local profiles = GetBlizziProfiles()
    if not profiles or type(profiles.Switch) ~= "function" then return end

    if CallWithSyncGuard(profiles.Switch, profiles, profileName) then
        QueueBlizziProfileRefresh()
    end
end

local function SyncEllesmereToProfile(profileName)
    if syncingProfiles or not profileName then return end
    if GetEllesmereActiveProfile() == profileName then return end
    if not EllesmereProfileExists(profileName) then return end

    local EUI = _G.EllesmereUI
    if not EUI or type(EUI.SwitchProfile) ~= "function" then return end

    CallWithSyncGuard(EUI.SwitchProfile, profileName)
end

local function SyncFromEllesmere(profileName)
    if syncingProfiles then return end
    if GetEllesmereActiveProfile() ~= profileName then return end

    local role = GetOakProfileRole(profileName)
    if not role then return end

    SyncBlizziToProfile(GetOakRoleProfileName(role))
end

local function SyncFromBlizzi(profileName)
    if syncingProfiles then return end
    if GetBlizziActiveProfile() ~= profileName then return end

    local role = GetOakProfileRole(profileName)
    if not role then return end

    QueueBlizziProfileRefresh()
    SyncEllesmereToProfile(GetOakRoleProfileName(role))
end

local function TryHookEllesmere()
    if ellesmereHooked or not hooksecurefunc or not IsAddonLoaded("EllesmereUI") then return end

    local EUI = _G.EllesmereUI
    if not EUI or type(EUI.SwitchProfile) ~= "function" then return end

    local ok = pcall(hooksecurefunc, EUI, "SwitchProfile", function(profileName)
        SyncFromEllesmere(profileName)
    end)
    ellesmereHooked = ok == true
end

local function TryHookBlizzi()
    if blizziHooked or not hooksecurefunc or not IsAddonLoaded("BliZzi_Interrupts") then return end

    local profiles = GetBlizziProfiles()
    if not profiles or type(profiles.Switch) ~= "function" then return end

    local ok = pcall(hooksecurefunc, profiles, "Switch", function(_, profileName)
        SyncFromBlizzi(profileName)
    end)
    blizziHooked = ok == true
end

local function TryInstallProfileSyncHooks()
    TryHookEllesmere()
    TryHookBlizzi()

    if ellesmereHooked and blizziHooked and syncFrame then
        syncFrame:UnregisterEvent("ADDON_LOADED")
        syncFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end

syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("ADDON_LOADED")
syncFrame:RegisterEvent("PLAYER_LOGIN")
syncFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED"
        and loadedAddon ~= addonName
        and loadedAddon ~= "EllesmereUI"
        and loadedAddon ~= "BliZzi_Interrupts"
    then
        return
    end

    TryInstallProfileSyncHooks()

    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, TryInstallProfileSyncHooks)
            C_Timer.After(1, TryInstallProfileSyncHooks)
            C_Timer.After(3, function()
                TryInstallProfileSyncHooks()
                if syncFrame and not (ellesmereHooked and blizziHooked) then
                    syncFrame:UnregisterEvent("ADDON_LOADED")
                end
            end)
        end
    end
end)

addonTable.SyncOakRoleProfiles = function(profileName)
    local role = GetOakProfileRole(profileName)
    if not role then return end
    profileName = GetOakRoleProfileName(role)
    SyncBlizziToProfile(profileName)
    SyncEllesmereToProfile(profileName)
end
