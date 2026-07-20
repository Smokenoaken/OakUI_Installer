local addonName, addonTable = ...
local P = addonTable.Profiles

local ROLE_PROFILE_NAMES = {
    dps = "OakUI Tank/DPS",
    heals = "OakUI Healer",
}

local MODULES = {
    { folder = "EllesmereUIActionBars", label = "Action Bars", description = "Action bar styling, fade rules, and per-bar behavior." },
    { folder = "EllesmereUINameplates", label = "Nameplates", description = "Nameplate styling, behavior, cast bars, and rounded border profile data." },
    { folder = "EllesmereUIUnitFrames", label = "Unit Frames", description = "Player, target, focus, pet, and boss frame settings." },
    { folder = "EllesmereUICooldownManager", label = "Cooldown Manager", description = "Cooldown bars, icon styling, glows, and per-spec spell layout." },
    { folder = "EllesmereUIResourceBars", label = "Resource Bars", description = "Cast bars, power bars, class resources, and totems." },
    { folder = "EllesmereUIRaidFrames", label = "Raid Frames", description = "Party, raid, and raid buff settings." },
    { folder = "EllesmereUIAuraBuffReminders", label = "AuraBuff Reminders", description = "Aura reminder and utility widget settings." },
    { folder = "EllesmereUIQoL", label = "Quality of Life", description = "Automation helpers, popup blocker, consumables, and utility toggles." },
    { folder = "EllesmereUIDragonRiding", label = "Dragon Riding", description = "Dragonriding UI settings hosted by Ellesmere's Blizzard skin module." },
    { folder = "EllesmereUIBags", label = "Bags", description = "Bag module styling and bag behavior." },
    { folder = "EllesmereUIFriends", label = "Friends List", description = "Friends panel and related datatext settings." },
    { folder = "EllesmereUIMythicTimer", label = "Mythic+ Timer", description = "Mythic+ timer styling and behavior." },
    { folder = "EllesmereUIQuestTracker", label = "Quest Tracker", description = "Quest tracker styling and behavior." },
    { folder = "EllesmereUIMinimap", label = "Minimap", description = "Minimap frame and minimap utility settings." },
    { folder = "EllesmereUIDamageMeters", label = "Damage Meters", description = "Damage meter panel styling and layout." },
    { folder = "EllesmereUIChat", label = "Chat", description = "Chat frame skinning, formatting, and utility options." },
    { folder = "EllesmereUIDataBars", label = "DataBars", description = "DataBars module styling and behavior. Character gold data is never imported by OakUI." },
}

local CATEGORY_TREE = {
    {
        id = "section:profile",
        label = "Profile Sections",
        description = "Shared profile-level data that is not owned by a single Ellesmere addon.",
        header = true,
        children = {
            { id = "theme", label = "Theme / Fonts / Colors", description = "Shared fonts, textures, accent colors, and class color behavior.", recommended = false },
            { id = "layout", label = "Layout", description = "EUI unlock anchors and size-match relationships for selected addons.", recommended = false },
        },
    },
    {
        id = "section:addons",
        label = "Per-Addon Import",
        description = "Import only the Ellesmere addon modules you want, matching EUI's per-addon import model.",
        header = true,
        children = {},
    },
}

for _, module in ipairs(MODULES) do
    table.insert(CATEGORY_TREE[2].children, {
        id = "module:" .. module.folder,
        label = module.label,
        description = module.description,
        recommended = true,
    })
end

addonTable.EllesmereSelectiveModules = MODULES
addonTable.EllesmereSelectiveSections = {
    { key = "theme", display = "Theme / Fonts / Colors", desc = "Shared fonts, textures, accent colors, and class color behavior." },
    { key = "layout", display = "Layout", desc = "EUI unlock anchors and size-match relationships for selected addons." },
}
addonTable.EllesmereSelectiveTree = CATEGORY_TREE

local function DeepCopy(src, seen)
    if type(src) ~= "table" then return src end
    if seen and seen[src] then return seen[src] end
    seen = seen or {}
    local copy = {}
    seen[src] = copy
    for key, value in pairs(src) do
        if type(value) ~= "function" and type(value) ~= "userdata" then
            copy[DeepCopy(key, seen)] = DeepCopy(value, seen)
        end
    end
    return copy
end

local function TrimProfileString(profileString)
    return tostring(profileString or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetEncodedProfile(role)
    if role == "heals" then
        local healer = TrimProfileString(P.ELLESMERE_PROFILE_HEALS)
        if healer ~= "" then return healer end
    end
    return TrimProfileString(P.ELLESMERE_PROFILE)
end

local function SelectionIncludes(selection, key)
    return selection == nil or selection.all or selection[key] == true
end

local function GetSelectedFolders(selection)
    local folders = {}
    local count = 0
    for _, module in ipairs(MODULES) do
        if SelectionIncludes(selection, "module:" .. module.folder) then
            folders[module.folder] = true
            count = count + 1
        end
    end
    return folders, count
end

local function GetProfilesDB()
    return type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB
end

function addonTable.GetOakEllesmereRoleProfileName(role)
    role = role == "heals" and "heals" or "dps"
    return ROLE_PROFILE_NAMES[role]
end

function addonTable.GetOakEllesmereCustomCdmChildren()
    return {}
end

local function DecodeOakEllesmerePayload(role)
    if not _G.EllesmereUI or type(_G.EllesmereUI.DecodeImportString) ~= "function" then
        return nil, "EllesmereUI import APIs are unavailable."
    end

    local encoded = GetEncodedProfile(role)
    if encoded == "" then
        return nil, "OakUI's Ellesmere profile string is missing."
    end

    local payload, err = _G.EllesmereUI.DecodeImportString(encoded)
    if not payload then
        return nil, err or "Could not decode OakUI's Ellesmere profile string."
    end
    return payload
end

local function BuildFilteredPayload(role, selection)
    local source, err = DecodeOakEllesmerePayload(role)
    if not source then return nil, err end

    if selection == nil or selection.all then
        return source
    end

    local payload = (_G.EllesmereUI and _G.EllesmereUI._DeepCopy and _G.EllesmereUI._DeepCopy(source)) or DeepCopy(source)
    local data = payload and payload.data
    if type(data) ~= "table" then return nil, "OakUI's Ellesmere profile payload is invalid." end

    local selectedFolders, folderCount = GetSelectedFolders(selection)
    local keepTheme = SelectionIncludes(selection, "theme")
    local keepLayout = SelectionIncludes(selection, "layout")

    if folderCount == 0 and not keepTheme and not keepLayout then
        return nil, "Select at least one Ellesmere addon or shared profile section."
    end

    local isPartialImport = false
    if type(data.addons) == "table" then
        for folder in pairs(data.addons) do
            if not selectedFolders[folder] then
                data.addons[folder] = nil
                isPartialImport = true
            end
        end
    end

    if not selectedFolders.EllesmereUICooldownManager then
        data.cdmSpells = nil
    end

    data.assignedSpecs = nil
    data.applyUIScale = nil

    if keepLayout and data.unlockLayout then
        if folderCount > 0
            and _G.EllesmereUI
            and type(_G.EllesmereUI.BuildImportKeyToFolder) == "function"
            and type(_G.EllesmereUI.FilterLayoutToFolders) == "function"
        then
            local meta = data.unlockLayoutMeta
            local keyToFolder = _G.EllesmereUI.BuildImportKeyToFolder(data.unlockLayout, meta and meta.keyToFolder)
            data.unlockLayout = _G.EllesmereUI.FilterLayoutToFolders(data.unlockLayout, selectedFolders, keyToFolder)
        end
    else
        data.unlockLayout = nil
    end
    data.unlockLayoutMeta = nil

    if isPartialImport and not keepTheme then
        data.fonts = nil
        data.customColors = nil
        data.euiAccent = nil
    end

    if isPartialImport then
        data.partialImport = true
    end

    if not keepLayout then
        data.specUnlockOverrides = nil
        data.condUnlockOverrides = nil
        data.layoutExcluded = true
    end

    return payload
end

function addonTable.ApplyOakEllesmereProfileImport(profileName, role, selection, quiet)
    if not C_AddOns.IsAddOnLoaded("EllesmereUI") then
        if not quiet then print("|cffff0000[OakUI]|r EllesmereUI must be loaded before importing an OakUI Ellesmere profile.") end
        return false
    end
    if not _G.EllesmereUI or type(_G.EllesmereUI.ImportProfile) ~= "function" then
        if not quiet then print("|cffff0000[OakUI]|r EllesmereUI import APIs are unavailable.") end
        return false
    end

    role = role == "heals" and "heals" or "dps"
    profileName = profileName and profileName ~= "" and profileName or addonTable.GetOakEllesmereRoleProfileName(role)

    local payload, err = BuildFilteredPayload(role, selection)
    if not payload then
        if not quiet then print("|cffff0000[OakUI]|r " .. tostring(err)) end
        return false
    end

    local ok, success, importErr = pcall(_G.EllesmereUI.ImportProfile, payload, profileName)
    if not ok then
        if not quiet then print("|cffff0000[OakUI]|r Ellesmere import failed: " .. tostring(success)) end
        return false
    end
    if not success then
        if not quiet then print("|cffff0000[OakUI]|r Ellesmere import failed: " .. tostring(importErr)) end
        return false
    end

    local db = GetProfilesDB()
    if db and addonTable.ApplyOakEllesmereUIScale then
        addonTable.ApplyOakEllesmereUIScale(db)
    end
    if db and addonTable.ApplyOakEllesmereLayoutAdjustments then
        addonTable.ApplyOakEllesmereLayoutAdjustments(db, profileName, role)
    end
    if addonTable.ApplyOakRoundThinBordersIfEnabled then pcall(addonTable.ApplyOakRoundThinBordersIfEnabled, profileName) end
    if addonTable.ApplyOakRoundThinDamageMetersIfEnabled then pcall(addonTable.ApplyOakRoundThinDamageMetersIfEnabled, profileName) end
    if addonTable.ApplyOakRoundThinTrackingBarsIfEnabled then pcall(addonTable.ApplyOakRoundThinTrackingBarsIfEnabled, profileName) end
    if addonTable.ApplyOakRoundThinCastBarsIfEnabled then pcall(addonTable.ApplyOakRoundThinCastBarsIfEnabled, profileName) end
    if addonTable.ApplyOakRoundThinNameplatesIfEnabled then pcall(addonTable.ApplyOakRoundThinNameplatesIfEnabled, profileName) end
    if addonTable.ApplyOakRoundThinBossFramesIfEnabled then pcall(addonTable.ApplyOakRoundThinBossFramesIfEnabled, profileName) end
    if addonTable.MarkEllesmereCDMAutoRepopulateProfile then addonTable.MarkEllesmereCDMAutoRepopulateProfile(profileName) end
    if addonTable.ScheduleEllesmereCDMRepopulate then addonTable.ScheduleEllesmereCDMRepopulate(profileName, "profile_import") end

    if not quiet then
        print("|cff17ee15[OakUI]|r Imported Ellesmere profile '" .. tostring(profileName) .. "' from OakUI's profile string.")
    end
    return true
end

function addonTable.ApplyOakEllesmereProfileImportAll(profileName, role, quiet)
    return addonTable.ApplyOakEllesmereProfileImport(profileName, role, { all = true }, quiet)
end
