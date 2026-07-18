local addonName, addonTable = ...
local P = addonTable.Profiles

local ROLE_PROFILE_NAMES = {
    dps = "OakUI Tank/DPS",
    heals = "OakUI Healer",
}

local SOURCE_PROFILE_NAMES = {
    dps = { "OakUI Tank/DPS", "OakUI-Tank/DPS", "OakUI DPS", "OakUI Tank" },
    heals = { "OakUI Healer", "OakUI-Healer", "OakUI Heals", "OakUI Heals/Healer" },
}

local MODULES = {
    { key = "actionbars", folder = "EllesmereUIActionBars", display = "Action Bars" },
    { key = "unitframes", folder = "EllesmereUIUnitFrames", display = "Unit Frames" },
    { key = "raidframes", folder = "EllesmereUIRaidFrames", display = "Raid/Party Frames" },
    { key = "cooldowns", folder = "EllesmereUICooldownManager", display = "Cooldown Manager" },
    { key = "resourcebars", folder = "EllesmereUIResourceBars", display = "Resource Bars" },
    { key = "chat", folder = "EllesmereUIChat", display = "Chat" },
    { key = "bags", folder = "EllesmereUIBags", display = "Bags" },
    { key = "minimap", folder = "EllesmereUIMinimap", display = "Minimap" },
    { key = "nameplates", folder = "EllesmereUINameplates", display = "Nameplates" },
    { key = "auras", folder = "EllesmereUIAuraBuffReminders", display = "Aura/Buff Reminders" },
    { key = "qol", folder = "EllesmereUIQoL", display = "Quality of Life" },
    { key = "quests", folder = "EllesmereUIQuestTracker", display = "Quest Tracker" },
    { key = "mythic", folder = "EllesmereUIMythicTimer", display = "Mythic+ Timer" },
    { key = "meters", folder = "EllesmereUIDamageMeters", display = "Damage Meters" },
    { key = "friends", folder = "EllesmereUIFriends", display = "Friends List" },
    { key = "databars", folder = "EllesmereUIDataBars", display = "DataBars" },
    { key = "dragonriding", folder = "EllesmereUIDragonRiding", display = "Dragonriding" },
}

local SECTION_DEFS = {
    { key = "layout", display = "Positions / Unlock Layout", desc = "Frame anchors, unlock positions, scale, CDM bar positions, and stored layout anchors." },
    { key = "fonts", display = "Fonts", desc = "Ellesmere font settings and OakUI font references." },
    { key = "colors", display = "Colors / Theme", desc = "Theme, class accent behavior, custom colors, and profile accent." },
    { key = "textures", display = "Bar Textures", desc = "Texture and border texture keys across all embedded module profiles." },
    { key = "cdmBars", display = "CDM Button Layout", desc = "Cooldown Manager button bars, icon size, shape, row counts, and CDM bar anchors." },
    { key = "cdmSpells", display = "CDM Icons", desc = "Per-spec CDM spell assignments and button spell choices." },
    { key = "cdmGlows", display = "CDM Glows", desc = "Per-spec CDM glow and active-state assignments." },
    { key = "buffBars", display = "Buff Bars", desc = "Tracked buff bars and their per-spec positions." },
    { key = "clickCast", display = "Click Cast", desc = "Ellesmere raid-frame click-cast bindings from the OakUI snapshot." },
}

addonTable.EllesmereSelectiveModules = MODULES
addonTable.EllesmereSelectiveSections = SECTION_DEFS

local CATEGORY_TREE = {
    {
        id = "section:profile",
        label = "Profile Sections",
        description = "Shared profile-level data that is not owned by a single Ellesmere addon.",
        header = true,
        children = {
            { id = "theme", label = "Theme / Fonts / Colors", description = "Shared fonts, textures, accent colors, and class color behavior.", recommended = false },
            { id = "layout", label = "Layout", description = "Mover positions, HUD anchors, size matches, and stored layout data.", recommended = false },
            { id = "clickCast", label = "Click Cast", description = "Ellesmere raid-frame click-cast bindings from the OakUI snapshot.", recommended = false },
        },
    },
    {
        id = "section:addons",
        label = "Per-Addon Import",
        description = "Import only the Ellesmere addon modules you want, matching Ellesmere's per-addon import model.",
        header = true,
        children = {
            {
                id = "module:EllesmereUIActionBars",
                label = "Action Bars",
                description = "Action bar styling, fade rules, and per-bar behavior.",
                recommended = true,
                children = {
                    { id = "actionBarsMaster", label = "Master Settings", description = "Global action bar textures, glows, and shared settings.", recommended = true },
                    { id = "actionBarsMouseover", label = "Mouseover Hide", description = "Mouseover fade and visibility rules.", recommended = true },
                    { id = "actionBarsPerBar", label = "Per-Bar Overrides", description = "Per-bar overrides for action bars and Blizzard support bars.", recommended = true },
                    { id = "actionBarsExtraButtons", label = "Extra Buttons", description = "Extra Action Button, encounter, and queue button settings.", recommended = true },
                    { id = "actionBarsTotemBar", label = "Totem Bar", description = "Totem and class support bar settings.", recommended = true },
                },
            },
            {
                id = "module:EllesmereUINameplates",
                label = "Nameplates",
                description = "Ellesmere nameplate styling, behavior, cast bars, and rounded border profile data.",
                recommended = true,
            },
            {
                id = "module:EllesmereUIUnitFrames",
                label = "Unit Frames",
                description = "Player, target, focus, pet, and boss frame settings.",
                recommended = true,
                children = {
                    { id = "unitFramesGeneral", label = "General", description = "Master unit frame settings and shared visuals.", recommended = true },
                    { id = "unitFramePlayer", label = "Player", description = "Player frame settings.", recommended = true },
                    { id = "unitFrameTarget", label = "Target", description = "Target frame settings.", recommended = true },
                    { id = "unitFrameToT", label = "ToT", description = "Target-of-target frame settings.", recommended = true },
                    { id = "unitFramePet", label = "Pet", description = "Pet frame settings.", recommended = true },
                    { id = "unitFrameFocus", label = "Focus", description = "Focus frame settings.", recommended = true },
                    { id = "unitFrameBoss", label = "Boss", description = "Boss frame settings.", recommended = true },
                },
            },
            {
                id = "module:EllesmereUICooldownManager",
                label = "Cooldown Manager",
                description = "Cooldown bars, icon styling, glows, and per-spec spell layout.",
                recommended = true,
                children = {
                    { id = "cdmBars", label = "CDM Bars", description = "Button bars, icon size, shape, rows, and CDM anchors.", recommended = true },
                    { id = "cdmSpells", label = "CDM Icons", description = "Per-spec cooldown spell assignments and button spell choices.", recommended = true },
                    { id = "cdmGlows", label = "CDM Glows", description = "Per-spec glow and active-state assignments.", recommended = true },
                    { id = "buffBars", label = "Buff Bars", description = "Tracked buff bars and their per-spec positions.", recommended = true },
                    {
                        id = "customCdmBars",
                        label = "Custom CDM Bars",
                        description = "Custom CDM bar settings and individual imported bars.",
                        recommended = true,
                        dynamicChildren = "customCdmBars",
                        children = {
                            { id = "customCdmBarsShared", label = "Shared Settings", description = "CDM bar keybind display and shared visibility settings.", recommended = true },
                        },
                    },
                },
            },
            {
                id = "module:EllesmereUIResourceBars",
                label = "Resource Bars",
                description = "Cast bars, power bars, class resources, and totems.",
                recommended = true,
                children = {
                    { id = "castBars", label = "Cast Bars / Power HUD", description = "Cast bars, class resource bars, totems, and HUD resources.", recommended = true },
                    { id = "cdmClassResourceBar", label = "Class Resource Bar", description = "Primary and secondary class resource bars.", recommended = true },
                },
            },
            {
                id = "module:EllesmereUIRaidFrames",
                label = "Raid Frames",
                description = "Party, raid, and raid buff settings.",
                recommended = true,
                children = {
                    { id = "groupFramesGeneral", label = "General", description = "Shared group frame options and global toggles.", recommended = true },
                    { id = "groupFramesParty", label = "Party", description = "Party frame designer settings.", recommended = true },
                    { id = "groupFramesRaid", label = "Raid", description = "Raid frame designer settings.", recommended = true },
                },
            },
            { id = "module:EllesmereUIAuraBuffReminders", label = "AuraBuff Reminders", description = "Aura reminder and utility widget settings.", recommended = true },
            { id = "module:EllesmereUIQoL", label = "Quality of Life", description = "Automation helpers, popup blocker, consumables, and utility toggles.", recommended = true },
            { id = "module:EllesmereUIDragonRiding", label = "Dragon Riding", description = "Dragonriding UI settings hosted by Ellesmere's Blizzard skin module.", recommended = true },
            { id = "module:EllesmereUIBags", label = "Bags", description = "Bag module styling and bag behavior.", recommended = true },
            { id = "module:EllesmereUIFriends", label = "Friends List", description = "Friends panel and related datatext settings.", recommended = true },
            { id = "module:EllesmereUIMythicTimer", label = "Mythic+ Timer", description = "Mythic+ timer styling and behavior.", recommended = true },
            { id = "module:EllesmereUIQuestTracker", label = "Quest Tracker", description = "Quest tracker styling and behavior.", recommended = true },
            { id = "module:EllesmereUIMinimap", label = "Minimap", description = "Minimap frame and minimap utility settings.", recommended = true },
            { id = "module:EllesmereUIDamageMeters", label = "Damage Meters", description = "Damage meter panel styling and layout.", recommended = true },
            { id = "module:EllesmereUIChat", label = "Chat", description = "Chat frame skinning, formatting, and utility options.", recommended = true },
            { id = "module:EllesmereUIDataBars", label = "DataBars", description = "DataBars module styling and behavior. Character gold data is never imported.", recommended = true },
        },
    },
}

addonTable.EllesmereSelectiveTree = CATEGORY_TREE

local function DeepCopy(src, seen)
    if type(src) ~= "table" then return src end
    if seen and seen[src] then return seen[src] end
    seen = seen or {}
    local copy = {}
    seen[src] = copy
    for k, v in pairs(src) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            copy[DeepCopy(k, seen)] = DeepCopy(v, seen)
        end
    end
    return copy
end

local function DeepMerge(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = DeepCopy(v)
        end
    end
end

local function ClearAndCopy(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k in pairs(dst) do dst[k] = nil end
    for k, v in pairs(src) do dst[k] = DeepCopy(v) end
end

local function EnsureEllesmereDB()
    if type(_G.EllesmereUIDB) ~= "table" then _G.EllesmereUIDB = {} end
    local db = _G.EllesmereUIDB
    db.profiles = db.profiles or {}
    db.profileOrder = db.profileOrder or {}
    db.specProfiles = db.specProfiles or {}
    return db
end

local function FindProfile(snapshot, names)
    local profiles = snapshot and snapshot.profiles
    if type(profiles) ~= "table" then return nil, nil end
    for _, name in ipairs(names) do
        if type(profiles[name]) == "table" then return name, profiles[name] end
    end
end

local function GetSourceProfile(role)
    local snapshot = P.ELLESMERE_SNAPSHOT
    if type(snapshot) ~= "table" then return nil, nil end

    role = role == "heals" and "heals" or "dps"
    return FindProfile(snapshot, SOURCE_PROFILE_NAMES[role])
end

function addonTable.GetOakEllesmereRoleProfileName(role)
    return ROLE_PROFILE_NAMES[role == "heals" and "heals" or "dps"]
end

local function AddProfileOrder(db, profileName)
    for _, name in ipairs(db.profileOrder) do
        if name == profileName then return end
    end
    table.insert(db.profileOrder, 1, profileName)
end

local function GetTargetProfile(db, profileName)
    local currentName = db.activeProfile or "Default"
    local base = db.profiles[profileName] or db.profiles[currentName] or {}
    db.profiles[profileName] = DeepCopy(base)
    db.profiles[profileName].addons = db.profiles[profileName].addons or {}
    AddProfileOrder(db, profileName)
    return db.profiles[profileName]
end

local function SelectionIncludes(selection, key)
    return selection == nil or selection.all or selection[key]
end

local function CopyRootKeys(db, snapshot, keys)
    for _, key in ipairs(keys) do
        if snapshot[key] ~= nil then db[key] = DeepCopy(snapshot[key]) end
    end
end

local function CopyProfileKeys(targetProfile, sourceProfile, keys)
    for _, key in ipairs(keys) do
        if sourceProfile[key] ~= nil then targetProfile[key] = DeepCopy(sourceProfile[key]) end
    end
end

local function ApplyRootUnlockLayoutFromProfile(db, profile)
    local layout = type(profile) == "table" and profile.unlockLayout
    if type(db) ~= "table" or type(layout) ~= "table" then return end

    db.unlockAnchors = DeepCopy(layout.anchors or {})
    db.unlockWidthMatch = DeepCopy(layout.widthMatch or {})
    db.unlockHeightMatch = DeepCopy(layout.heightMatch or {})
    db.phantomBounds = DeepCopy(layout.phantomBounds or {})
end

local function NormalizeHealerResourceLayout(profile)
    if type(profile) ~= "table" then return end

    local layout = profile.unlockLayout
    if type(layout) == "table" then
        if type(layout.anchors) == "table" then
            layout.anchors.ERB_ClassResource = nil
        end
        if type(layout.widthMatch) == "table" then
            layout.widthMatch.ERB_ClassResource = nil
        end
    end

    local resourceBars = profile.addons and profile.addons.EllesmereUIResourceBars
    local secondary = type(resourceBars) == "table" and resourceBars.secondary
    if type(secondary) == "table" then
        secondary.anchorTo = "erb_powerbar"
        secondary.anchorPosition = "top"
        secondary.anchorOffsetX = 0
        secondary.anchorOffsetY = 0
    end
end

local function CopyAddon(targetProfile, sourceProfile, folder)
    local srcAddons = sourceProfile.addons
    if type(srcAddons) ~= "table" or type(srcAddons[folder]) ~= "table" then return false end
    targetProfile.addons = targetProfile.addons or {}
    local copy = DeepCopy(srcAddons[folder])
    if folder == "EllesmereUIDataBars" then
        copy.characters = nil
        copy.currentMoney = nil
        local function ClearMoneyFields(node)
            if type(node) ~= "table" then return end
            node.currentMoney = nil
            for _, value in pairs(node) do
                ClearMoneyFields(value)
            end
        end
        ClearMoneyFields(copy)
    end
    targetProfile.addons[folder] = copy
    return true
end

local function GetAddonTable(profile, folder)
    if type(profile) ~= "table" then return nil end
    local addons = profile.addons
    if type(addons) ~= "table" then return nil end
    return addons[folder]
end

local function EnsureTargetAddon(targetProfile, folder)
    targetProfile.addons = targetProfile.addons or {}
    targetProfile.addons[folder] = targetProfile.addons[folder] or {}
    return targetProfile.addons[folder]
end

local function GetPath(root, path)
    if type(root) ~= "table" or type(path) ~= "string" or path == "" then return nil, false end
    local node = root
    for part in path:gmatch("[^%.]+") do
        local key = tonumber(part) or part
        if type(node) ~= "table" or node[key] == nil then return nil, false end
        node = node[key]
    end
    return node, true
end

local function SetPath(root, path, value)
    if type(root) ~= "table" or type(path) ~= "string" or path == "" then return end
    local parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = tonumber(part) or part end
    local node = root
    for i = 1, #parts - 1 do
        local key = parts[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[parts[#parts]] = DeepCopy(value)
end

local function CopyAddonKeys(targetProfile, sourceProfile, folder, keys)
    local src = GetAddonTable(sourceProfile, folder)
    if type(src) ~= "table" or type(keys) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, folder)
    for _, key in ipairs(keys) do
        if src[key] ~= nil then dst[key] = DeepCopy(src[key]) end
    end
end

local function CopyAddonPaths(targetProfile, sourceProfile, folder, paths)
    local src = GetAddonTable(sourceProfile, folder)
    if type(src) ~= "table" or type(paths) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, folder)
    for _, path in ipairs(paths) do
        local value, exists = GetPath(src, path)
        if exists then SetPath(dst, path, value) end
    end
end

local function CopyAddonExceptKeys(targetProfile, sourceProfile, folder, excluded)
    local src = GetAddonTable(sourceProfile, folder)
    if type(src) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, folder)
    excluded = excluded or {}
    for k, v in pairs(src) do
        if not excluded[k] then dst[k] = DeepCopy(v) end
    end
end

local function CopyTableKeys(dst, src, keys)
    if type(dst) ~= "table" or type(src) ~= "table" or type(keys) ~= "table" then return end
    for _, key in ipairs(keys) do
        if src[key] ~= nil then dst[key] = DeepCopy(src[key]) end
    end
end

local function ShouldCopyTextureKey(key)
    key = tostring(key):lower()
    return key:find("texture", 1, true) ~= nil or key:find("statusbar", 1, true) ~= nil
end

local function ShouldCopyPositionKey(key)
    key = tostring(key):lower()
    return key == "x" or key == "y" or key == "point" or key == "relpoint"
        or key:find("position", 1, true) ~= nil
        or key:find("anchor", 1, true) ~= nil
        or key:find("offset", 1, true) ~= nil
end

local function CopyMatchingKeys(dst, src, predicate)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if predicate(k) then
            dst[k] = DeepCopy(v)
        elseif type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyMatchingKeys(dst[k], v, predicate)
        end
    end
end

local function ApplyTextures(targetProfile, sourceProfile)
    if type(sourceProfile.addons) ~= "table" then return end
    targetProfile.addons = targetProfile.addons or {}
    for folder, src in pairs(sourceProfile.addons) do
        if type(src) == "table" then
            targetProfile.addons[folder] = targetProfile.addons[folder] or {}
            CopyMatchingKeys(targetProfile.addons[folder], src, ShouldCopyTextureKey)
        end
    end
end

local function ApplyModulePositions(targetProfile, sourceProfile)
    if type(sourceProfile.addons) ~= "table" then return end
    targetProfile.addons = targetProfile.addons or {}
    for folder, src in pairs(sourceProfile.addons) do
        if type(src) == "table" then
            targetProfile.addons[folder] = targetProfile.addons[folder] or {}
            CopyMatchingKeys(targetProfile.addons[folder], src, ShouldCopyPositionKey)
        end
    end
end

local function ApplyCDMBars(targetProfile, sourceProfile)
    local src = sourceProfile.addons and sourceProfile.addons.EllesmereUICooldownManager
    if type(src) ~= "table" then return end
    targetProfile.addons.EllesmereUICooldownManager = targetProfile.addons.EllesmereUICooldownManager or {}
    local dst = targetProfile.addons.EllesmereUICooldownManager
    for _, key in ipairs({ "cdmBars", "cdmBarPositions" }) do
        if src[key] ~= nil then dst[key] = DeepCopy(src[key]) end
    end
end

local function GetSpecAssignmentStores(db, profileName)
    db.spellAssignments = db.spellAssignments or {}
    db.spellAssignments.specProfiles = db.spellAssignments.specProfiles or {}

    local profileSpecs
    if profileName and profileName ~= "" then
        db.spellAssignments.profiles = db.spellAssignments.profiles or {}
        db.spellAssignments.profiles[profileName] = db.spellAssignments.profiles[profileName] or {}
        db.spellAssignments.profiles[profileName].specProfiles = db.spellAssignments.profiles[profileName].specProfiles or {}
        profileSpecs = db.spellAssignments.profiles[profileName].specProfiles
    end

    return db.spellAssignments.specProfiles, profileSpecs
end

local function ApplySpecAssignmentKeys(db, snapshot, keys, profileName)
    local srcProfiles = snapshot.spellAssignments and snapshot.spellAssignments.specProfiles
    if type(srcProfiles) ~= "table" then return end
    local legacySpecs, profileSpecs = GetSpecAssignmentStores(db, profileName)
    for specID, srcSpec in pairs(srcProfiles) do
        if type(srcSpec) == "table" then
            legacySpecs[specID] = legacySpecs[specID] or {}
            local profileSpec
            if profileSpecs then
                profileSpecs[specID] = profileSpecs[specID] or {}
                profileSpec = profileSpecs[specID]
            end
            for _, key in ipairs(keys) do
                if srcSpec[key] ~= nil then
                    legacySpecs[specID][key] = DeepCopy(srcSpec[key])
                    if profileSpec then profileSpec[key] = DeepCopy(srcSpec[key]) end
                end
            end
        end
    end
end

local function ApplySpecBarKeys(db, snapshot, barKeys, profileName)
    local srcProfiles = snapshot.spellAssignments and snapshot.spellAssignments.specProfiles
    if type(srcProfiles) ~= "table" or type(barKeys) ~= "table" then return end
    local legacySpecs, profileSpecs = GetSpecAssignmentStores(db, profileName)
    for specID, srcSpec in pairs(srcProfiles) do
        if type(srcSpec) == "table" then
            legacySpecs[specID] = legacySpecs[specID] or {}
            local targetSpecs = { legacySpecs[specID] }
            if profileSpecs then
                profileSpecs[specID] = profileSpecs[specID] or {}
                targetSpecs[#targetSpecs + 1] = profileSpecs[specID]
            end
            for _, rootKey in ipairs({ "barSpells", "barGlows" }) do
                if type(srcSpec[rootKey]) == "table" then
                    for _, dstSpec in ipairs(targetSpecs) do
                        dstSpec[rootKey] = dstSpec[rootKey] or {}
                        for _, barKey in ipairs(barKeys) do
                            if srcSpec[rootKey][barKey] ~= nil then
                                dstSpec[rootKey][barKey] = DeepCopy(srcSpec[rootKey][barKey])
                            end
                        end
                    end
                end
            end
        end
    end
end

local function ApplyCDMBarByKey(targetProfile, sourceProfile, db, snapshot, barKey, profileName)
    if type(barKey) ~= "string" or barKey == "" then return end
    local src = GetAddonTable(sourceProfile, "EllesmereUICooldownManager")
    if type(src) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, "EllesmereUICooldownManager")

    if type(src.cdmBars) == "table" and type(src.cdmBars.bars) == "table" then
        dst.cdmBars = dst.cdmBars or {}
        dst.cdmBars.bars = dst.cdmBars.bars or {}
        local implicitKeys = { "cooldowns", "utility", "buffs" }
        for index, bar in ipairs(src.cdmBars.bars) do
            local sourceKey = type(bar) == "table" and (bar.key or implicitKeys[index]) or nil
            if sourceKey == barKey then
                dst.cdmBars.bars[index] = DeepCopy(bar)
            end
        end
    end

    if src.cdmBarPositions and src.cdmBarPositions[barKey] ~= nil then
        dst.cdmBarPositions = dst.cdmBarPositions or {}
        dst.cdmBarPositions[barKey] = DeepCopy(src.cdmBarPositions[barKey])
    end

    ApplySpecBarKeys(db, snapshot, { barKey }, profileName)
end

local function ApplyCDMBarGroup(targetProfile, sourceProfile, db, snapshot, barKeys, profileName)
    for _, barKey in ipairs(barKeys or {}) do
        ApplyCDMBarByKey(targetProfile, sourceProfile, db, snapshot, barKey, profileName)
    end
end

local function ApplyActionBarSubset(targetProfile, sourceProfile, barKeys, fieldPredicate)
    local src = GetAddonTable(sourceProfile, "EllesmereUIActionBars")
    if type(src) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, "EllesmereUIActionBars")
    dst.bars = dst.bars or {}
    dst.barPositions = dst.barPositions or {}
    for _, barKey in ipairs(barKeys or {}) do
        if type(src.bars) == "table" and type(src.bars[barKey]) == "table" then
            if fieldPredicate then
                dst.bars[barKey] = dst.bars[barKey] or {}
                for field, value in pairs(src.bars[barKey]) do
                    if fieldPredicate(field) then dst.bars[barKey][field] = DeepCopy(value) end
                end
            else
                dst.bars[barKey] = DeepCopy(src.bars[barKey])
            end
        end
        if type(src.barPositions) == "table" and src.barPositions[barKey] ~= nil then
            dst.barPositions[barKey] = DeepCopy(src.barPositions[barKey])
        end
    end
end

local function IsMouseoverField(field)
    field = tostring(field):lower()
    return field:find("mouseover", 1, true) ~= nil or field == "_savedbaralpha" or field == "barvisibility"
end

local function ApplyGroupFramesSubset(targetProfile, sourceProfile, mode)
    local src = GetAddonTable(sourceProfile, "EllesmereUIRaidFrames")
    if type(src) ~= "table" then return end
    local dst = EnsureTargetAddon(targetProfile, "EllesmereUIRaidFrames")
    for key, value in pairs(src) do
        local lower = tostring(key):lower()
        local isParty = lower:find("^party") ~= nil or lower:find("party", 1, true) ~= nil
        local isPosition = lower:find("unlockpos", 1, true) ~= nil
        if mode == "party" and isParty and not isPosition then
            dst[key] = DeepCopy(value)
        elseif mode == "raid" and not isParty and not isPosition then
            dst[key] = DeepCopy(value)
        elseif mode == "general" and (lower:find("tooltip", 1, true) or lower:find("role", 1, true) or lower:find("preview", 1, true)) then
            dst[key] = DeepCopy(value)
        end
    end
end

local function ApplySelectionCategory(id, db, snapshot, targetProfile, sourceProfile, profileName)
    if id == "theme" then
        CopyRootKeys(db, snapshot, { "fonts", "fctFont", "customColors", "activeTheme", "useClassAccentColor" })
        CopyProfileKeys(targetProfile, sourceProfile, { "fonts", "customColors", "euiAccent" })
        ApplyTextures(targetProfile, sourceProfile)
    elseif id == "layout" then
        CopyRootKeys(db, snapshot, {
            "unlockAnchors", "unlockWidthMatch", "unlockHeightMatch", "phantomBounds",
            "ppUIScale", "ppUIScaleAuto", "unlockGridMode", "unlockSnapEnabled",
            "unlockBannerScale", "shifterPositions", "fpsPos", "bagsPosition",
        })
        CopyProfileKeys(targetProfile, sourceProfile, { "unlockLayout" })
        ApplyModulePositions(targetProfile, sourceProfile)
    elseif id == "unitFrames" then
        CopyAddonExceptKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { positions = true })
    elseif id == "unitFramesGeneral" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "healthBarTexture" })
    elseif id == "unitFramePlayer" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "player" })
    elseif id == "unitFrameTarget" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "target" })
    elseif id == "unitFrameToT" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "targettarget", "totPet" })
    elseif id == "unitFramePet" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "pet" })
    elseif id == "unitFrameFocus" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "focus", "focustarget" })
    elseif id == "unitFrameBoss" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIUnitFrames", { "boss" })
    elseif id == "groupFrames" then
        CopyAddonExceptKeys(targetProfile, sourceProfile, "EllesmereUIRaidFrames", { unlockPos = true, partyUnlockPos = true })
        if snapshot.clickCast ~= nil then db.clickCast = DeepCopy(snapshot.clickCast) end
    elseif id == "groupFramesGeneral" then
        ApplyGroupFramesSubset(targetProfile, sourceProfile, "general")
        if snapshot.clickCast ~= nil then db.clickCast = DeepCopy(snapshot.clickCast) end
    elseif id == "groupFramesParty" then
        ApplyGroupFramesSubset(targetProfile, sourceProfile, "party")
    elseif id == "groupFramesRaid" then
        ApplyGroupFramesSubset(targetProfile, sourceProfile, "raid")
    elseif id == "castBars" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIResourceBars", { "castBar", "health", "primary", "secondary", "totemBar" })
    elseif id == "cdm" then
        ApplyCDMBars(targetProfile, sourceProfile)
        ApplySpecAssignmentKeys(db, snapshot, { "barSpells", "barGlows", "trackedBuffBars", "tbbPositions" }, profileName)
    elseif id == "cdmEssential" then
        ApplyCDMBarGroup(targetProfile, sourceProfile, db, snapshot, { "cooldowns" }, profileName)
    elseif id == "cdmUtility" then
        ApplyCDMBarGroup(targetProfile, sourceProfile, db, snapshot, { "utility", "focuskick" }, profileName)
    elseif id == "cdmBuff" then
        ApplyCDMBarGroup(targetProfile, sourceProfile, db, snapshot, { "buffs" }, profileName)
        ApplySpecAssignmentKeys(db, snapshot, { "trackedBuffBars", "tbbPositions" }, profileName)
    elseif id == "cdmClassResourceBar" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIResourceBars", { "primary", "secondary" })
    elseif id == "cdmEffects" then
        ApplySpecAssignmentKeys(db, snapshot, { "barGlows" }, profileName)
        CopyAddonPaths(targetProfile, sourceProfile, "EllesmereUICooldownManager", { "cdmBars.bars" })
    elseif id == "cdmRotationAssist" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUICooldownManager", { "spec" })
    elseif id == "cdmKeybinds" then
        CopyRootKeys(db, snapshot, { "profileKeybinds" })
    elseif id == "actionBars" then
        CopyAddonExceptKeys(targetProfile, sourceProfile, "EllesmereUIActionBars", { barPositions = true })
    elseif id == "actionBarsMaster" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIActionBars", { "highlightTextureType", "pushedTextureType", "procGlowEnabled", "procGlowType", "mouseoverShowAll" })
    elseif id == "actionBarsMouseover" then
        local bars = { "MainBar", "Bar2", "Bar3", "Bar4", "Bar5", "PetBar", "StanceBar", "RepBar", "XPBar", "EncounterBar", "QueueStatus" }
        ApplyActionBarSubset(targetProfile, sourceProfile, bars, IsMouseoverField)
    elseif id == "actionBarsPerBar" then
        ApplyActionBarSubset(targetProfile, sourceProfile, { "MainBar", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8", "PetBar", "StanceBar", "MicroBar", "BagBar", "RepBar", "XPBar" })
    elseif id == "actionBarsExtraButtons" then
        ApplyActionBarSubset(targetProfile, sourceProfile, { "ExtraActionButton", "EncounterBar", "QueueStatus" })
    elseif id == "actionBarsTotemBar" then
        CopyAddonKeys(targetProfile, sourceProfile, "EllesmereUIResourceBars", { "totemBar" })
    elseif id == "minimapDatatexts" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIMinimap")
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIDamageMeters")
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIFriends")
    elseif id == "minimapSubtab" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIMinimap")
    elseif id == "datatextSubtab" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIDamageMeters")
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIFriends")
    elseif id == "customCdmBars" then
        ApplyCDMBars(targetProfile, sourceProfile)
        ApplySpecAssignmentKeys(db, snapshot, { "barSpells", "barGlows" }, profileName)
    elseif id == "customCdmBarsShared" then
        CopyAddonPaths(targetProfile, sourceProfile, "EllesmereUICooldownManager", { "cdmBars" })
    elseif type(id) == "string" and id:find("^customCdmBar:") then
        ApplyCDMBarByKey(targetProfile, sourceProfile, db, snapshot, id:match("^customCdmBar:(.+)$"), profileName)
    elseif id == "timersWidgets" then
        for _, folder in ipairs({ "EllesmereUIMythicTimer", "EllesmereUIQuestTracker", "EllesmereUIAuraBuffReminders", "EllesmereUIDragonRiding" }) do
            CopyAddon(targetProfile, sourceProfile, folder)
        end
    elseif id == "chat" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIChat")
    elseif id == "nameplatesDataBars" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUINameplates")
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIDataBars")
    elseif id == "nameplatesOnly" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUINameplates")
    elseif id == "dataBarsOnly" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIDataBars")
    elseif id == "qol" then
        CopyAddon(targetProfile, sourceProfile, "EllesmereUIQoL")
        CopyRootKeys(db, snapshot, {
            "autoFillDelete", "autoLogging", "autoOpenContainers", "autoUnwrapCollections",
            "keystonePopup", "quickLoot", "reskinGameMenu", "reskinQueuePopup",
            "showSpellID", "skipCinematics", "skipCinematicsAuto",
        })
    elseif id == "skinning" then
        for _, folder in ipairs({ "EllesmereUIBags", "EllesmereUINameplates" }) do
            CopyAddon(targetProfile, sourceProfile, folder)
        end
        CopyRootKeys(db, snapshot, {
            "bagCategoryOrder", "bagCategoryState", "bagDefaultGroupsSeeded",
            "bagDisabledCategories", "bagPinnedItems", "bagSidebarCollapsed",
            "bagVisualOrder", "bagsPosition", "bagsVisible", "currencyOrder",
            "statSectionsOrder", "themedCharacterSheet",
        })
    end
end

function addonTable.GetOakEllesmereCustomCdmChildren(role)
    local snapshot = P.ELLESMERE_SNAPSHOT
    local _, sourceProfile = GetSourceProfile(role)
    local src = GetAddonTable(sourceProfile, "EllesmereUICooldownManager")
    local bars = src and src.cdmBars and src.cdmBars.bars
    if type(bars) ~= "table" then return {} end
    local children = {}
    for index, bar in ipairs(bars) do
        if type(bar) == "table" and type(bar.key) == "string" and bar.key:find("^custom_") then
            local name = bar.name and tostring(bar.name) or ("Custom Bar " .. index)
            local count = 0
            local spells = snapshot and snapshot.spellAssignments and snapshot.spellAssignments.specProfiles
            if type(spells) == "table" then
                for _, spec in pairs(spells) do
                    local source = spec and spec.barSpells and spec.barSpells[bar.key]
                    if type(source) == "table" then
                        for _ in pairs(source) do count = count + 1 end
                        break
                    end
                end
            end
            children[#children + 1] = {
                id = "customCdmBar:" .. bar.key,
                label = name,
                description = count > 0 and (count .. " entries; " .. bar.key) or bar.key,
                recommended = true,
                dynamic = true,
            }
        end
    end
    return children
end

local function RepointEllesmereProfile(profileName)
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.SwitchProfile) == "function" then
        local ok = pcall(EUI.SwitchProfile, profileName)
        if ok then return end
    end

    local db = EnsureEllesmereDB()
    db.activeProfile = profileName
    local registry = EUI and EUI.Lite and EUI.Lite._dbRegistry
    local profile = db.profiles and db.profiles[profileName]
    if type(registry) == "table" and type(profile) == "table" then
        profile.addons = profile.addons or {}
        for _, addonDB in ipairs(registry) do
            local folder = addonDB.folder
            if folder then
                profile.addons[folder] = profile.addons[folder] or {}
                addonDB.profile = profile.addons[folder]
                addonDB._profileName = profileName
            end
        end
    end
end

local function RefreshEllesmere()
    if _G.EllesmereUI and type(_G.EllesmereUI.RefreshAllAddons) == "function" then
        pcall(_G.EllesmereUI.RefreshAllAddons, _G.EllesmereUI)
    end
    if addonTable.RefreshEllesmereVisibilityTweaks then
        pcall(addonTable.RefreshEllesmereVisibilityTweaks)
    end
    if addonTable.RefreshEllesmereResourceAnchor then
        pcall(addonTable.RefreshEllesmereResourceAnchor, true)
        if C_Timer and C_Timer.After then
            C_Timer.After(0.75, function()
                if addonTable.RefreshEllesmereResourceAnchor then
                    pcall(addonTable.RefreshEllesmereResourceAnchor, true)
                end
            end)
            C_Timer.After(2.1, function()
                if addonTable.RefreshEllesmereResourceAnchor then
                    pcall(addonTable.RefreshEllesmereResourceAnchor, true)
                end
            end)
        end
    end
end

function addonTable.ApplyOakEllesmereSnapshot(profileName, role, selection, quiet)
    if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.IsAddOnLoaded("EllesmereUI") then
        if not quiet then print("|cffff0000[OakUI]|r EllesmereUI must be loaded before applying the OakUI Ellesmere snapshot.") end
        return false
    end

    local snapshot = P.ELLESMERE_SNAPSHOT
    if type(snapshot) ~= "table" then
        if not quiet then print("|cffff0000[OakUI]|r Ellesmere snapshot is missing. Run GenerateEllesmereSnapshot.ps1 before packaging.") end
        return false
    end

    local sourceName, sourceProfile = GetSourceProfile(role)
    if type(sourceProfile) ~= "table" then
        if not quiet then print("|cffff0000[OakUI]|r No usable Ellesmere source profile was found in the OakUI snapshot.") end
        return false
    end

    role = role == "heals" and "heals" or "dps"
    profileName = profileName and profileName ~= "" and profileName or addonTable.GetOakEllesmereRoleProfileName(role)

    local db = EnsureEllesmereDB()
    local targetProfile = GetTargetProfile(db, profileName)

    if type(selection) == "table" and not selection.all then
        for key, enabled in pairs(selection) do
            if enabled then
                ApplySelectionCategory(key, db, snapshot, targetProfile, sourceProfile, profileName)
            end
        end
    end

    if SelectionIncludes(selection, "layout") then
        CopyRootKeys(db, snapshot, {
            "unlockAnchors", "unlockWidthMatch", "unlockHeightMatch", "phantomBounds",
            "ppUIScale", "ppUIScaleAuto", "unlockGridMode", "unlockSnapEnabled",
            "unlockBannerScale", "shifterPositions", "fpsPos", "bagsPosition",
        })
        CopyProfileKeys(targetProfile, sourceProfile, { "unlockLayout" })
        ApplyModulePositions(targetProfile, sourceProfile)
    end

    if SelectionIncludes(selection, "fonts") then
        CopyRootKeys(db, snapshot, { "fonts", "fctFont" })
        CopyProfileKeys(targetProfile, sourceProfile, { "fonts" })
    end

    if SelectionIncludes(selection, "colors") then
        CopyRootKeys(db, snapshot, { "customColors", "activeTheme", "useClassAccentColor" })
        CopyProfileKeys(targetProfile, sourceProfile, { "customColors", "euiAccent" })
    end

    if SelectionIncludes(selection, "textures") then
        ApplyTextures(targetProfile, sourceProfile)
    end

    if SelectionIncludes(selection, "cdmBars") then
        ApplyCDMBars(targetProfile, sourceProfile)
    end

    if SelectionIncludes(selection, "cdmSpells") then
        ApplySpecAssignmentKeys(db, snapshot, { "barSpells" }, profileName)
    end

    if SelectionIncludes(selection, "cdmGlows") then
        ApplySpecAssignmentKeys(db, snapshot, { "barGlows" }, profileName)
    end

    if SelectionIncludes(selection, "buffBars") then
        ApplySpecAssignmentKeys(db, snapshot, { "trackedBuffBars", "tbbPositions" }, profileName)
    end

    if SelectionIncludes(selection, "clickCast") then
        if snapshot.clickCast ~= nil then db.clickCast = DeepCopy(snapshot.clickCast) end
    end

    for _, module in ipairs(MODULES) do
        if SelectionIncludes(selection, "module:" .. module.folder) then
            CopyAddon(targetProfile, sourceProfile, module.folder)
        end
    end

    if role == "heals" then
        NormalizeHealerResourceLayout(targetProfile)
    end

    if SelectionIncludes(selection, "layout") then
        ApplyRootUnlockLayoutFromProfile(db, targetProfile)
    end

    db.activeProfile = profileName
    if db.lastNonSpecProfile ~= nil then db.lastNonSpecProfile = profileName end
    RepointEllesmereProfile(profileName)
    RefreshEllesmere()
    if addonTable.MarkEllesmereCDMAutoRepopulateProfile then
        addonTable.MarkEllesmereCDMAutoRepopulateProfile(profileName)
    end
    if addonTable.ScheduleEllesmereCDMRepopulate
        and (SelectionIncludes(selection, "cdmBars") or SelectionIncludes(selection, "cdmSpells"))
    then
        addonTable.ScheduleEllesmereCDMRepopulate(profileName, "snapshot")
    end

    if not quiet then
        print("|cff17ee15[OakUI]|r Applied Ellesmere snapshot '" .. tostring(sourceName) .. "' to profile '" .. tostring(profileName) .. "'.")
    end
    return true
end

function addonTable.ApplyOakEllesmereSnapshotAll(profileName, role, quiet)
    return addonTable.ApplyOakEllesmereSnapshot(profileName, role, { all = true }, quiet)
end
