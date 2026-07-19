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

local function EnsureDB()
    if not OakUI_DB then OakUI_DB = {} end
    OakUI_DB.layoutTransform = OakUI_DB.layoutTransform or {}
    return OakUI_DB.layoutTransform
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

local function PatchProfileLayout(profile, preset, offsetX)
    if type(profile) ~= "table" then return false end
    local changed = PatchMinimapPosition(profile)
    changed = PatchDamageMeterAnchor(profile.unlockLayout and profile.unlockLayout.anchors, preset, offsetX) or changed
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
    local EUI = _G.EllesmereUI
    if EUI and EUI.ReapplyOwnAnchor then
        pcall(EUI.ReapplyOwnAnchor, "EDM_Win1")
    elseif EUI and EUI.ReapplyAllUnlockAnchors then
        pcall(EUI.ReapplyAllUnlockAnchors)
    end
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

local function ScheduleLiveDamageMeterOffset(db, profileName, preset)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(0.25, function() ApplyLiveDamageMeterOffset(db, profileName, preset) end)
    C_Timer.After(1.25, function() ApplyLiveDamageMeterOffset(db, profileName, preset) end)
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

function addonTable.ApplyOakEllesmereLayoutAdjustments(db, profileName)
    local preset = addonTable.GetOakLayoutPreset()
    if IsNativePreset(preset) or type(db) ~= "table" then return false end

    local offsetX = ComputeDamageMeterOffsetX(preset)
    local changed = false
    if profileName and db.profiles and db.profiles[profileName] then
        changed = PatchProfileLayout(db.profiles[profileName], preset, offsetX) or changed
    end

    local activeName = db.activeProfile or db.profile
    if activeName and db.profiles and db.profiles[activeName] then
        changed = PatchProfileLayout(db.profiles[activeName], preset, offsetX) or changed
    end

    changed = PatchDamageMeterAnchor(db.unlockAnchors, preset, offsetX) or changed
    changed = PatchDamageMeterAnchor(db.unlockLayout and db.unlockLayout.anchors, preset, offsetX) or changed

    if changed then
        RefreshEllesmereLayout()
        ScheduleLiveDamageMeterOffset(db, profileName, preset)
    end
    return changed
end

function addonTable.TransformOakLayoutOffset(x, y)
    local factors = addonTable.GetOakLayoutTransform()
    if not factors or not factors.active then return x, y end
    return (tonumber(x) or 0) * factors.x, (tonumber(y) or 0) * factors.y
end
