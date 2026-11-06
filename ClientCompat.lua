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

-- Keep the native visibility selection and legacy fields in agreement.
function addonTable.SetForeverActionBarVisibility(settings, hidden)
    local EUI = _G.EllesmereUI
    if EUI and type(EUI.SetVisibilitySelection) == "function" then
        EUI.SetVisibilitySelection(settings, "barVisibility", hidden and { mouseover = true } or { always = true })
    end
    settings.visibilityModes = nil
    settings.visibilityOverride = nil
    settings.barVisibility = hidden and "mouseover" or "always"
    settings.alwaysHidden = false
    settings.mouseoverEnabled = hidden == true
    settings.combatHideEnabled = false
    settings.combatShowEnabled = false
    settings.housingHideEnabled = false
    for key in pairs(settings) do
        if type(key) == "string" and (key:match("^visOnly") or key:match("^visHide")) then
            settings[key] = false
        end
    end
    local alpha = settings._savedBarAlpha or settings.mouseoverAlpha or 1
    if alpha <= 0 then alpha = 1 end
    settings._savedBarAlpha = hidden and alpha or nil
    settings.mouseoverAlpha = hidden and 0 or alpha
end

function addonTable.ClearForeverImportedGamepadHiding(addons)
    if type(addons) ~= "table" then return end
    local changed = false
    local actionBars = addons.EllesmereUIActionBars
    for _, settings in pairs(actionBars and actionBars.bars or {}) do
        if type(settings) == "table" and settings.gamepadHideBar == true then
            settings.gamepadHideBar = false
            changed = true
        end
    end
    local resourceBars = addons.EllesmereUIResourceBars
    if resourceBars and type(resourceBars.castBar) == "table" and resourceBars.castBar.gamepadHide == true then
        resourceBars.castBar.gamepadHide = false
        changed = true
    end
    local unitFrames = addons.EllesmereUIUnitFrames
    if unitFrames and type(unitFrames.player) == "table" and unitFrames.player.castbarGamepadHide == true then
        unitFrames.player.castbarGamepadHide = false
        changed = true
    end
    return changed
end

function addonTable.ApplyForeverImportDefaults(data)
    local addons = type(data) == "table" and data.addons
    if type(addons) ~= "table" then return end
    addonTable.ClearForeverImportedGamepadHiding(addons)
    local actionBars = addons.EllesmereUIActionBars
    if not actionBars then return end
    actionBars.mouseoverShowAll = false
    actionBars.bars = actionBars.bars or {}
    for i = 1, 10 do
        local key = i == 1 and "MainBar" or "Bar" .. i
        local settings = actionBars.bars[key] or {}
        actionBars.bars[key] = settings
        addonTable.SetForeverActionBarVisibility(settings, false)
        settings.enabled = i <= 5
        settings.alwaysHidden = i > 5
        settings.barVisibility = i <= 5 and "always" or "never"
    end
end
