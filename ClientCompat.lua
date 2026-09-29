local addonName, addonTable = ...

-- Forever shares the modern engine, but has its own content and spell setup.
-- Resolve once, before any module installs hooks or registers events.
local interface = select(4, GetBuildInfo())
addonTable.IsForever = type(interface) == "number" and interface >= 16000 and interface < 20000

if not addonTable.IsForever then return end

-- Obtain the recipient's export header instead of assuming Retail's wire
-- format. The bundled v2 exports have ten tokens per single-anchor system.
function addonTable.DecodeForeverEditMode(encoded, preset)
    local tokens = {}
    for token in encoded:gmatch("%S+") do tokens[#tokens + 1] = token end
    local count = tonumber(tokens[2])
    if tokens[1] ~= "2" or not count or #tokens ~= 2 + count * 10 then
        return nil, "Unrecognized OakUI Edit Mode source format."
    end
    local exported = C_EditMode.ConvertLayoutInfoToString(preset)
    local native = {}
    for token in exported:gmatch("%S+") do native[#native + 1] = token end
    local header
    if tonumber(native[3]) == #preset.systems then
        header = native[1] .. " " .. native[2] .. " " .. count
    elseif tonumber(native[2]) == #preset.systems then
        header = native[1] .. " " .. count
    else
        return nil, "Unrecognized Forever Edit Mode export header."
    end
    local layout = C_EditMode.ConvertStringToLayoutInfo(header .. " " .. table.concat(tokens, " ", 3))
    if type(layout) ~= "table" or type(layout.systems) ~= "table" or #layout.systems ~= count then
        return nil, "Forever did not decode all OakUI Edit Mode systems."
    end
    local points = { [0] = "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
    for i, system in ipairs(layout.systems) do
        local offset = 2 + (i - 1) * 10
        local anchor = system.anchorInfo
        if tokens[offset + 9] ~= "-1" or not anchor
            or anchor.relativeTo ~= tokens[offset + 6]
            or anchor.point ~= points[tonumber(tokens[offset + 4])]
            or anchor.relativePoint ~= points[tonumber(tokens[offset + 5])]
            or math.abs((tonumber(anchor.offsetX) or math.huge) - tonumber(tokens[offset + 7])) > 0.01
            or math.abs((tonumber(anchor.offsetY) or math.huge) - tonumber(tokens[offset + 8])) > 0.01 then
            return nil, "Forever decoded an incorrect anchor for OakUI system " .. i .. ". Nothing was saved."
        end
    end
    return layout
end

addonTable.ForeverExcludedModules = {
    EllesmereUIDragonRiding = true,
    EllesmereUIMythicTimer = true,
    EllesmereUICooldownManager = true,
    EllesmereUIAuraBuffReminders = true,
    EllesmereUIQuickdraw = true,
}

-- Forever uses Action Bar 6 in place of the Retail Cooldown Manager. Keep
-- this client-specific translation here so Retail never changes Bar 6.
local FOREVER_ACTION_BAR_VISIBILITY_KEYS = {
    "visOnlyInstances", "visHideInstances",
    "visOnlyDungeons", "visHideDungeons",
    "visHideHousing", "visOnlyHousing",
    "visHideMounted", "visOnlyMounted",
    "visHideDragonriding", "visOnlySkyriding",
    "visHideNoTarget", "visHideWithTarget",
    "visHideNoEnemy", "visHideWithEnemy",
    "visOnlyResting", "visHideResting",
    "visOnlyVehicle", "visHideVehicle",
    "visOnlyPartyMode", "visHidePartyMode",
}

local function GetForeverActionBarVisibilityKeys()
    return type(_G.EllesmereUI) == "table"
        and type(_G.EllesmereUI.VIS_OPT_KEYS) == "table"
        and _G.EllesmereUI.VIS_OPT_KEYS
        or FOREVER_ACTION_BAR_VISIBILITY_KEYS
end

function addonTable.ApplyForeverCooldownActionBarVisibility(settings, hideWithoutTarget)
    if type(settings) ~= "table" then return false end

    local savedAlpha = settings._savedBarAlpha
    settings.barVisibility = "always"
    settings.alwaysHidden = false
    settings.mouseoverEnabled = false
    settings.combatHideEnabled = false
    settings.combatShowEnabled = false
    settings.visibilityModes = nil
    settings.visibilityMatch = nil
    settings.visibilityOverride = nil
    if savedAlpha ~= nil then
        settings.mouseoverAlpha = savedAlpha
        settings._savedBarAlpha = nil
    elseif settings.mouseoverAlpha == nil or settings.mouseoverAlpha <= 0 then
        settings.mouseoverAlpha = 1
    end

    for _, key in ipairs(GetForeverActionBarVisibilityKeys()) do
        settings[key] = false
    end
    settings.visHideNoTarget = hideWithoutTarget == true
    return true
end

function addonTable.GetForeverCooldownActionBarVisibility(settings)
    if type(settings) ~= "table" then return nil end
    if settings.barVisibility ~= "always"
        or settings.alwaysHidden == true
        or settings.mouseoverEnabled == true
        or settings.visibilityModes ~= nil
        or settings.visibilityOverride ~= nil
        or settings.visHideNoTarget ~= true then
        return false
    end
    for _, key in ipairs(GetForeverActionBarVisibilityKeys()) do
        if key ~= "visHideNoTarget" and settings[key] == true then
            return false
        end
    end
    return true
end

-- Operates only on a newly decoded OakUI payload, never on existing profiles.
-- EUI merges omitted modules from the player's current Forever profile.
function addonTable.PrepareForeverPayload(payload)
    local data = type(payload) == "table" and payload.data
    if type(data) ~= "table" or type(data.addons) ~= "table" then
        return nil, "OakUI's Ellesmere profile payload is invalid."
    end

    local folders = {}
    for folder in pairs(data.addons) do
        if addonTable.ForeverExcludedModules[folder]
            or not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(folder)) then
            data.addons[folder] = nil
        else
            folders[folder] = true
        end
    end

    data.cdmSpells = nil
    data.spellAssignments = nil
    data.assignedSpecs = nil
    data.blizzSkinGlobals = nil
    data.applyBlizzSkinGlobals = nil
    for _, key in ipairs({
        "specOverrides", "specOverrideGroups", "specOverrideNextId",
        "condOverrides", "condOverrideGroups", "condOverrideNextId",
        "specUnlockOverrides", "condUnlockOverrides", "specBmOverrides", "condBmOverrides",
    }) do
        data[key] = nil
    end
    data.overridesIncluded = nil
    data.overridesExcluded = true
    data.partialImport = true

    if data.unlockLayout then
        local EUI = _G.EllesmereUI
        if not (EUI and type(EUI.BuildImportKeyToFolder) == "function"
            and type(EUI.FilterLayoutToFolders) == "function") then
            return nil, "Update EllesmereUI before importing an OakUI Forever layout."
        end
        local meta = data.unlockLayoutMeta
        local keyToFolder = EUI.BuildImportKeyToFolder(data.unlockLayout, meta and meta.keyToFolder)
        data.unlockLayout = EUI.FilterLayoutToFolders(data.unlockLayout, folders, keyToFolder)
        data.unlockLayoutMeta = nil
    end
    return payload
end
