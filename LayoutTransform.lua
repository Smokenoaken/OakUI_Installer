local addonName, addonTable = ...

local BASE_WIDTH = 2560
local BASE_HEIGHT = 1440
local BASE_UI_SCALE = 0.64

local PRESETS = {
    { key = "native", label = "OakUI Native", desc = "2560x1440 at 0.64.", width = 2560, height = 1440, scale = 0.64 },
    { key = "1080p", label = "1080p OakUI 0.64", desc = "1920x1080 at 0.64.", width = 1920, height = 1080, scale = 0.64 },
    { key = "1080p_compact", label = "1080p Compact 0.533", desc = "1920x1080 at 0.533.", width = 1920, height = 1080, scale = 0.533 },
    { key = "1440p_pp", label = "1440p Pixel Perfect", desc = "2560x1440 at 0.533.", width = 2560, height = 1440, scale = 0.533 },
    { key = "uw3440_oak", label = "3440 Ultrawide 0.64", desc = "3440x1440 at 0.64.", width = 3440, height = 1440, scale = 0.64 },
    { key = "uw3440_pp", label = "3440 Ultrawide 0.533", desc = "3440x1440 at 0.533.", width = 3440, height = 1440, scale = 0.533 },
    { key = "4k", label = "4K", desc = "3840x2160 at 0.356.", width = 3840, height = 2160, scale = 0.356 },
    { key = "uw_oak", label = "5120 Super Ultrawide 0.64", desc = "5120x1440 at 0.64.", width = 5120, height = 1440, scale = 0.64 },
    { key = "uw_pp", label = "5120 Super Ultrawide 0.533", desc = "5120x1440 at 0.533.", width = 5120, height = 1440, scale = 0.533 },
}

local PRESET_BY_KEY = {}
for _, preset in ipairs(PRESETS) do
    PRESET_BY_KEY[preset.key] = preset
end
PRESET_BY_KEY["1080p_oak"] = PRESET_BY_KEY["1080p"]

local activePresetKey = "native"
local BASE_DAMAGE_METER_1_OFFSET_X = 939.1666666666666
local EDGE_MARGIN = 0
local EDGE_MARGIN_BY_PRESET = {
    ["1080p"] = 0,
}
local RAID_FRAME_KEY = "RF_RaidFrames"
local DRAGON_RIDING_KEY = "EDR_Cluster"
local DRAGON_RIDING_TARGET_KEY = "ERB_Power"
local RAID_FRAME_CLAMP_PRESETS = {
    ["1080p"] = true,
    ["1080p_oak"] = true,
    ["1080p_compact"] = true,
}
local EXTRA_FRAMES_CONTAINER_NAME = "ERFExtraFramesContainer"
local EXTRA_FRAMES_GAP = 5
local DEFAULT_MINIMAP_SIZE = 210
local OBJECTIVE_TRACKER_SCALE_NUDGE = 25
local OBJECTIVE_TRACKER_GAP_BELOW_MINIMAP = 0
local OBJECTIVE_TRACKER_1080P_MAX_HEIGHT = 550
local OBJECTIVE_TRACKER_MIN_HEIGHT = 400
local OBJECTIVE_TRACKER_MAX_HEIGHT = 1200
local OBJECTIVE_TRACKER_DAMAGE_METER_GAP = 18
local OBJECTIVE_TRACKER_1080P_FLOOR = 550
local QUEUE_STATUS_CORNER_INSET = 22
local DBM_HUGE_TARGET_AURA_CLEARANCE = 22
local DBM_HUGE_BAR_TARGET_GAP = 16
local DBM_HUGE_SCALE_GAP_NUDGE_MAX = 3
local DBM_HUGE_VISUAL_WIDTH_INSET = 4
local DBM_HUGE_VISUAL_X_NUDGE = -3
local DAMAGE_METER_VISIBLE_ROWS = {
    [1] = 5, -- Overall Damage Done
    [2] = 5, -- Damage Done
    [3] = 3, -- Healing Done
}

local function EnsureDB()
    if not OakUI_DB then OakUI_DB = {} end
    OakUI_DB.layoutTransform = OakUI_DB.layoutTransform or {}
    return OakUI_DB.layoutTransform
end

local function GetActiveEllesmereProfileName()
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.GetActiveProfileName) == "function" then
        local ok, profileName = pcall(EUI.GetActiveProfileName)
        if ok then return profileName end
    end
    return type(_G.EllesmereUIDB) == "table" and (_G.EllesmereUIDB.activeProfile or _G.EllesmereUIDB.profile)
end

local function DefaultRoleProfileName(role)
    if addonTable.GetOakEllesmereRoleProfileName then
        return addonTable.GetOakEllesmereRoleProfileName(role)
    end
    return role == "heals" and "OakUI Healer" or "OakUI Tank/DPS"
end

local function RememberProfileRole(profileName, role)
    if not profileName or (role ~= "dps" and role ~= "heals") then return end
    local db = EnsureDB()
    db.ellesmereProfileRoles = db.ellesmereProfileRoles or {}
    db.ellesmereProfileRoles[profileName] = role
end

local function GetProfileRole(profileName)
    if not profileName then return nil end
    local roles = OakUI_DB and OakUI_DB.layoutTransform and OakUI_DB.layoutTransform.ellesmereProfileRoles
    if type(roles) == "table" and roles[profileName] then return roles[profileName] end
    if profileName == DefaultRoleProfileName("heals") then return "heals" end
    if profileName == DefaultRoleProfileName("dps") then return "dps" end
end

local function IsTankDPSProfile(profileName, role)
    if role == "dps" then return true end
    if role == "heals" then return false end
    return GetProfileRole(profileName) == "dps"
end

local function IsActiveEllesmereProfile(profileName)
    if not profileName or profileName == "" then return true end
    return GetActiveEllesmereProfileName() == profileName
end

local function EnsureEllesmereMovementAlertProfile()
    local getter = _G._EUI_MovementAlert_DB
    if type(getter) == "function" then
        local ok, movementDB = pcall(getter)
        if ok and type(movementDB) == "table" and type(movementDB.profile) == "table" then
            if type(movementDB.profile.movementAlert) ~= "table" then
                movementDB.profile.movementAlert = {}
            end
            return true
        end
    end

    local euiDB = _G.EllesmereUIDB
    local profileName = GetActiveEllesmereProfileName()
    local profile = type(euiDB) == "table"
        and type(euiDB.profiles) == "table"
        and profileName
        and euiDB.profiles[profileName]
    if type(profile) ~= "table" then return false end

    profile.addons = profile.addons or {}
    profile.addons.EllesmereUIQoL = profile.addons.EllesmereUIQoL or {}
    if type(profile.addons.EllesmereUIQoL.movementAlert) ~= "table" then
        profile.addons.EllesmereUIQoL.movementAlert = {}
    end
    return true
end

local function GetPreset(key)
    return PRESET_BY_KEY[key or activePresetKey] or PRESET_BY_KEY.native
end

local function GetCurrentUIScale()
    local dbScale = type(_G.EllesmereUIDB) == "table" and tonumber(_G.EllesmereUIDB.ppUIScale)
    if dbScale and dbScale > 0 then return dbScale end

    if UIParent and type(UIParent.GetScale) == "function" then
        local ok, scale = pcall(UIParent.GetScale, UIParent)
        scale = ok and tonumber(scale)
        if scale and scale > 0 then return scale end
    end

    if type(GetCVar) == "function" then
        local scale = tonumber(GetCVar("uiScale"))
        if scale and scale > 0 then return scale end
    end

    return BASE_UI_SCALE
end

local function GetCVarValue(name)
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value and value ~= "" then return value end
    end
    if type(GetCVar) == "function" then
        local ok, value = pcall(GetCVar, name)
        if ok and value and value ~= "" then return value end
    end
end

local function ParseResolutionText(value)
    if type(value) ~= "string" then return nil, nil end
    local width, height = value:match("(%d+)%s*[xX]%s*(%d+)")
    width, height = tonumber(width), tonumber(height)
    if width and width > 0 and height and height > 0 then
        return width, height
    end
end

local function GetIndexedScreenResolution()
    if type(GetCurrentResolution) ~= "function" or type(GetScreenResolutions) ~= "function" then
        return nil, nil
    end

    local okIndex, index = pcall(GetCurrentResolution)
    index = okIndex and tonumber(index)
    if not index or index <= 0 then return nil, nil end

    local resolutions = { pcall(GetScreenResolutions) }
    if not resolutions[1] then return nil, nil end

    local resolution = resolutions[index + 1]
    return ParseResolutionText(resolution)
end

local function GetCurrentPhysicalResolution()
    local width, height
    if type(GetPhysicalScreenSize) == "function" then
        local ok, physW, physH = pcall(GetPhysicalScreenSize)
        if ok then
            width, height = tonumber(physW), tonumber(physH)
        end
    end

    if width and width > 0 and height and height > 0 then
        return math.floor(width + 0.5), math.floor(height + 0.5)
    end

    for _, cvarName in ipairs({ "gxResolution", "gxFullscreenResolution" }) do
        local width, height = ParseResolutionText(GetCVarValue(cvarName))
        if width and height then
            return math.floor(width + 0.5), math.floor(height + 0.5)
        end
    end

    local indexedWidth, indexedHeight = GetIndexedScreenResolution()
    if indexedWidth and indexedHeight then
        return math.floor(indexedWidth + 0.5), math.floor(indexedHeight + 0.5)
    end

    local windowedWidth, windowedHeight = ParseResolutionText(GetCVarValue("gxWindowedResolution"))
    if windowedWidth and windowedHeight then
        return math.floor(windowedWidth + 0.5), math.floor(windowedHeight + 0.5)
    end

    if type(GetScreenWidth) == "function" and type(GetScreenHeight) == "function" then
        width, height = tonumber(GetScreenWidth()), tonumber(GetScreenHeight())
    end

    if not width or width <= 0 or not height or height <= 0 then
        return nil, nil
    end

    return math.floor(width + 0.5), math.floor(height + 0.5)
end

local function ResolutionScore(preset, width, height)
    if not width or not height then return math.huge end
    local presetWidth = tonumber(preset and preset.width) or BASE_WIDTH
    local presetHeight = tonumber(preset and preset.height) or BASE_HEIGHT
    local aspect = width / height
    local presetAspect = presetWidth / presetHeight
    local aspectScore = math.abs(aspect - presetAspect) * 10000
    local heightScore = math.abs(height - presetHeight)
    local widthScore = math.abs(width - presetWidth) * 0.25
    return aspectScore + heightScore + widthScore
end

local function DetectRecommendedPreset()
    local width, height = GetCurrentPhysicalResolution()
    if not width or not height then
        return GetPreset("native"), { width = nil, height = nil, scale = GetCurrentUIScale() }
    end

    local userScale = GetCurrentUIScale()
    local bestPreset, bestResolutionScore, bestScaleScore
    for _, preset in ipairs(PRESETS) do
        local resolutionScore = ResolutionScore(preset, width, height)
        local scaleScore = math.abs(userScale - (tonumber(preset.scale) or BASE_UI_SCALE))
        if not bestPreset
            or resolutionScore < bestResolutionScore - 0.001
            or (math.abs(resolutionScore - bestResolutionScore) <= 0.001 and scaleScore < bestScaleScore)
        then
            bestPreset = preset
            bestResolutionScore = resolutionScore
            bestScaleScore = scaleScore
        end
    end

    return bestPreset or GetPreset("native"), { width = width, height = height, scale = userScale }
end

local function SameResolution(preset, width, height)
    return type(preset) == "table"
        and tonumber(preset.width) == tonumber(width)
        and tonumber(preset.height) == tonumber(height)
end

local function GetFactors(preset)
    preset = preset or GetPreset()
    local targetScale = tonumber(preset.scale) or BASE_UI_SCALE
    local scaleFactor = BASE_UI_SCALE / targetScale
    return {
        key = preset.key,
        label = preset.label,
        x = ((tonumber(preset.width) or BASE_WIDTH) / BASE_WIDTH) * scaleFactor,
        y = ((tonumber(preset.height) or BASE_HEIGHT) / BASE_HEIGHT) * scaleFactor,
    }
end

local X_KEYS = {
    x = true,
    posx = true,
    positionx = true,
    offsetx = true,
    xoffset = true,
    xofs = true,
    anchoroffsetx = true,
    barxoffset = true,
}

local Y_KEYS = {
    y = true,
    posy = true,
    positiony = true,
    offsety = true,
    yoffset = true,
    yofs = true,
    anchoroffsety = true,
    baryoffset = true,
}

local function AxisForKey(key)
    local lower = tostring(key or ""):lower():gsub("[_%-%s]", "")
    if lower:find("shadow", 1, true)
        or lower:find("border", 1, true)
        or lower:find("padding", 1, true)
        or lower:find("margin", 1, true)
    then
        return nil
    end
    if X_KEYS[lower] then return "x" end
    if Y_KEYS[lower] then return "y" end
    if lower:find("xoffset", 1, true) or lower:find("offsetx", 1, true) then return "x" end
    if lower:find("yoffset", 1, true) or lower:find("offsety", 1, true) then return "y" end
end

local function TransformNumber(value, axis, factors)
    local factor = axis == "x" and factors.x or factors.y
    return value * factor
end

local function TransformTable(root, factors, seen)
    if type(root) ~= "table" then return root end
    if seen and seen[root] then return root end
    seen = seen or {}
    seen[root] = true

    for key, value in pairs(root) do
        local axis = AxisForKey(key)
        if axis and type(value) == "number" then
            root[key] = TransformNumber(value, axis, factors)
        elseif type(value) == "table" then
            TransformTable(value, factors, seen)
        end
    end
    return root
end

function addonTable.GetOakLayoutPresets()
    return PRESETS
end

function addonTable.GetOakRecommendedLayoutPreset()
    return DetectRecommendedPreset()
end

function addonTable.GetOakLayoutPresetGroups()
    local recommended, detected = DetectRecommendedPreset()
    local recommendedGroup = {}
    local alternatives = {}
    for _, preset in ipairs(PRESETS) do
        if detected and detected.width and detected.height and SameResolution(preset, detected.width, detected.height) then
            recommendedGroup[#recommendedGroup + 1] = preset
        elseif recommended and SameResolution(preset, recommended.width, recommended.height) then
            recommendedGroup[#recommendedGroup + 1] = preset
        else
            alternatives[#alternatives + 1] = preset
        end
    end
    if #recommendedGroup == 0 and recommended then
        recommendedGroup[1] = recommended
    end
    return recommendedGroup, alternatives, detected, recommended
end

function addonTable.SetOakLayoutPreset(key)
    local preset = GetPreset(key)
    activePresetKey = preset.key
    local db = EnsureDB()
    db.preset = preset.key
    db.width = preset.width
    db.height = preset.height
    db.scale = preset.scale
    return preset
end

function addonTable.GetOakLayoutPreset()
    local db = OakUI_DB and OakUI_DB.layoutTransform
    return GetPreset((db and db.preset) or activePresetKey)
end

function addonTable.GetOakLayoutTransform()
    local preset = addonTable.GetOakLayoutPreset()
    local factors = GetFactors(preset)
    factors.active = math.abs(factors.x - 1) > 0.0001 or math.abs(factors.y - 1) > 0.0001
    return factors
end

function addonTable.IsOakLayoutTransformActive()
    local factors = addonTable.GetOakLayoutTransform()
    return factors and factors.active == true
end

function addonTable.ApplyOakLayoutTransform(root)
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active then return root end
    return TransformTable(root, factors)
end

function addonTable.TransformOakLayoutPosition(position)
    if type(position) ~= "table" then return position end
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active then return position end

    for key, value in pairs(position) do
        local axis = AxisForKey(key)
        if axis and type(value) == "number" then
            position[key] = TransformNumber(value, axis, factors)
        end
    end
    return position
end

local function TransformMinimap(profile)
    local minimap = profile
        and profile.addons
        and profile.addons.EllesmereUIMinimap
        and profile.addons.EllesmereUIMinimap.minimap
    if type(minimap) ~= "table" then return end

    addonTable.TransformOakLayoutPosition(minimap.position)
end

local function UiCoordWidth(preset)
    local width = tonumber(preset and preset.width) or BASE_WIDTH
    local scale = tonumber(preset and preset.scale) or BASE_UI_SCALE
    if scale <= 0 then scale = BASE_UI_SCALE end
    return width / scale
end

local function LayoutSizeScaleForPreset(preset)
    local scale = tonumber(preset and preset.scale) or BASE_UI_SCALE
    if scale <= 0 then scale = BASE_UI_SCALE end
    return BASE_UI_SCALE / scale
end

local function ComputeDamageMeterOffsetX(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    return BASE_DAMAGE_METER_1_OFFSET_X + ((UiCoordWidth(preset) - (BASE_WIDTH / BASE_UI_SCALE)) / 2)
end

local ComputeDamageMeterHeightForRows

local function EdgeMarginForPreset(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    local presetMargin = preset and EDGE_MARGIN_BY_PRESET[preset.key]
    if presetMargin ~= nil then return presetMargin end
    return EDGE_MARGIN
end

local function ComputeObjectiveTrackerTopRightOffset(preset)
    local margin = EdgeMarginForPreset(preset)
    local scaleFactor = LayoutSizeScaleForPreset(preset)
    local minimapOffset = DEFAULT_MINIMAP_SIZE + ((scaleFactor - 1) * OBJECTIVE_TRACKER_SCALE_NUDGE)
    return 0, -(margin + minimapOffset + OBJECTIVE_TRACKER_GAP_BELOW_MINIMAP)
end

local function ComputeObjectiveTrackerMaxHeight(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    local height = tonumber(preset and preset.height) or BASE_HEIGHT
    local scale = tonumber(preset and preset.scale) or BASE_UI_SCALE
    if height <= 0 then height = BASE_HEIGHT end
    if scale <= 0 then scale = BASE_UI_SCALE end

    local scaledFallback = OBJECTIVE_TRACKER_1080P_MAX_HEIGHT
        * (height / 1080)
        * (BASE_UI_SCALE / scale)
    local _, objectiveY = ComputeObjectiveTrackerTopRightOffset(preset)
    local trackerTopOffset = math.abs(tonumber(objectiveY) or 0)
    local meterStackHeight = 0

    for index, rows in pairs(DAMAGE_METER_VISIBLE_ROWS) do
        meterStackHeight = meterStackHeight + ComputeDamageMeterHeightForRows(nil, rows, preset)
    end

    local availableHeight = height - trackerTopOffset - meterStackHeight - OBJECTIVE_TRACKER_DAMAGE_METER_GAP
    if height <= 1080 then
        availableHeight = math.max(availableHeight, OBJECTIVE_TRACKER_1080P_FLOOR)
        availableHeight = math.min(availableHeight, scaledFallback)
    elseif availableHeight <= OBJECTIVE_TRACKER_MIN_HEIGHT then
        availableHeight = scaledFallback
    end

    return math.floor(math.max(OBJECTIVE_TRACKER_MIN_HEIGHT, math.min(OBJECTIVE_TRACKER_MAX_HEIGHT, availableHeight)) + 0.5)
end

local function PatchMinimapPosition(profile)
    local margin = EdgeMarginForPreset()
    local minimap = profile
        and profile.addons
        and profile.addons.EllesmereUIMinimap
        and profile.addons.EllesmereUIMinimap.minimap
    if type(minimap) ~= "table" then return false end

    minimap.position = {
        point = "TOPRIGHT",
        relPoint = "TOPRIGHT",
        x = -margin,
        y = -margin,
    }
    return true
end

local function GetProfileMinimapSize(profile)
    local minimap = profile
        and profile.addons
        and profile.addons.EllesmereUIMinimap
        and profile.addons.EllesmereUIMinimap.minimap
    return tonumber(type(minimap) == "table" and minimap.mapSize) or DEFAULT_MINIMAP_SIZE
end

local function PatchQueueStatusPosition(profile, preset)
    local actionBars = profile
        and profile.addons
        and profile.addons.EllesmereUIActionBars
    if type(actionBars) ~= "table" then return false end

    local margin = EdgeMarginForPreset(preset)
    local mapSize = GetProfileMinimapSize(profile)
    actionBars.barPositions = actionBars.barPositions or {}
    actionBars.barPositions.QueueStatus = {
        point = "CENTER",
        relPoint = "TOPRIGHT",
        x = -(margin + QUEUE_STATUS_CORNER_INSET),
        y = -(margin + mapSize - QUEUE_STATUS_CORNER_INSET),
    }
    return true
end

function addonTable.ScaleOakLayoutLength(value)
    local preset = addonTable.GetOakLayoutPreset()
    local scaled = (tonumber(value) or 0) * LayoutSizeScaleForPreset(preset)
    return math.floor(scaled + 0.5)
end

local function ComputeDBMHugeBarGap(preset)
    local scaleFactor = LayoutSizeScaleForPreset(preset)
    local nudge = 0
    if scaleFactor > 1 then
        nudge = math.min(DBM_HUGE_SCALE_GAP_NUDGE_MAX, math.floor(((scaleFactor - 1) * 15) + 0.5))
    end
    return DBM_HUGE_BAR_TARGET_GAP - nudge
end

local function DamageMeterPixelMultiplier(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    local height = tonumber(preset and preset.height) or BASE_HEIGHT
    local scale = tonumber(preset and preset.scale) or BASE_UI_SCALE
    if height <= 0 then height = BASE_HEIGHT end
    if scale <= 0 then scale = BASE_UI_SCALE end
    return (768 / height) / scale
end

ComputeDamageMeterHeightForRows = function(dm, rows, preset)
    rows = tonumber(rows) or 0
    local headerHeight = tonumber(dm and dm.hdrHeight) or 22
    local barHeight = tonumber(dm and dm.barHeight) or 22
    local barSpacing = tonumber(dm and dm.barSpacing) or 2
    local mult = DamageMeterPixelMultiplier(preset)
    return math.floor(headerHeight + (rows * ((barHeight + barSpacing) * mult)) + 0.5)
end

local function PatchDamageMeterRowHeights(dm, preset)
    local changed = false
    for index, rows in pairs(DAMAGE_METER_VISIBLE_ROWS) do
        local window = dm.windows[index]
        if type(window) == "table" then
            local targetHeight = ComputeDamageMeterHeightForRows(dm, rows, preset)
            if not tonumber(window.height) or math.abs(window.height - targetHeight) > 0.5 then
                window.height = targetHeight
                changed = true
            end
        end
    end
    return changed
end

local function PatchDamageMeterWindowSizes(profile, preset)
    local dm = profile
        and profile.addons
        and profile.addons.EllesmereUIDamageMeters
        and profile.addons.EllesmereUIDamageMeters.dm
    if type(dm) ~= "table" or type(dm.windows) ~= "table" then return false end

    local targetSizeScale = LayoutSizeScaleForPreset(preset)
    local targetWidth = math.floor((GetProfileMinimapSize(profile) or DEFAULT_MINIMAP_SIZE) + 0.5)
    local changed = false

    for _, window in ipairs(dm.windows) do
        if type(window) == "table" then
            if not tonumber(window.width) or math.abs(window.width - targetWidth) > 0.5 then
                window.width = targetWidth
                changed = true
            end
        end
    end
    dm._oakLayoutSizeScale = targetSizeScale

    changed = PatchDamageMeterRowHeights(dm, preset) or changed

    return changed
end

local function PatchDamageMeterAnchor(anchors, preset, offsetX)
    if type(anchors) ~= "table" then return false end
    local anchor = anchors.EDM_Win1
    if type(anchor) ~= "table" then return false end

    anchor.target = "EDB_2"
    anchor.side = "TOP"
    anchor.offsetX = tonumber(offsetX) or ComputeDamageMeterOffsetX(preset)
    anchor.offsetY = 0
    return true
end

local function PatchDragonRidingAnchor(anchors)
    if type(anchors) ~= "table" then return false end
    local anchor = anchors[DRAGON_RIDING_KEY]
    local changed = false
    if type(anchor) ~= "table" then
        anchor = {}
        anchors[DRAGON_RIDING_KEY] = anchor
        changed = true
    end

    if anchor.target ~= DRAGON_RIDING_TARGET_KEY then anchor.target = DRAGON_RIDING_TARGET_KEY; changed = true end
    if anchor.side ~= "TOP" then anchor.side = "TOP"; changed = true end
    if tonumber(anchor.offsetX) ~= 0 then anchor.offsetX = 0; changed = true end
    if tonumber(anchor.offsetY) ~= 0 then anchor.offsetY = 0; changed = true end
    return changed
end

local function PatchDragonRidingWidthMatch(widthMatch)
    if type(widthMatch) ~= "table" then return false end
    if widthMatch[DRAGON_RIDING_KEY] == DRAGON_RIDING_TARGET_KEY then return false end
    widthMatch[DRAGON_RIDING_KEY] = DRAGON_RIDING_TARGET_KEY
    return true
end

local function PatchDragonRidingLayer(layer)
    if type(layer) ~= "table" then return false end
    layer.anchors = layer.anchors or {}
    layer.widthMatch = layer.widthMatch or {}
    local changed = PatchDragonRidingAnchor(layer.anchors)
    changed = PatchDragonRidingWidthMatch(layer.widthMatch) or changed
    return changed
end

local function PatchDragonRidingProfile(profile)
    if type(profile) ~= "table" then return false end

    profile.unlockLayout = profile.unlockLayout or {}
    local changed = PatchDragonRidingLayer(profile.unlockLayout)

    local dragonRiding = profile.addons
        and profile.addons.EllesmereUIDragonRiding
    if type(dragonRiding) == "table" and dragonRiding.unlockPos ~= nil then
        dragonRiding.unlockPos = nil
        changed = true
    end

    return changed
end

local function ClearDragonRidingModuleUnlockPos(profileName)
    local db = _G.EllesmereUIDragonRidingDB
    local profiles = type(db) == "table" and db.profiles
    if not profileName or type(profiles) ~= "table" or type(profiles[profileName]) ~= "table" then
        return false
    end

    if profiles[profileName].unlockPos == nil then return false end
    profiles[profileName].unlockPos = nil
    return true
end

local function PatchRaidFrameAnchorOffset(anchors, deltaX)
    deltaX = tonumber(deltaX)
    if type(anchors) ~= "table" or not deltaX or math.abs(deltaX) < 0.5 then return false end

    local anchor = anchors[RAID_FRAME_KEY]
    if type(anchor) ~= "table" then return false end

    anchor.offsetX = (tonumber(anchor.offsetX) or 0) + deltaX
    return true
end

local function PatchTankDPSExtraFrames(profile)
    local raidFrames = profile
        and profile.addons
        and profile.addons.EllesmereUIRaidFrames
    if type(raidFrames) ~= "table" then return false end

    raidFrames.extraFrames = raidFrames.extraFrames or {}
    local extra = raidFrames.extraFrames
    local changed = false
    if extra.position ~= "free" then extra.position = "free"; changed = true end
    if extra.growDirection ~= "UP" then extra.growDirection = "UP"; changed = true end
    if extra.wrapDirection ~= "RIGHT" then extra.wrapDirection = "RIGHT"; changed = true end
    if extra.freeHorizontal ~= false then extra.freeHorizontal = false; changed = true end
    return changed
end

local DAMAGE_METER_ELEM_KEYS = {
    EDM_Win1 = true,
    EDM_Win2 = true,
    EDM_Win3 = true,
}

local function ClearDamageMeterElementPositions(layer)
    if type(layer) ~= "table" or type(layer.elems) ~= "table" then return false end

    local changed = false
    for key in pairs(DAMAGE_METER_ELEM_KEYS) do
        if layer.elems[key] ~= nil then
            layer.elems[key] = nil
            changed = true
        end
    end
    return changed
end

local function PatchUnlockLayerLayout(layer, preset, offsetX)
    if type(layer) ~= "table" then return false end
    local changed = PatchDamageMeterAnchor(layer.anchors, preset, offsetX)
    changed = PatchDragonRidingLayer(layer) or changed
    changed = ClearDamageMeterElementPositions(layer) or changed
    return changed
end

local function PatchUnlockOverrideStore(store, preset, offsetX)
    if type(store) ~= "table" then return false end

    local changed = PatchUnlockLayerLayout(store.baselineLayout, preset, offsetX)
    if type(store.layouts) == "table" then
        for _, layer in pairs(store.layouts) do
            changed = PatchUnlockLayerLayout(layer, preset, offsetX) or changed
        end
    end
    return changed
end

local function PatchUnlockLayerRaidFrameOffset(layer, deltaX)
    if type(layer) ~= "table" then return false end
    return PatchRaidFrameAnchorOffset(layer.anchors, deltaX)
end

local function PatchUnlockOverrideStoreRaidFrameOffset(store, deltaX)
    if type(store) ~= "table" then return false end

    local changed = PatchUnlockLayerRaidFrameOffset(store.baselineLayout, deltaX)
    if type(store.layouts) == "table" then
        for _, layer in pairs(store.layouts) do
            changed = PatchUnlockLayerRaidFrameOffset(layer, deltaX) or changed
        end
    end
    return changed
end

local function PatchProfileRaidFrameOffset(profile, deltaX)
    if type(profile) ~= "table" then return false end

    local changed = PatchRaidFrameAnchorOffset(profile.unlockLayout and profile.unlockLayout.anchors, deltaX)
    changed = PatchUnlockOverrideStoreRaidFrameOffset(profile.specUnlockOverrides, deltaX) or changed
    changed = PatchUnlockOverrideStoreRaidFrameOffset(profile.condUnlockOverrides, deltaX) or changed
    return changed
end

local function PatchProfileLayout(profile, preset, offsetX)
    if type(profile) ~= "table" then return false end
    local changed = PatchMinimapPosition(profile)
    changed = PatchQueueStatusPosition(profile, preset) or changed
    changed = PatchDamageMeterWindowSizes(profile, preset) or changed
    changed = PatchDragonRidingProfile(profile) or changed
    changed = PatchDamageMeterAnchor(profile.unlockLayout and profile.unlockLayout.anchors, preset, offsetX) or changed
    changed = PatchUnlockOverrideStore(profile.specUnlockOverrides, preset, offsetX) or changed
    changed = PatchUnlockOverrideStore(profile.condUnlockOverrides, preset, offsetX) or changed
    return changed
end

local function ResolveUnlockFrame(key)
    local EUI = _G.EllesmereUI
    local registry = EUI and EUI._unlockRegisteredElements
    local elem = registry and registry[key]
    if not elem then return nil end
    if type(elem.getFrame) == "function" then
        local ok, frame = pcall(elem.getFrame, key)
        if ok then return frame end
    end
    return elem.frame
end

local function ResolveDBMHugeBarTargetFrame()
    return ResolveUnlockFrame("target")
        or _G.EllesmereUIUnitFrames_Target
        or _G.TargetFrame
end

local SnapLayoutCoord

local function GetFrameRectInUIParent(frame)
    if not (frame and UIParent and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetEffectiveScale) then
        return nil
    end
    local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    if not (left and right and top) then return nil end

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale()
    return {
        left = left * frameScale / uiScale,
        right = right * frameScale / uiScale,
        top = top * frameScale / uiScale,
        width = (right - left) * frameScale / uiScale,
    }
end

local function GetDBMHugeIconWidth(options)
    if type(options) ~= "table" or options.IconLeft == false then return 0 end

    if options.IconLocked == false then
        return 20
    end

    return tonumber(options.HugeHeight) or 20
end

local function GetDBMHugeRightIconWidth(options)
    if type(options) ~= "table" or options.IconRight ~= true then return 0 end

    if options.IconLocked == false then
        return 20
    end

    return tonumber(options.HugeHeight) or 20
end

local function ComputeDBMHugeBarWidth(options, rect)
    local width = tonumber(rect and rect.width)
    if not width or width <= 0 then return nil end

    local hugeScale = tonumber(options and options.HugeScale) or 1
    if hugeScale <= 0 then hugeScale = 1 end

    local barWidth = ((width - DBM_HUGE_VISUAL_WIDTH_INSET) / hugeScale)
        - GetDBMHugeIconWidth(options)
        - GetDBMHugeRightIconWidth(options)
    return SnapLayoutCoord(math.max(1, barWidth))
end

local function ComputeDBMHugeBarCenterOffset(options)
    local hugeScale = tonumber(options and options.HugeScale) or 1
    if hugeScale <= 0 then hugeScale = 1 end

    return ((GetDBMHugeIconWidth(options) - GetDBMHugeRightIconWidth(options)) * hugeScale) / 2
end

SnapLayoutCoord = function(value)
    local EUI = _G.EllesmereUI
    if EUI and EUI.PP and type(EUI.PP.Scale) == "function" then
        local ok, snapped = pcall(EUI.PP.Scale, value)
        if ok and snapped then return snapped end
    end
    if EUI and EUI.PP and type(EUI.PP.Snap) == "function" then
        local ok, snapped = pcall(EUI.PP.Snap, value)
        if ok and snapped then return snapped end
    end
    return math.floor((tonumber(value) or 0) + 0.5)
end

function addonTable.ApplyOakDBMHugeBarsToTarget(profileName)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not UIParent then return false end

    local target = ResolveDBMHugeBarTargetFrame()
    local rect = GetFrameRectInUIParent(target)
    if not rect then return false end

    local dbtProfileName = profileName or _G.DBM_UsedProfile or "Default"
    local options = type(_G.DBT_AllPersistentOptions) == "table" and _G.DBT_AllPersistentOptions[dbtProfileName]
    local DBT = _G.DBT
    if type(options) ~= "table" and DBT and type(DBT.Options) == "table" then
        options = DBT.Options
        dbtProfileName = _G.DBM_UsedProfile or dbtProfileName
    end
    if type(options) ~= "table" then return false end

    local uiWidth = UIParent:GetWidth() or BASE_WIDTH
    local auraClearance = addonTable.ScaleOakLayoutLength and addonTable.ScaleOakLayoutLength(DBM_HUGE_TARGET_AURA_CLEARANCE) or DBM_HUGE_TARGET_AURA_CLEARANCE
    local gap = ComputeDBMHugeBarGap(addonTable.GetOakLayoutPreset())
    local width = ComputeDBMHugeBarWidth(options, rect)
    local x = SnapLayoutCoord(((rect.left + rect.right) / 2) - (uiWidth / 2) + ComputeDBMHugeBarCenterOffset(options) + DBM_HUGE_VISUAL_X_NUDGE)
    local y = SnapLayoutCoord(rect.top + auraClearance + gap)
    local changed = options.HugeTimerPoint ~= "BOTTOM"
        or math.abs((tonumber(options.HugeTimerX) or 0) - x) > 0.5
        or math.abs((tonumber(options.HugeTimerY) or 0) - y) > 0.5
        or (width and math.abs((tonumber(options.HugeWidth) or 0) - width) > 0.5)
        or options.ExpandUpwardsLarge ~= true

    options.HugeTimerPoint = "BOTTOM"
    options.HugeTimerX = x
    options.HugeTimerY = y
    if width then
        options.HugeWidth = width
    end
    options.ExpandUpwardsLarge = true

    if DBT and type(DBT.Options) == "table" and (_G.DBM_UsedProfile == dbtProfileName or not _G.DBM_UsedProfile) then
        DBT.Options.HugeTimerPoint = options.HugeTimerPoint
        DBT.Options.HugeTimerX = options.HugeTimerX
        DBT.Options.HugeTimerY = options.HugeTimerY
        if width then
            DBT.Options.HugeWidth = width
        end
        DBT.Options.ExpandUpwardsLarge = options.ExpandUpwardsLarge
        if type(DBT.Rearrange) == "function" then
            pcall(DBT.Rearrange, DBT)
        end
    elseif changed and DBT and type(DBT.ApplyProfile) == "function" and _G.DBM_UsedProfile == dbtProfileName then
        pcall(DBT.ApplyProfile, DBT, dbtProfileName, true)
    end
    return changed
end

local dbmHugeHooked = {}
local dbmHugeScheduled = {}

local function ScheduleDBMHugeBars(profileName, delay)
    local key = tostring(delay or 0)
    if dbmHugeScheduled[key] then return end
    dbmHugeScheduled[key] = true
    local function Apply()
        dbmHugeScheduled[key] = nil
        addonTable.ApplyOakDBMHugeBarsToTarget(profileName)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0, Apply)
    else
        Apply()
    end
end

local function HookDBMHugeEUIFunction(tbl, name)
    if dbmHugeHooked[name] or type(tbl) ~= "table" or type(tbl[name]) ~= "function" or type(hooksecurefunc) ~= "function" then
        return
    end
    hooksecurefunc(tbl, name, function()
        ScheduleDBMHugeBars(nil, 0.05)
    end)
    dbmHugeHooked[name] = true
end

local function EnsureDBMHugeHooks()
    local EUI = _G.EllesmereUI
    HookDBMHugeEUIFunction(EUI, "RefreshAllAddons")
    HookDBMHugeEUIFunction(EUI, "ReapplyAllUnlockAnchors")
    HookDBMHugeEUIFunction(EUI, "ReapplyAllUnlockAnchorsForced")
    if not dbmHugeHooked._EUF_ReloadFrames and type(_G._EUF_ReloadFrames) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc("_EUF_ReloadFrames", function()
            ScheduleDBMHugeBars(nil, 0.05)
        end)
        dbmHugeHooked._EUF_ReloadFrames = true
    end
end

function addonTable.ScheduleOakDBMHugeBarsToTarget(profileName)
    EnsureDBMHugeHooks()
    ScheduleDBMHugeBars(profileName, 0)
    ScheduleDBMHugeBars(profileName, 0.25)
    ScheduleDBMHugeBars(profileName, 1)
end

local function ComputeLiveDamageMeterOffset()
    if not UIParent then return nil end
    local child = ResolveUnlockFrame("EDM_Win1")
    local target = ResolveUnlockFrame("EDB_2")
    if not (child and target and child.GetLeft and target.GetLeft) then return nil end
    if not (child:GetLeft() and target:GetLeft()) then return nil end

    local uiScale = UIParent:GetEffectiveScale()
    local childScale = child:GetEffectiveScale()
    local targetScale = target:GetEffectiveScale()
    local targetLeft = (target:GetLeft() or 0) * targetScale / uiScale
    local targetRight = (target:GetRight() or 0) * targetScale / uiScale
    local targetCenterX = (targetLeft + targetRight) / 2
    local childWidth = (child:GetWidth() or 0) * childScale / uiScale
    local desiredCenterX = (UIParent:GetWidth() or 0) - EdgeMarginForPreset() - (childWidth / 2)
    return desiredCenterX - targetCenterX
end

local function RefreshEllesmereLayout()
    EnsureEllesmereMovementAlertProfile()
    if _G._EMM_ApplyMinimap then pcall(_G._EMM_ApplyMinimap) end
    if _G._ERF_RefreshAll then pcall(_G._ERF_RefreshAll) end
    local EUI = _G.EllesmereUI
    if _G._EAB_Apply then pcall(_G._EAB_Apply) end
    if _G._EDM_Apply then pcall(_G._EDM_Apply) end
    if _G._EDR_Rebuild then pcall(_G._EDR_Rebuild) end
    if EUI and type(EUI.SpecOverrides_ApplyUnlock) == "function" then
        pcall(EUI.SpecOverrides_ApplyUnlock, nil, true)
    end
    if EUI and type(EUI.ApplyAllWidthHeightMatches) == "function" then
        pcall(EUI.ApplyAllWidthHeightMatches)
    end
    if EUI and EUI.ReapplyOwnAnchor then
        pcall(EUI.ReapplyOwnAnchor, "EDM_Win1")
        pcall(EUI.ReapplyOwnAnchor, DRAGON_RIDING_KEY)
        pcall(EUI.ReapplyOwnAnchor, RAID_FRAME_KEY)
    elseif EUI and EUI.ReapplyAllUnlockAnchors then
        pcall(EUI.ReapplyAllUnlockAnchors)
    end
end

local function RefreshEllesmereRaidFramesOnly()
    EnsureEllesmereMovementAlertProfile()
    if _G._ERF_RefreshAll then pcall(_G._ERF_RefreshAll) end
end

local function ApplyInstallExtraFramesPosition(profileName, role)
    EnsureEllesmereMovementAlertProfile()
    profileName = profileName or GetActiveEllesmereProfileName()
    if not IsTankDPSProfile(profileName, role) then return false end
    if not IsActiveEllesmereProfile(profileName) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local raidFrame = ResolveUnlockFrame(RAID_FRAME_KEY)
    if not (raidFrame and raidFrame.GetRight and raidFrame.GetBottom) then return false end
    local raidRight = raidFrame:GetRight()
    local raidBottom = raidFrame:GetBottom()
    if not (raidRight and raidBottom and UIParent and UIParent.GetCenter) then return false end

    local profiles = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.profiles
    local activeProfile = profileName and profiles and profiles[profileName]
    local raidFrames = activeProfile
        and activeProfile.addons
        and activeProfile.addons.EllesmereUIRaidFrames
    if type(raidFrames) ~= "table" then return false end

    local extra = raidFrames.extraFrames
    if type(extra) ~= "table" then return false end
    local uiCenterX, uiCenterY = UIParent:GetCenter()
    if not (uiCenterX and uiCenterY) then return false end

    local uiScale = UIParent:GetEffectiveScale()
    local raidScale = raidFrame:GetEffectiveScale()
    local left = (raidRight * raidScale / uiScale) + EXTRA_FRAMES_GAP - uiCenterX
    local bottom = (raidBottom * raidScale / uiScale) - uiCenterY
    local extraFrame = _G[EXTRA_FRAMES_CONTAINER_NAME]
    local previousRect = type(extra.freeRect) == "table" and extra.freeRect or nil
    local width = extraFrame and extraFrame.GetWidth and extraFrame:GetWidth() or nil
    local height = extraFrame and extraFrame.GetHeight and extraFrame:GetHeight() or nil
    if not width or width <= 0 then
        width = previousRect and previousRect.right and previousRect.left and (previousRect.right - previousRect.left) or 0
    end
    if not height or height <= 0 then
        height = previousRect and previousRect.top and previousRect.bottom and (previousRect.top - previousRect.bottom) or 0
    end

    extra.position = "free"
    extra.growDirection = "UP"
    extra.wrapDirection = "RIGHT"
    extra.freeHorizontal = false
    extra.freePos = {
        x = left + (width / 2),
        y = bottom + (height / 2),
    }
    extra.freeRect = {
        left = left,
        right = left + width,
        bottom = bottom,
        top = bottom + height,
    }

    if extraFrame and extraFrame.ClearAllPoints and extraFrame.SetPoint then
        extraFrame:ClearAllPoints()
        extraFrame:SetPoint("BOTTOMLEFT", UIParent, "CENTER", left, bottom)
    end
    return true
end

local function ScheduleInstallExtraFramesPosition(profileName, role)
    ApplyInstallExtraFramesPosition(profileName, role)
    if not (C_Timer and C_Timer.After) then
        return
    end
    C_Timer.After(0, function() ApplyInstallExtraFramesPosition(profileName, role) end)
    C_Timer.After(0.25, function() ApplyInstallExtraFramesPosition(profileName, role) end)
    C_Timer.After(1, function() ApplyInstallExtraFramesPosition(profileName, role) end)
end

local function ApplyLiveDamageMeterOffset(db, profileName, preset)
    local offsetX = ComputeLiveDamageMeterOffset()
    if not offsetX then return false end

    if type(db) == "table" then
        PatchDamageMeterAnchor(db.unlockAnchors, preset, offsetX)
        PatchDamageMeterAnchor(db.unlockLayout and db.unlockLayout.anchors, preset, offsetX)
        if profileName and db.profiles and db.profiles[profileName] then
            PatchProfileLayout(db.profiles[profileName], preset, offsetX)
        end
        local activeName = db.activeProfile or db.profile
        if activeName and db.profiles and db.profiles[activeName] then
            PatchProfileLayout(db.profiles[activeName], preset, offsetX)
        end
    end
    RefreshEllesmereLayout()
    return true
end

local function ComputeLiveRaidFrameOffsetDelta(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    if not (preset and RAID_FRAME_CLAMP_PRESETS[preset.key]) then return nil end
    if not UIParent then return nil end

    local frame = ResolveUnlockFrame(RAID_FRAME_KEY)
    if not (frame and frame.GetLeft and frame.GetRight) then return nil end
    if not (frame:GetLeft() and frame:GetRight()) then return nil end

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale()
    local left = (frame:GetLeft() or 0) * frameScale / uiScale
    local right = (frame:GetRight() or 0) * frameScale / uiScale
    local uiWidth = UIParent:GetWidth() or 0
    local margin = EdgeMarginForPreset(preset)

    if left < margin then
        return margin - left
    elseif right > uiWidth - margin then
        return (uiWidth - margin) - right
    end
end

local function ApplyLiveRaidFrameClamp(db, profileName, preset)
    local deltaX = ComputeLiveRaidFrameOffsetDelta(preset)
    if not deltaX or math.abs(deltaX) < 0.5 then return false end

    local changed = false
    if type(db) == "table" then
        changed = PatchRaidFrameAnchorOffset(db.unlockAnchors, deltaX) or changed
        changed = PatchRaidFrameAnchorOffset(db.unlockLayout and db.unlockLayout.anchors, deltaX) or changed
        local activeName = db.activeProfile or db.profile
        if activeName and db.profiles and db.profiles[activeName] then
            changed = PatchProfileRaidFrameOffset(db.profiles[activeName], deltaX) or changed
        elseif profileName and db.profiles and db.profiles[profileName] then
            changed = PatchProfileRaidFrameOffset(db.profiles[profileName], deltaX) or changed
        end
    end
    if changed then RefreshEllesmereLayout() end
    return changed
end

local function ApplyLiveLayoutCorrections(db, profileName, preset, role)
    if not IsActiveEllesmereProfile(profileName) then return false end
    local changed = ApplyLiveDamageMeterOffset(db, profileName, preset)
    changed = ApplyLiveRaidFrameClamp(db, profileName, preset) or changed
    return changed
end

local function ScheduleLiveDamageMeterOffset(db, profileName, preset, role)
    ApplyLiveLayoutCorrections(db, profileName, preset, role)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(0.25, function() ApplyLiveLayoutCorrections(db, profileName, preset, role) end)
    C_Timer.After(1.25, function() ApplyLiveLayoutCorrections(db, profileName, preset, role) end)
end

local function NumberPattern()
    return "%-?%d+%.?%d*"
end

local function PatternInt(value)
    value = tonumber(value) or 0
    if value < 0 then return "%-" .. tostring(math.abs(value)) end
    return tostring(value)
end

local function FormatCoord(value)
    return string.format("%.1f", tonumber(value) or 0)
end

local function ReplaceEditModeRecord(layoutString, systemID, systemIndex, point, relPoint, relativeTo, x, y)
    if type(layoutString) ~= "string" or layoutString == "" then return layoutString end
    local prefix = " "
    local num = NumberPattern()
    local pattern = "(%s)" .. tostring(systemID) .. "%s+" .. PatternInt(systemIndex)
        .. "%s+([%-]?%d+)%s+[%-]?%d+%s+[%-]?%d+%s+%S+%s+" .. num .. "%s+" .. num
    local replacement = function(space, enabled)
        return table.concat({
            space,
            tostring(systemID),
            tostring(systemIndex),
            tostring(enabled),
            tostring(point),
            tostring(relPoint),
            tostring(relativeTo),
            FormatCoord(x),
            FormatCoord(y),
        }, " ")
    end
    local adjusted = (prefix .. layoutString):gsub(pattern, replacement, 1)
    return adjusted:sub(2)
end

function addonTable.ApplyOakEditModeLayoutAdjustmentsString(layoutString)
    local preset = addonTable.GetOakLayoutPreset()
    local margin = EdgeMarginForPreset(preset)
    local objectiveX, objectiveY = ComputeObjectiveTrackerTopRightOffset(preset)
    layoutString = ReplaceEditModeRecord(layoutString, 6, 0, 0, 0, "UIParent", margin, -margin)
    layoutString = ReplaceEditModeRecord(layoutString, 6, 1, 0, 6, "BuffFrame", 0, -4)
    layoutString = ReplaceEditModeRecord(layoutString, 12, -1, 2, 2, "UIParent", objectiveX, objectiveY)
    return layoutString
end

local function GetObjectiveTrackerHeightSetting()
    local enum = Enum and Enum.EditModeObjectiveTrackerSetting
    if type(enum) ~= "table" then return nil end
    return enum.Height or enum.FrameHeight or enum.TrackerHeight or enum.MaxHeight or enum.MaximumHeight
end

local function UpsertEditModeSetting(settings, settingID, value)
    if not settingID or type(settings) ~= "table" then return false end
    for _, settingInfo in ipairs(settings) do
        if settingInfo.setting == settingID then
            if settingInfo.value ~= value then
                settingInfo.value = value
                return true
            end
            return false
        end
    end
    settings[#settings + 1] = { setting = settingID, value = value }
    return true
end

local function CapLargestNumericSetting(settings, maxValue)
    if type(settings) ~= "table" then return false end
    local target
    local targetValue = -math.huge
    for _, settingInfo in ipairs(settings) do
        local value = tonumber(settingInfo and settingInfo.value)
        if value and value >= OBJECTIVE_TRACKER_MIN_HEIGHT and value > targetValue then
            target = settingInfo
            targetValue = value
        end
    end
    if target and targetValue > maxValue then
        target.value = maxValue
        return true
    end
    return false
end

function addonTable.ApplyOakEditModeLayoutAdjustmentsInfo(layoutInfo)
    if type(layoutInfo) ~= "table" or type(layoutInfo.systems) ~= "table" then return false end

    local preset = addonTable.GetOakLayoutPreset()
    local maxHeight = ComputeObjectiveTrackerMaxHeight(preset)
    local objectiveSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ObjectiveTracker or 12
    local heightSetting = GetObjectiveTrackerHeightSetting()
    local changed = false

    for _, sysInfo in ipairs(layoutInfo.systems) do
        if sysInfo.system == objectiveSystem and sysInfo.systemIndex == -1 then
            sysInfo.settings = sysInfo.settings or {}
            changed = UpsertEditModeSetting(sysInfo.settings, heightSetting, maxHeight) or changed
            changed = CapLargestNumericSetting(sysInfo.settings, maxHeight) or changed
            break
        end
    end

    return changed
end

function addonTable.ApplyOakEllesmereUIScale(db)
    if type(db) ~= "table" then return end
    local preset = addonTable.GetOakLayoutPreset()
    if type(preset) ~= "table" then return end

    db.ppUIScale = preset.scale
    db.ppUIScaleAuto = false
    if UIParent and type(UIParent.SetScale) == "function" and not (InCombatLockdown and InCombatLockdown()) then
        pcall(UIParent.SetScale, UIParent, preset.scale)
    end
    if _G.EllesmereUI and _G.EllesmereUI.PP and type(_G.EllesmereUI.PP.UpdateMult) == "function" then
        pcall(_G.EllesmereUI.PP.UpdateMult)
    end
end

function addonTable.ApplyOakScopedEllesmereLayoutTransform(db, profile, options)
    options = options or {}
    if options.all or options.scale then
        addonTable.ApplyOakEllesmereUIScale(db)
    end
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active or type(profile) ~= "table" then return end

    if options.all or options.minimap then
        TransformMinimap(profile)
    end
end

function addonTable.ApplyOakEllesmereLayoutAdjustments(db, profileName, role)
    local preset = addonTable.GetOakLayoutPreset()
    if type(db) ~= "table" then return false end
    if role == "dps" or role == "heals" then RememberProfileRole(profileName, role) end

    local offsetX = ComputeDamageMeterOffsetX(preset)
    local changed = false
    local extraChanged = false
    if profileName and db.profiles and db.profiles[profileName] then
        changed = PatchProfileLayout(db.profiles[profileName], preset, offsetX) or changed
        changed = ClearDragonRidingModuleUnlockPos(profileName) or changed
        if IsTankDPSProfile(profileName, role) then
            extraChanged = PatchTankDPSExtraFrames(db.profiles[profileName]) or extraChanged
        end
    end

    local activeName = db.activeProfile or db.profile
    if activeName and db.profiles and db.profiles[activeName] then
        changed = PatchProfileLayout(db.profiles[activeName], preset, offsetX) or changed
        changed = ClearDragonRidingModuleUnlockPos(activeName) or changed
        if IsTankDPSProfile(activeName, GetProfileRole(activeName)) then
            extraChanged = PatchTankDPSExtraFrames(db.profiles[activeName]) or extraChanged
        end
    end

    changed = PatchDamageMeterAnchor(db.unlockAnchors, preset, offsetX) or changed
    changed = PatchDamageMeterAnchor(db.unlockLayout and db.unlockLayout.anchors, preset, offsetX) or changed
    db.unlockAnchors = db.unlockAnchors or {}
    db.unlockWidthMatch = db.unlockWidthMatch or {}
    changed = PatchDragonRidingAnchor(db.unlockAnchors) or changed
    changed = PatchDragonRidingWidthMatch(db.unlockWidthMatch) or changed
    changed = PatchDragonRidingLayer(db.unlockLayout) or changed

    if changed then
        RefreshEllesmereLayout()
        ScheduleLiveDamageMeterOffset(db, profileName, preset, role)
    elseif extraChanged then
        RefreshEllesmereRaidFramesOnly()
    end
    if IsTankDPSProfile(profileName, role) then ScheduleInstallExtraFramesPosition(profileName, role) end
    return changed or extraChanged
end

function addonTable.TransformOakLayoutOffset(x, y)
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active then return x, y end
    return (tonumber(x) or 0) * factors.x, (tonumber(y) or 0) * factors.y
end
