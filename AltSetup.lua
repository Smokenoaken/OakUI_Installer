local _, addonTable = ...

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

local function GetAceCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return name .. " - " .. realm
end

local function GetInstallCharacters()
    OakUI_DB = OakUI_DB or {}
    OakUI_DB.install = OakUI_DB.install or {}
    OakUI_DB.install.characters = OakUI_DB.install.characters or {}
    return OakUI_DB.install.characters
end

local function IsAddonLoaded(folder)
    if addonTable.IsForever and (folder == "DBM-Core" or folder == "BigWigs"
        or folder == "BliZzi_Interrupts" or folder == "wMarker") then return false end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(folder)
    end
    return IsAddOnLoaded and IsAddOnLoaded(folder)
end

local function ProfileExists(profiles, profileName)
    return profileName ~= "" and type(profiles) == "table" and type(profiles[profileName]) == "table"
end

local function GetEllesmereProfile()
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.GetActiveProfileName) == "function" then
        local ok, profileName = pcall(EUI.GetActiveProfileName)
        if ok then return TrimText(profileName) end
    end
    return type(_G.EllesmereUIDB) == "table" and TrimText(_G.EllesmereUIDB.activeProfile) or ""
end

local function GetBigWigsProfile()
    if _G.BigWigsAPI and type(_G.BigWigsAPI.GetProfileName) == "function" then
        local ok, profileName = pcall(_G.BigWigsAPI.GetProfileName)
        if ok then return TrimText(profileName) end
    end
    local profileKeys = type(_G.BigWigs3DB) == "table" and _G.BigWigs3DB.profileKeys
    return type(profileKeys) == "table" and TrimText(profileKeys[GetAceCharacterKey()]) or ""
end

local function GetBlizziProfile()
    local profiles = _G.BIT and _G.BIT.Profiles
    if profiles and type(profiles.GetActiveName) == "function" then
        local ok, profileName = pcall(profiles.GetActiveName, profiles)
        if ok then return TrimText(profileName) end
    end
    return type(_G.BliZziInterruptsSavedVars) == "table" and TrimText(_G.BliZziInterruptsSavedVars.activeProfile) or ""
end

local function GetWMarkerProfile()
    local db = _G.wMarkerAce and _G.wMarkerAce.db
    if db and type(db.GetCurrentProfile) == "function" then
        local ok, profileName = pcall(db.GetCurrentProfile, db)
        if ok then return TrimText(profileName) end
    end
    local profileKeys = type(_G.wMarkerAceDB) == "table" and _G.wMarkerAceDB.profileKeys
    return type(profileKeys) == "table" and TrimText(profileKeys[GetAceCharacterKey()]) or ""
end

local function CopySnapshot(snapshot)
    if type(snapshot) ~= "table" then return nil end
    return {
        ellesmere = TrimText(snapshot.ellesmere),
        editMode = TrimText(snapshot.editMode),
        bigWigs = TrimText(snapshot.bigWigs),
        dbm = TrimText(snapshot.dbm),
        blizzi = TrimText(snapshot.blizzi),
        wmarker = TrimText(snapshot.wmarker),
        capturedAt = tonumber(snapshot.capturedAt) or 0,
    }
end

local GetSnapshotSummary

local function IsOakProfileName(profileName)
    local lower = TrimText(profileName):lower()
    if lower == "oakui" then return true end
    if lower:sub(1, 5) ~= "oakui" then return false end
    local separator = lower:sub(6, 6)
    return separator == " " or separator == "-" or separator == "_" or separator == "/"
end

local function AddProfileName(names, seen, profileName)
    profileName = TrimText(profileName)
    local key = profileName:lower()
    if profileName == "" or not IsOakProfileName(profileName) or seen[key] then return end
    seen[key] = true
    names[#names + 1] = profileName
end

local function AddProfileMapKeys(names, seen, profiles)
    if type(profiles) ~= "table" then return end
    for profileName, profileData in pairs(profiles) do
        if type(profileName) == "string" and type(profileData) == "table" then
            AddProfileName(names, seen, profileName)
        end
    end
end

local function AddProfileMapValues(names, seen, profileKeys)
    if type(profileKeys) ~= "table" then return end
    for _, profileName in pairs(profileKeys) do
        if type(profileName) == "string" then AddProfileName(names, seen, profileName) end
    end
end

local function SortProfileNames(names)
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function GetEllesmereProfileNames()
    local names, seen = {}, {}
    AddProfileMapKeys(names, seen, type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles)
    return SortProfileNames(names)
end

local function GetBigWigsProfileNames()
    local names, seen = {}, {}
    if _G.BigWigsAPI and type(_G.BigWigsAPI.GetProfileList) == "function" then
        local ok, profiles = pcall(_G.BigWigsAPI.GetProfileList)
        if ok and type(profiles) == "table" then
            for _, profileName in pairs(profiles) do AddProfileName(names, seen, profileName) end
        end
    end
    local saved = type(_G.BigWigs3DB) == "table" and _G.BigWigs3DB
    AddProfileMapKeys(names, seen, saved and saved.profiles)
    AddProfileMapValues(names, seen, saved and saved.profileKeys)
    return SortProfileNames(names)
end

local function GetDBMProfileNames()
    local names, seen = {}, {}
    if type(_G.DBM_AllSavedOptions) == "table" and type(_G.DBT_AllPersistentOptions) == "table" then
        for profileName, profileData in pairs(_G.DBM_AllSavedOptions) do
            if type(profileName) == "string" and type(profileData) == "table"
                and type(_G.DBT_AllPersistentOptions[profileName]) == "table" then
                AddProfileName(names, seen, profileName)
            end
        end
    end
    return SortProfileNames(names)
end

local function GetBlizziProfileNames()
    local names, seen = {}, {}
    local saved = type(_G.BliZziInterruptsSavedVars) == "table" and _G.BliZziInterruptsSavedVars
    AddProfileMapKeys(names, seen, saved and saved.profiles)
    return SortProfileNames(names)
end

local function GetWMarkerProfileNames()
    local names, seen = {}, {}
    local db = _G.wMarkerAce and _G.wMarkerAce.db
    if db and type(db.GetProfiles) == "function" then
        local profiles = {}
        local ok = pcall(db.GetProfiles, db, profiles)
        if ok then
            for _, profileName in pairs(profiles) do AddProfileName(names, seen, profileName) end
        end
    end
    local saved = type(_G.wMarkerAceDB) == "table" and _G.wMarkerAceDB
    AddProfileMapKeys(names, seen, db and db.profiles or saved and saved.profiles)
    AddProfileMapValues(names, seen, saved and saved.profileKeys)
    return SortProfileNames(names)
end

local function GetEditModeLayoutNames()
    local names, seen = {}, {}
    local layouts = addonTable.GetEditModeLayoutNames and addonTable.GetEditModeLayoutNames() or {}
    for _, layoutName in pairs(layouts) do
        if addonTable.IsForever then
            names[#names + 1] = layoutName
        else
            AddProfileName(names, seen, layoutName)
        end
    end
    return SortProfileNames(names)
end

local function GetRoleHint(profileName)
    local lower = TrimText(profileName):lower()
    if lower:find("heal", 1, true) then return "heals" end
    if lower:find("tank", 1, true) or lower:find("dps", 1, true) then return "dps" end
end

local function CompactProfileName(profileName)
    return TrimText(profileName):lower():gsub("[^%a%d]", "")
end

local function GetProfileTokens(profileName)
    local tokens = {}
    for token in TrimText(profileName):lower():gmatch("[%a%d]+") do
        if token ~= "oakui" and token ~= "tank" and token ~= "dps" and token ~= "healer" and token ~= "heal" then
            tokens[token] = true
        end
    end
    return tokens
end

local function GetProfileMatchScore(candidate, option)
    local candidateLower = TrimText(candidate):lower()
    local optionLower = TrimText(option):lower()
    if candidateLower == optionLower then return 10000 end
    if CompactProfileName(candidate) == CompactProfileName(option) then return 9000 end

    local candidateRole = GetRoleHint(candidate)
    local optionRole = GetRoleHint(option)
    if candidateRole and optionRole and candidateRole ~= optionRole then return nil end

    local score = 100
    if candidateRole and optionRole == candidateRole then
        score = score + 2000
    elseif candidateRole and not optionRole then
        score = score + 50
    end

    local candidateTokens = GetProfileTokens(candidate)
    for token in pairs(GetProfileTokens(option)) do
        if candidateTokens[token] then
            score = score + 200
        else
            score = score - 100
        end
    end
    return score
end

local function FindBestProfileName(candidate, options)
    local bestName, bestScore
    for _, option in ipairs(options or {}) do
        local score = GetProfileMatchScore(candidate, option)
        if score and (not bestScore or score > bestScore or (score == bestScore and option:lower() < bestName:lower())) then
            bestName, bestScore = option, score
        end
    end
    return bestName
end

local DetectedSnapshots = {}

local function BuildDetectedProfileEntries()
    DetectedSnapshots = {}
    local profiles = {
        ellesmere = GetEllesmereProfileNames(),
        bigWigs = GetBigWigsProfileNames(),
        dbm = GetDBMProfileNames(),
        blizzi = GetBlizziProfileNames(),
        wmarker = GetWMarkerProfileNames(),
        editMode = GetEditModeLayoutNames(),
    }

    local candidates, candidateSeen = {}, {}
    for _, key in ipairs({ "ellesmere", "bigWigs", "dbm", "blizzi", "wmarker" }) do
        for _, profileName in ipairs(profiles[key]) do
            if key == "ellesmere" or GetRoleHint(profileName) then
                AddProfileName(candidates, candidateSeen, profileName)
            end
        end
    end
    SortProfileNames(candidates)

    local entries, snapshotSeen = {}, {}
    for _, candidate in ipairs(candidates) do
        local snapshot = {
            ellesmere = FindBestProfileName(candidate, profiles.ellesmere) or "",
            editMode = FindBestProfileName(candidate, profiles.editMode)
                or (addonTable.IsForever and addonTable.GetActiveEditModeLayoutName and addonTable.GetActiveEditModeLayoutName()) or "",
            bigWigs = FindBestProfileName(candidate, profiles.bigWigs) or "",
            dbm = FindBestProfileName(candidate, profiles.dbm) or "",
            blizzi = FindBestProfileName(candidate, profiles.blizzi) or "",
            wmarker = FindBestProfileName(candidate, profiles.wmarker) or "",
            capturedAt = 0,
        }
        if snapshot.ellesmere ~= "" and snapshot.editMode ~= "" then
            local signature = table.concat({ snapshot.ellesmere, snapshot.editMode, snapshot.bigWigs, snapshot.dbm, snapshot.blizzi, snapshot.wmarker }, "\031")
            if not snapshotSeen[signature] then
                snapshotSeen[signature] = true
                local key = "detected:" .. tostring(#entries + 1)
                DetectedSnapshots[key] = { snapshot = snapshot, label = candidate }
                entries[#entries + 1] = {
                    key = key,
                    label = "Existing profiles: " .. candidate,
                    summary = "Detected OakUI profiles already stored by your addons:\n" .. GetSnapshotSummary(snapshot),
                    time = 0,
                    detected = true,
                }
            end
        end
    end
    return entries
end

function addonTable.CaptureCurrentOakProfileSnapshot()
    local characters = GetInstallCharacters()
    local key = GetCharacterKey()
    local state = characters[key]
    if type(state) ~= "table" or state.completed ~= true then return false end

    local snapshot = {
        ellesmere = GetEllesmereProfile(),
        editMode = addonTable.GetActiveEditModeLayoutName and TrimText(addonTable.GetActiveEditModeLayoutName()) or "",
        bigWigs = GetBigWigsProfile(),
        dbm = TrimText(_G.DBM_UsedProfile),
        blizzi = GetBlizziProfile(),
        wmarker = GetWMarkerProfile(),
        capturedAt = time and time() or 0,
    }
    if snapshot.ellesmere == "" or snapshot.editMode == "" then return false end

    state.profileSnapshot = snapshot
    characters[key] = state
    return true
end

GetSnapshotSummary = function(snapshot)
    local values = {}
    local function Add(label, value)
        value = TrimText(value)
        if value ~= "" then values[#values + 1] = label .. ": " .. value end
    end
    Add("EllesmereUI", snapshot.ellesmere)
    Add("Edit Mode", snapshot.editMode)
    Add("BigWigs", snapshot.bigWigs)
    Add("DBM", snapshot.dbm)
    Add("Blizzi", snapshot.blizzi)
    Add("wMarker", snapshot.wmarker)
    return table.concat(values, "\n")
end

function addonTable.GetOakAltSetupCharacters()
    addonTable.CaptureCurrentOakProfileSnapshot()
    local currentKey = GetCharacterKey()
    local entries = {}
    for key, state in pairs(GetInstallCharacters()) do
        local snapshot = type(state) == "table" and state.profileSnapshot
        if key ~= currentKey and type(state) == "table" and state.completed == true and type(snapshot) == "table"
            and TrimText(snapshot.ellesmere) ~= "" and TrimText(snapshot.editMode) ~= "" then
            entries[#entries + 1] = {
                key = key,
                label = key,
                summary = GetSnapshotSummary(snapshot),
                time = tonumber(snapshot.capturedAt) or tonumber(state.time) or 0,
            }
        end
    end
    table.sort(entries, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return a.label < b.label
    end)
    return entries
end

function addonTable.GetOakAltSetupOptions()
    local entries = BuildDetectedProfileEntries()
    for _, entry in ipairs(addonTable.GetOakAltSetupCharacters()) do
        entry.label = "Configured character: " .. entry.label
        entries[#entries + 1] = entry
    end
    return entries
end

local function BigWigsProfileExists(profileName)
    if _G.BigWigsAPI and type(_G.BigWigsAPI.IsValidProfile) == "function" then
        local ok, exists = pcall(_G.BigWigsAPI.IsValidProfile, profileName)
        if ok then return exists == true end
    end
    if ProfileExists(type(_G.BigWigs3DB) == "table" and _G.BigWigs3DB.profiles, profileName) then
        return true
    end
    local namespaces = type(_G.BigWigs3DB) == "table" and _G.BigWigs3DB.namespaces
    if type(namespaces) == "table" then
        for _, namespace in pairs(namespaces) do
            if ProfileExists(type(namespace) == "table" and namespace.profiles, profileName) then return true end
        end
    end
    return false
end

local function PreflightSnapshot(snapshot)
    local errors = {}
    local ellesmereProfile = TrimText(snapshot.ellesmere)
    if not _G.EllesmereUI or type(_G.EllesmereUI.SwitchProfile) ~= "function" then
        errors[#errors + 1] = "EllesmereUI profile switching is not ready yet."
    elseif not ProfileExists(type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles, ellesmereProfile) then
        errors[#errors + 1] = "EllesmereUI profile '" .. ellesmereProfile .. "' is unavailable."
    end

    local editModeLayout = TrimText(snapshot.editMode)
    if editModeLayout ~= "" and addonTable.IsEditModeLayoutAvailable and not addonTable.IsEditModeLayoutAvailable(editModeLayout) then
        errors[#errors + 1] = "Edit Mode layout '" .. editModeLayout .. "' is not available to this character."
    end
    return #errors == 0, table.concat(errors, "\n")
end

local function AddApplied(applied, label)
    applied[#applied + 1] = label
end

local function AddSkipped(skipped, label, profileName)
    skipped[#skipped + 1] = label .. " ('" .. tostring(profileName) .. "')"
end

local function ApplyEllesmere(profileName, applied)
    local EUI = _G.EllesmereUI
    if not EUI or type(EUI.SwitchProfile) ~= "function" then return false end
    local ok = pcall(EUI.SwitchProfile, profileName)
    if not ok then return false end
    local activeProfile = type(_G.EllesmereUIDB) == "table" and TrimText(_G.EllesmereUIDB.activeProfile) or ""
    if activeProfile ~= profileName then return false end
    if type(EUI.RefreshAllAddons) == "function" then pcall(EUI.RefreshAllAddons, true) end
    AddApplied(applied, "EllesmereUI")
    return true
end

local function ApplyBigWigs(profileName, applied, skipped)
    if profileName == "" or not IsAddonLoaded("BigWigs") then return end
    if not BigWigsProfileExists(profileName) or type(_G.BigWigs3DB) ~= "table" then
        AddSkipped(skipped, "BigWigs", profileName)
        return
    end
    local db = _G.BigWigsLoader and _G.BigWigsLoader.db
    if db and type(db.SetProfile) == "function" then
        local ok = pcall(db.SetProfile, db, profileName)
        if ok then
            AddApplied(applied, "BigWigs")
            return
        end
    end
    AddSkipped(skipped, "BigWigs", profileName)
end

local function ApplyDBM(profileName, applied, skipped)
    if profileName == "" or not IsAddonLoaded("DBM-Core") then return end
    if not ProfileExists(_G.DBM_AllSavedOptions, profileName)
        or not ProfileExists(_G.DBT_AllPersistentOptions, profileName) then
        AddSkipped(skipped, "DBM", profileName)
        return
    end
    _G.DBM_UsedProfile = profileName
    if _G.DBM and type(_G.DBM.ApplyProfile) == "function" then
        pcall(_G.DBM.ApplyProfile, _G.DBM, profileName)
    end
    AddApplied(applied, "DBM")
end

local function ApplyBlizzi(profileName, applied, skipped)
    if profileName == "" or not IsAddonLoaded("BliZzi_Interrupts") then return end
    local saved = _G.BliZziInterruptsSavedVars
    if not ProfileExists(type(saved) == "table" and saved.profiles, profileName) then
        AddSkipped(skipped, "Blizzi", profileName)
        return
    end
    local profiles = _G.BIT and _G.BIT.Profiles
    if profiles and type(profiles.Switch) == "function" then
        local ok, switched = pcall(profiles.Switch, profiles, profileName)
        if not ok or switched == false then
            AddSkipped(skipped, "Blizzi", profileName)
            return
        end
    else
        saved.activeProfile = profileName
    end
    AddApplied(applied, "Blizzi")
end

local function ApplyWMarker(profileName, applied, skipped)
    if profileName == "" or not IsAddonLoaded("wMarker") then return end
    local db = _G.wMarkerAce and _G.wMarkerAce.db
    local stored = db and db.profiles or (type(_G.wMarkerAceDB) == "table" and _G.wMarkerAceDB.profiles)
    if not ProfileExists(stored, profileName) or not db or type(db.SetProfile) ~= "function" then
        AddSkipped(skipped, "wMarker", profileName)
        return
    end
    local ok = pcall(db.SetProfile, db, profileName)
    if ok then AddApplied(applied, "wMarker") else AddSkipped(skipped, "wMarker", profileName) end
end

local function ApplyChatLayout(applied)
    local apply = addonTable.ScheduleChatWindowsAfterEllesmereProfile or addonTable.SetupChatWindows
    if type(apply) ~= "function" then return false end

    local ok, result = pcall(apply, true)
    if not ok or result ~= true then return false end

    if addonTable.MarkOakChatGeometryAfterReload then
        addonTable.MarkOakChatGeometryAfterReload()
    elseif addonTable.MarkOakChatLayoutAfterReload then
        addonTable.MarkOakChatLayoutAfterReload()
    end
    AddApplied(applied, "Chat Layout")
    return true
end

function addonTable.ApplyOakAltSetup(sourceKey, options)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat before setting up this character."
    end
    options = type(options) == "table" and options or {}

    local characters = GetInstallCharacters()
    local detected = DetectedSnapshots[sourceKey]
    local sourceState = not detected and characters[sourceKey]
    local snapshot = detected and CopySnapshot(detected.snapshot)
        or type(sourceState) == "table" and CopySnapshot(sourceState.profileSnapshot)
    if not snapshot then return false, "That profile setup is no longer available. Reopen Set Up Alt and try again." end

    local ready, preflightError = PreflightSnapshot(snapshot)
    if not ready then return false, preflightError end

    local applied, skipped = {}, {}
    if snapshot.editMode ~= "" and addonTable.ActivateEditModeLayout then
        if not addonTable.ActivateEditModeLayout(snapshot.editMode) then
            return false, "Edit Mode could not activate layout '" .. snapshot.editMode .. "'."
        end
        AddApplied(applied, "Edit Mode")
        if addonTable.MarkEditModeActivationAfterReload then
            addonTable.MarkEditModeActivationAfterReload(snapshot.editMode)
        end
    end

    if not ApplyEllesmere(snapshot.ellesmere, applied) then
        return false, "EllesmereUI could not switch to profile '" .. snapshot.ellesmere .. "'."
    end

    ApplyBigWigs(snapshot.bigWigs, applied, skipped)
    ApplyDBM(snapshot.dbm, applied, skipped)
    ApplyBlizzi(snapshot.blizzi, applied, skipped)
    ApplyWMarker(snapshot.wmarker, applied, skipped)

    local chatLayoutFailed = options.chatLayout == true and not ApplyChatLayout(applied)

    local currentKey = GetCharacterKey()
    local state = characters[currentKey] or {}
    local now = time and time() or 0
    state.seen = true
    state.seenVersion = addonTable.Profiles and addonTable.Profiles.VERSION or "Unknown"
    state.seenTime = state.seenTime or now
    state.completed = true
    state.version = addonTable.Profiles and addonTable.Profiles.VERSION or "Unknown"
    state.time = now
    if detected then
        state.copiedFrom = nil
        state.profileSource = detected.label
    else
        state.copiedFrom = sourceKey
        state.profileSource = nil
    end
    snapshot.capturedAt = state.time
    state.profileSnapshot = snapshot
    characters[currentKey] = state

    local cdmRepopulateQueued = false
    if addonTable.MarkEllesmereCDMRepopulateAfterReload then
        addonTable.MarkEllesmereCDMRepopulateAfterReload()
        cdmRepopulateQueued = true
    end

    local message = "Applied existing profiles for: " .. table.concat(applied, ", ") .. "."
    if #skipped > 0 then
        message = message .. "\nSkipped unavailable optional profiles: " .. table.concat(skipped, ", ") .. "."
    end
    if chatLayoutFailed then
        message = message .. "\nThe chat layout could not be applied. Try Apply Chat Layout from Chat Cleaning after reload."
    end
    if cdmRepopulateQueued then
        message = message .. "\nAfter reload, OakUI will open the Ellesmere CDM repopulate confirmation."
    end
    return true, message
end
