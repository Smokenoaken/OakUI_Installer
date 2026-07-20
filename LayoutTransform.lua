local addonName, addonTable = ...

local BASE_WIDTH = 2560
local BASE_HEIGHT = 1440
local BASE_UI_SCALE = 0.64

local PRESETS = {
    { key = "native", label = "OakUI Native", desc = "2560x1440 at 0.64.", width = 2560, height = 1440, scale = 0.64 },
    { key = "1080p", label = "1080p", desc = "1920x1080 at 0.711.", width = 1920, height = 1080, scale = 0.711 },
    { key = "1440p_pp", label = "1440p Pixel Perfect", desc = "2560x1440 at 0.533.", width = 2560, height = 1440, scale = 0.533 },
    { key = "4k", label = "4K", desc = "3840x2160 at 0.356.", width = 3840, height = 2160, scale = 0.356 },
    { key = "uw_oak", label = "Ultrawide 0.64", desc = "5120x1440 at 0.64.", width = 5120, height = 1440, scale = 0.64 },
    { key = "uw_pp", label = "Ultrawide 0.533", desc = "5120x1440 at 0.533.", width = 5120, height = 1440, scale = 0.533 },
}

local PRESET_BY_KEY = {}
for _, preset in ipairs(PRESETS) do
    PRESET_BY_KEY[preset.key] = preset
end

local activePresetKey = "native"
local BASE_DAMAGE_METER_1_OFFSET_X = 939.1666666666666
local EDGE_MARGIN = 10
local EDGE_MARGIN_BY_PRESET = {
    ["1080p"] = 0,
}
local RAID_FRAME_KEY = "RF_RaidFrames"
local RAID_FRAME_CLAMP_PRESETS = {
    ["1080p"] = true,
}
local EXTRA_FRAMES_CONTAINER_NAME = "ERFExtraFramesContainer"
local EXTRA_FRAMES_GAP = 5

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

local function GetPreset(key)
    return PRESET_BY_KEY[key or activePresetKey] or PRESET_BY_KEY.native
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

local function IsNativePreset(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    return not preset or preset.key == "native"
end

local function UiCoordWidth(preset)
    local width = tonumber(preset and preset.width) or BASE_WIDTH
    local scale = tonumber(preset and preset.scale) or BASE_UI_SCALE
    if scale <= 0 then scale = BASE_UI_SCALE end
    return width / scale
end

local function ComputeDamageMeterOffsetX(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    return BASE_DAMAGE_METER_1_OFFSET_X + ((UiCoordWidth(preset) - (BASE_WIDTH / BASE_UI_SCALE)) / 2)
end

local function EdgeMarginForPreset(preset)
    preset = preset or addonTable.GetOakLayoutPreset()
    local presetMargin = preset and EDGE_MARGIN_BY_PRESET[preset.key]
    if presetMargin ~= nil then return presetMargin end
    return EDGE_MARGIN
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

local function PatchProfileLayout(profile, preset, offsetX, role)
    if type(profile) ~= "table" then return false end
    local changed = PatchMinimapPosition(profile)
    changed = PatchDamageMeterAnchor(profile.unlockLayout and profile.unlockLayout.anchors, preset, offsetX) or changed
    changed = PatchUnlockOverrideStore(profile.specUnlockOverrides, preset, offsetX) or changed
    changed = PatchUnlockOverrideStore(profile.condUnlockOverrides, preset, offsetX) or changed
    if role == "dps" then
        changed = PatchTankDPSExtraFrames(profile) or changed
    end
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
    if _G._EMM_ApplyMinimap then pcall(_G._EMM_ApplyMinimap) end
    if _G._ERF_RefreshAll then pcall(_G._ERF_RefreshAll) end
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.SpecOverrides_ApplyUnlock) == "function" then
        pcall(EUI.SpecOverrides_ApplyUnlock, nil, true)
    end
    if EUI and EUI.ReapplyOwnAnchor then
        pcall(EUI.ReapplyOwnAnchor, "EDM_Win1")
        pcall(EUI.ReapplyOwnAnchor, RAID_FRAME_KEY)
    elseif EUI and EUI.ReapplyAllUnlockAnchors then
        pcall(EUI.ReapplyAllUnlockAnchors)
    end
end

local function ApplyInstallExtraFramesPosition(profileName, role)
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
            PatchProfileLayout(db.profiles[profileName], preset, offsetX, GetProfileRole(profileName))
        end
        local activeName = db.activeProfile or db.profile
        if activeName and db.profiles and db.profiles[activeName] then
            PatchProfileLayout(db.profiles[activeName], preset, offsetX, GetProfileRole(activeName))
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
    if IsNativePreset(preset) then return layoutString end

    local margin = EdgeMarginForPreset(preset)
    local minimapSize = 253
    local questY = -(margin + minimapSize + 28)
    layoutString = ReplaceEditModeRecord(layoutString, 6, 0, 0, 0, "UIParent", margin, -margin)
    layoutString = ReplaceEditModeRecord(layoutString, 6, 1, 0, 6, "BuffFrame", 0, -4)
    layoutString = ReplaceEditModeRecord(layoutString, 12, -1, 2, 2, "UIParent", -margin, questY)
    return layoutString
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

    if IsNativePreset(preset) then
        local changed = false
        if IsTankDPSProfile(profileName, role) and profileName and db.profiles and db.profiles[profileName] then
            changed = PatchTankDPSExtraFrames(db.profiles[profileName]) or changed
        end
        if changed then RefreshEllesmereLayout() end
        if IsTankDPSProfile(profileName, role) then ScheduleInstallExtraFramesPosition(profileName, role) end
        return changed
    end

    local offsetX = ComputeDamageMeterOffsetX(preset)
    local changed = false
    if profileName and db.profiles and db.profiles[profileName] then
        changed = PatchProfileLayout(db.profiles[profileName], preset, offsetX, role) or changed
    end

    local activeName = db.activeProfile or db.profile
    if activeName and db.profiles and db.profiles[activeName] then
        changed = PatchProfileLayout(db.profiles[activeName], preset, offsetX, GetProfileRole(activeName)) or changed
    end

    changed = PatchDamageMeterAnchor(db.unlockAnchors, preset, offsetX) or changed
    changed = PatchDamageMeterAnchor(db.unlockLayout and db.unlockLayout.anchors, preset, offsetX) or changed

    if changed then
        RefreshEllesmereLayout()
        ScheduleLiveDamageMeterOffset(db, profileName, preset, role)
    end
    if IsTankDPSProfile(profileName, role) then ScheduleInstallExtraFramesPosition(profileName, role) end
    return changed
end

function addonTable.TransformOakLayoutOffset(x, y)
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active then return x, y end
    return (tonumber(x) or 0) * factors.x, (tonumber(y) or 0) * factors.y
end
