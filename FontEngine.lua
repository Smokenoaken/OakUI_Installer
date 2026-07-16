local addonName, addonTable = ...

local FONT_PATH = "Interface\\AddOns\\OakUI_Installer\\Fonts\\"
local MEDIA_PATH = "Interface\\AddOns\\OakUI_Installer\\Media\\"
local BORDER_PATH = MEDIA_PATH .. "Borders\\"
local DEFAULT_FONT = "OakUI Font"
local DEFAULT_SIZE = 14
local DEFAULT_OUTLINE = "NONE"
local ROUND_THIN_BORDER_NAME = "OakUI Round Thin"
local ROUND_THIN_BORDER_PATH = BORDER_PATH .. "OakRoundThinBorder.png"
local ROUND_THIN_MASK_PATH = BORDER_PATH .. "OakRoundThinMask.png"
local ROUND_THIN_BORDER_WIDTH = 20
local ROUND_THIN_BORDER_HEIGHT = 20
local ROUND_THIN_BORDER_MARGIN = 0.48
local ROUND_THIN_BORDER_OUTSET = 1.5

local OAK_FONTS = {
    ["OakUI Font"] = MEDIA_PATH .. "OakFont.ttf",
    ["Basic OakUI Font"] = MEDIA_PATH .. "OakFont.ttf",
    ["OakUI Arial Narrow"] = FONT_PATH .. "ARIALN.ttf",
    ["Electrofied"] = FONT_PATH .. "electr.ttf",
    ["Electrofied Bold"] = FONT_PATH .. "electrb.ttf",
    ["Electrofied Bold Italic"] = FONT_PATH .. "electrbi.ttf",
    ["Electrofied Italic"] = FONT_PATH .. "electri.ttf",
    ["OakUI Friz Quadrata"] = FONT_PATH .. "FRIZQT__.ttf",
    ["OakUI Morpheus"] = FONT_PATH .. "MORPHEUS.ttf",
    ["OakUI Skurri"] = FONT_PATH .. "SKURRI.ttf",
}

local OAK_BORDERS = {
    [ROUND_THIN_BORDER_NAME] = ROUND_THIN_BORDER_PATH,
}

addonTable.OAK_ROUND_THIN_BORDER_NAME = ROUND_THIN_BORDER_NAME
addonTable.OAK_ROUND_THIN_BORDER_KEY = "sm:" .. ROUND_THIN_BORDER_NAME
addonTable.OAK_ROUND_THIN_BORDER_PATH = ROUND_THIN_BORDER_PATH
addonTable.OAK_ROUND_THIN_MASK_PATH = ROUND_THIN_MASK_PATH
addonTable.OAK_ROUND_THIN_BORDER_MARGINS = {
    left = ROUND_THIN_BORDER_WIDTH * ROUND_THIN_BORDER_MARGIN,
    right = ROUND_THIN_BORDER_WIDTH * ROUND_THIN_BORDER_MARGIN,
    top = ROUND_THIN_BORDER_HEIGHT * ROUND_THIN_BORDER_MARGIN,
    bottom = ROUND_THIN_BORDER_HEIGHT * ROUND_THIN_BORDER_MARGIN,
}

local SECTIONS = {
    { key = "combat", name = "Combat Font", size = 120, outline = "SHADOW", restart = true },
    { key = "name", name = "Name Font", size = 12, outline = "NONE", restart = true },
    { key = "nameplate", name = "Blizzard Nameplate", size = 9, outline = "OUTLINE", largeSize = 11, largeOutline = "OUTLINE" },
    { key = "cooldown", name = "Blizzard Cooldown", objects = { "SystemFont_Shadow_Large_Outline" }, size = 16, outline = "SHADOW" },
    { key = "worldzone", name = "World Zone Text", objects = { "ZoneTextFont", "WorldMapTextFont" }, size = 25, outline = "OUTLINE" },
    { key = "worldsubzone", name = "World Sub Zone Text", objects = { "SubZoneTextFont" }, size = 24, outline = "OUTLINE" },
    { key = "pvpzone", name = "PVP Zone Text", objects = { "PVPArenaTextString" }, size = 22, outline = "OUTLINE" },
    { key = "pvpsubzone", name = "PVP Sub Zone Text", objects = { "PVPInfoTextString" }, size = 22, outline = "OUTLINE" },
    { key = "objective", name = "Objective Text", objects = { "ObjectiveFont", "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont" }, size = 12, outline = "SHADOW", objectiveRange = true },
    { key = "errortext", name = "Quest Progress / Error Text", objects = { "ErrorFont" }, size = 16, outline = "SHADOW", resizeErrors = true },
    { key = "mailbody", name = "Mail Text", objects = { "MailTextFontNormal" }, size = 15, outline = "NONE" },
    { key = "questtitle", name = "Quest Title", objects = { "QuestTitleFont" }, size = 18, outline = "NONE" },
    { key = "questtext", name = "Quest Text", objects = { "QuestFont" }, size = 13, outline = "NONE" },
    { key = "questsmall", name = "Quest Small", objects = { "QuestFontNormalSmall" }, size = 12, outline = "NONE" },
    { key = "talkingtitle", name = "Talking Head Name", talkingObject = { "TalkingHeadFrame", "NameFrame", "Name" }, size = 22, outline = "OUTLINE" },
    { key = "talkingtext", name = "Talking Head Text", talkingObject = { "TalkingHeadFrame", "TextFrame", "Text" }, size = 16, outline = "SHADOW" },
}

addonTable.FontSections = SECTIONS
addonTable.OakFontFallbacks = OAK_FONTS

local function GetLSM()
    return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
end

local function IsOakRoundThinBorderKey(textureKey)
    if not textureKey or textureKey == "" then return false end
    return textureKey == ROUND_THIN_BORDER_NAME
        or textureKey == "sm:" .. ROUND_THIN_BORDER_NAME
        or textureKey == ROUND_THIN_BORDER_PATH
end
addonTable.IsOakRoundThinBorderKey = IsOakRoundThinBorderKey

local function RegisterOakRoundThinBorderRenderer()
    local E = _G.EllesmereUI
    if type(E) ~= "table" or E._oakRoundThinBorderRendererHooked then return end
    if type(E.ApplyBorderStyle) ~= "function" then return end

    local originalApplyBorderStyle = E.ApplyBorderStyle
    local originalSetBorderStyleColor = E.SetBorderStyleColor
    local margins = addonTable.OAK_ROUND_THIN_BORDER_MARGINS

    local function HideOakRoundThinBorder(borderFrame)
        local texture = borderFrame and borderFrame._oakRoundThinBorderTexture
        if texture then texture:Hide() end
        local entries = borderFrame and borderFrame._oakRoundThinMaskEntries
        if entries then
            for _, entry in ipairs(entries) do
                local mask = entry.mask
                for target in pairs(entry.targets or {}) do
                    if target and target.RemoveMaskTexture and mask then
                        pcall(target.RemoveMaskTexture, target, mask)
                    end
                end
                if mask then mask:Hide() end
            end
        end
        if borderFrame then borderFrame._oakRoundThinMaskEntries = nil end
    end

    local function HideEllesmereBorderSystems(borderFrame)
        local PP = E.PP
        if PP and type(PP.GetBorders) == "function" and PP.GetBorders(borderFrame) then
            if type(PP.HideBorder) == "function" then PP.HideBorder(borderFrame) end
            local ppContainer = PP.GetBorders(borderFrame)
            if ppContainer then
                if ppContainer._top then ppContainer._top:SetAlpha(0) end
                if ppContainer._bottom then ppContainer._bottom:SetAlpha(0) end
                if ppContainer._left then ppContainer._left:SetAlpha(0) end
                if ppContainer._right then ppContainer._right:SetAlpha(0) end
            end
        end

        local bdFrame = E._bdBorderData and E._bdBorderData[borderFrame]
        if bdFrame then bdFrame:Hide() end
    end

    local function GetOffset(value, fallback)
        if value == nil then return fallback end
        return value
    end

    local function GetWidgetMethod(widget, methodName)
        local ok, method = pcall(function()
            return widget and widget[methodName]
        end)
        if ok and type(method) == "function" then
            return method
        end
        return nil
    end

    local function CallWidgetMethodSafe(widget, methodName, ...)
        local method = GetWidgetMethod(widget, methodName)
        if not method then return false, nil end
        local ok, result = pcall(method, widget, ...)
        if ok then return true, result end
        return false, nil
    end

    local function IsWidgetForbidden(widget)
        local ok, forbidden = CallWidgetMethodSafe(widget, "IsForbidden")
        return ok and forbidden
    end

    local function GetWidgetObjectTypeResult(widget, objectType)
        local ok, isType = CallWidgetMethodSafe(widget, "IsObjectType", objectType)
        return ok, ok and isType
    end

    local function IsWidgetObjectType(widget, objectType)
        local _, isType = GetWidgetObjectTypeResult(widget, objectType)
        return isType
    end

    local function AddMaskTarget(targets, texture)
        if texture and GetWidgetMethod(texture, "AddMaskTexture") then
            targets[texture] = true
        end
    end

    local function AddMaskGroup(groups, maskParent, anchorFrame, targets)
        if not maskParent or not anchorFrame or not GetWidgetMethod(maskParent, "CreateMaskTexture") or not targets or not next(targets) then return end
        groups[#groups + 1] = {
            maskParent = maskParent,
            anchorFrame = anchorFrame,
            targets = targets,
        }
    end

    local function GetFrameChildrenSafe(frame)
        if not frame or IsWidgetForbidden(frame) then return nil end
        local method = GetWidgetMethod(frame, "GetChildren")
        if not method then return nil end
        local ok, children = pcall(function() return { method(frame) } end)
        if ok then return children end
        return nil
    end

    local function AddStatusBarMaskGroup(groups, bar, seenStatusBars, anchorOverride)
        if not bar or IsWidgetForbidden(bar) then return end
        local ok, statusBarTexture = CallWidgetMethodSafe(bar, "GetStatusBarTexture")
        if not ok then return end
        if seenStatusBars then
            if seenStatusBars[bar] then return end
            seenStatusBars[bar] = true
        end

        local targets = {}
        AddMaskTarget(targets, statusBarTexture)
        AddMaskTarget(targets, bar.bg)
        AddMaskTarget(targets, bar.BG)
        AddMaskTarget(targets, bar._bg)
        AddMaskGroup(groups, bar, anchorOverride or bar, targets)

        AddStatusBarMaskGroup(groups, bar._forward, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar._topBar, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.HealingAll, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.HealingPlayer, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.HealingOther, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.DamageAbsorb, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.HealAbsorb, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.TempLoss, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.mainBar, seenStatusBars, anchorOverride)
        AddStatusBarMaskGroup(groups, bar.altBar, seenStatusBars, anchorOverride)
    end

    local function AddStatusBarFillMaskGroup(groups, bar, seenStatusBars, anchorOverride)
        if not bar or IsWidgetForbidden(bar) then return end
        local ok, statusBarTexture = CallWidgetMethodSafe(bar, "GetStatusBarTexture")
        if not ok then return end
        if seenStatusBars then
            if seenStatusBars[bar] then return end
            seenStatusBars[bar] = true
        end

        local targets = {}
        AddMaskTarget(targets, statusBarTexture)
        AddMaskTarget(targets, bar.bg)
        AddMaskTarget(targets, bar.BG)
        AddMaskTarget(targets, bar._bg)
        AddMaskTarget(targets, bar._modernBase)
        AddMaskGroup(groups, bar, anchorOverride or bar, targets)
    end

    local function AddHealthPredictionMaskGroups(groups, prediction, seenStatusBars, anchorOverride)
        if type(prediction) ~= "table" then return end
        local absorb = prediction.damageAbsorb or prediction.DamageAbsorb
        local healAbsorb = prediction.healAbsorb or prediction.HealAbsorb

        AddStatusBarFillMaskGroup(groups, absorb, seenStatusBars, anchorOverride)
        if absorb then
            AddStatusBarFillMaskGroup(groups, absorb._forward, seenStatusBars, anchorOverride)
            AddStatusBarFillMaskGroup(groups, absorb._healAbsorb, seenStatusBars, anchorOverride)
        end
        AddStatusBarFillMaskGroup(groups, healAbsorb, seenStatusBars, anchorOverride)
    end

    local function AddChildStatusBarMaskGroups(groups, frame, seenStatusBars, depth, anchorOverride)
        if not frame or (depth or 0) <= 0 then return end
        local children = GetFrameChildrenSafe(frame)
        if not children then return end
        for _, child in ipairs(children) do
            local objectTypeOk, isStatusBar = GetWidgetObjectTypeResult(child, "StatusBar")
            if isStatusBar then
                AddStatusBarMaskGroup(groups, child, seenStatusBars, anchorOverride)
            end
            if objectTypeOk and child and not IsWidgetForbidden(child) then
                AddChildStatusBarMaskGroups(groups, child, seenStatusBars, depth - 1, anchorOverride)
            end
        end
    end

    local function CollectOakRoundThinMaskGroups(owner, borderFrame)
        local groups = {}
        if not owner then return groups end
        local seenStatusBars = {}

        local ownerTargets = {}
        -- These textures live directly on the owner frame, so they need a mask
        -- created on that same owner frame and anchored to the full border area.
        AddMaskTarget(ownerTargets, owner._bg)
        AddMaskTarget(ownerTargets, owner.bg)
        AddMaskTarget(ownerTargets, owner.BG)
        AddMaskTarget(ownerTargets, owner._powerBg)
        AddMaskTarget(ownerTargets, owner._topNameBarBg)
        AddMaskTarget(ownerTargets, owner.barBg)
        AddMaskTarget(ownerTargets, owner.barBgSolid)
        AddMaskTarget(ownerTargets, owner.icon)
        AddMaskTarget(ownerTargets, owner.iconBg)
        AddMaskGroup(groups, owner, borderFrame, ownerTargets)

        if IsWidgetObjectType(owner, "StatusBar") then
            AddStatusBarMaskGroup(groups, owner, seenStatusBars, borderFrame)
        end
        AddStatusBarMaskGroup(groups, owner._sb, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner.Health, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner.Power, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner.Castbar, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._health, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._power, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._absorbBar, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._healAbsorbBar, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._healPredBar, seenStatusBars, borderFrame)
        AddStatusBarMaskGroup(groups, owner._reducedMaxHealthBar, seenStatusBars, borderFrame)
        AddHealthPredictionMaskGroups(groups, owner.HealthPrediction, seenStatusBars, owner.Health or owner._health or borderFrame)
        AddChildStatusBarMaskGroups(groups, owner, seenStatusBars, 5, borderFrame)

        return groups
    end

    local function ApplyOakRoundThinMask(borderFrame)
        local owner = borderFrame and borderFrame:GetParent()
        if not owner then return end

        local previousEntries = borderFrame._oakRoundThinMaskEntries
        if previousEntries then
            for _, entry in ipairs(previousEntries) do
                for target in pairs(entry.targets or {}) do
                    if target and target.RemoveMaskTexture and entry.mask then
                        pcall(target.RemoveMaskTexture, target, entry.mask)
                    end
                end
            end
        end

        local groups = CollectOakRoundThinMaskGroups(owner, borderFrame)
        local masks = borderFrame._oakRoundThinMasksByParent
        if not masks then
            masks = {}
            borderFrame._oakRoundThinMasksByParent = masks
        end

        local entries = {}
        for _, group in ipairs(groups) do
            local mask = masks[group.maskParent]
            if not mask or mask:GetParent() ~= group.maskParent then
                if mask then mask:Hide() end
                mask = group.maskParent:CreateMaskTexture()
                masks[group.maskParent] = mask
            end

            mask:SetTexture(ROUND_THIN_MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            if mask.SetTextureSliceMargins then
                mask:SetTextureSliceMargins(margins.left, margins.top, margins.right, margins.bottom)
            end
            if mask.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
                mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
            mask:ClearAllPoints()
            mask:SetAllPoints(group.anchorFrame)
            mask:Show()

            entries[#entries + 1] = { mask = mask, targets = group.targets }
            for target in pairs(group.targets) do
                pcall(target.RemoveMaskTexture, target, mask)
                pcall(target.AddMaskTexture, target, mask)
            end
        end
        borderFrame._oakRoundThinMaskEntries = entries
    end

    local function RemoveOakRoundThinMaskOnly(anchorFrame)
        local entries = anchorFrame and anchorFrame._oakRoundThinMaskOnlyEntries
        if entries then
            for _, entry in ipairs(entries) do
                local mask = entry.mask
                for target in pairs(entry.targets or {}) do
                    if target and target.RemoveMaskTexture and mask then
                        pcall(target.RemoveMaskTexture, target, mask)
                    end
                end
            end
        end
        if anchorFrame and anchorFrame._oakRoundThinMaskOnly then
            anchorFrame._oakRoundThinMaskOnly:Hide()
        end
        if anchorFrame then anchorFrame._oakRoundThinMaskOnlyEntries = nil end
    end

    local function ApplyOakRoundThinMaskOnly(maskParent, targets, anchorFrame)
        if not maskParent or not maskParent.CreateMaskTexture then return false end
        anchorFrame = anchorFrame or maskParent

        local targetSet = {}
        if targets and targets.AddMaskTexture then
            targetSet[targets] = true
        elseif type(targets) == "table" then
            for _, target in ipairs(targets) do
                AddMaskTarget(targetSet, target)
            end
        end
        if not next(targetSet) then return false end

        RemoveOakRoundThinMaskOnly(maskParent)

        local mask = maskParent._oakRoundThinMaskOnly
        if not mask or mask:GetParent() ~= maskParent then
            if mask then mask:Hide() end
            mask = maskParent:CreateMaskTexture()
            maskParent._oakRoundThinMaskOnly = mask
        end

        mask:SetTexture(ROUND_THIN_MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if mask.SetTextureSliceMargins then
            mask:SetTextureSliceMargins(margins.left, margins.top, margins.right, margins.bottom)
        end
        if mask.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            mask:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
        mask:ClearAllPoints()
        mask:SetAllPoints(anchorFrame)
        mask:Show()

        for target in pairs(targetSet) do
            pcall(target.RemoveMaskTexture, target, mask)
            pcall(target.AddMaskTexture, target, mask)
        end
        maskParent._oakRoundThinMaskOnlyEntries = {
            { mask = mask, targets = targetSet },
        }
        return true
    end

    local function ApplyOakRoundThinBorder(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY)
        if not borderFrame or not size or size <= 0 then
            HideOakRoundThinBorder(borderFrame)
            if borderFrame then borderFrame:Hide() end
            return
        end

        HideEllesmereBorderSystems(borderFrame)

        local texture = borderFrame._oakRoundThinBorderTexture
        if not texture then
            texture = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            texture:SetTexture(ROUND_THIN_BORDER_PATH)
            if texture.SetTextureSliceMargins then
                texture:SetTextureSliceMargins(margins.left, margins.top, margins.right, margins.bottom)
            end
            if texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
                texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
            borderFrame._oakRoundThinBorderTexture = texture
        else
            texture:SetTexture(ROUND_THIN_BORDER_PATH)
        end

        local padX = ROUND_THIN_BORDER_OUTSET + GetOffset(offsetOverride, 0)
        local padY = ROUND_THIN_BORDER_OUTSET + GetOffset(offsetYOverride, 0)
        local sx = shiftX or 0
        local sy = shiftY or 0

        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", -padX + sx, padY + sy)
        texture:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", padX + sx, -padY + sy)
        texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
        texture:Show()
        borderFrame:Show()

        ApplyOakRoundThinMask(borderFrame)
        if _G.C_Timer and _G.C_Timer.After and not borderFrame._oakRoundThinMaskRefreshPending then
            borderFrame._oakRoundThinMaskRefreshPending = true
            _G.C_Timer.After(0, function()
                if borderFrame then
                    borderFrame._oakRoundThinMaskRefreshPending = nil
                end
                if borderFrame and borderFrame._oakRoundThinBorderTexture and borderFrame._oakRoundThinBorderTexture:IsShown() then
                    ApplyOakRoundThinMask(borderFrame)
                end
            end)
        end
    end

    addonTable.ApplyOakRoundThinBorderFrame = ApplyOakRoundThinBorder
    addonTable.HideOakRoundThinBorderFrame = HideOakRoundThinBorder
    addonTable.ApplyOakRoundThinMaskOnly = ApplyOakRoundThinMaskOnly
    addonTable.RemoveOakRoundThinMaskOnly = RemoveOakRoundThinMaskOnly

    function E.ApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey)
        if IsOakRoundThinBorderKey(textureKey) then
            return ApplyOakRoundThinBorder(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY)
        end

        HideOakRoundThinBorder(borderFrame)
        return originalApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey)
    end

    function E.SetBorderStyleColor(borderFrame, r, g, b, a)
        local texture = borderFrame and borderFrame._oakRoundThinBorderTexture
        if texture and texture:IsShown() then
            texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
            return
        end

        if originalSetBorderStyleColor then
            return originalSetBorderStyleColor(borderFrame, r, g, b, a)
        end
    end

    E._oakRoundThinBorderRendererHooked = true
end
addonTable.RegisterOakRoundThinBorderRenderer = RegisterOakRoundThinBorderRenderer

local function RegisterOakFonts()
    local LSM = GetLSM()
    if LSM then
        for name, path in pairs(OAK_FONTS) do
            LSM:Register("font", name, path)
        end
        for name, path in pairs(OAK_BORDERS) do
            LSM:Register("border", name, path)
            LSM:Register("nineslice", name, {
                file = path,
                previewWidth = ROUND_THIN_BORDER_WIDTH,
                previewHeight = ROUND_THIN_BORDER_HEIGHT,
                padding = { left = 0, right = 0, top = 0, bottom = 0 },
                margins = addonTable.OAK_ROUND_THIN_BORDER_MARGINS,
                scaleModifier = 1,
                mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched,
            })
            LSM:Register("ninesliceborder", name, {
                nineslice = name,
                mask = {
                    file = ROUND_THIN_MASK_PATH,
                    margins = addonTable.OAK_ROUND_THIN_BORDER_MARGINS,
                },
            })
        end
    end
    RegisterOakRoundThinBorderRenderer()
end
addonTable.RegisterOakFonts = RegisterOakFonts
addonTable.RegisterOakMedia = RegisterOakFonts

local function GetFontPath(fontName)
    local LSM = GetLSM()
    if LSM then
        local path = LSM:Fetch("font", fontName, true)
        if path then return path end
    end
    return OAK_FONTS[fontName] or OAK_FONTS[DEFAULT_FONT]
end

local function GetPreferredOakFontName()
    RegisterOakFonts()

    local LSM = GetLSM()
    if LSM and LSM:Fetch("font", "OakUI Font", true) then
        return "OakUI Font"
    end

    if OAK_FONTS["OakUI Font"] then
        return "OakUI Font"
    end

    return DEFAULT_FONT
end

function addonTable.GetFontChoices()
    RegisterOakFonts()

    local fonts = {}
    local LSM = GetLSM()
    local source = LSM and LSM:HashTable("font") or OAK_FONTS
    for name in pairs(source or OAK_FONTS) do
        fonts[#fonts + 1] = name
    end
    table.sort(fonts)
    return fonts
end

local function EnsureFontDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.fonts then OakUI_DB.fonts = {} end

    local db = OakUI_DB.fonts
    if type(db.global) ~= "table" then
        db.global = { font = DEFAULT_FONT, size = DEFAULT_SIZE, outline = DEFAULT_OUTLINE }
    end
    if type(db.sections) ~= "table" then
        db.sections = {}
    end

    db.global = db.global or { font = DEFAULT_FONT, size = DEFAULT_SIZE, outline = DEFAULT_OUTLINE }
    db.global.font = db.global.font or DEFAULT_FONT
    db.global.size = db.global.size or DEFAULT_SIZE
    db.global.outline = db.global.outline or DEFAULT_OUTLINE

    for _, section in ipairs(SECTIONS) do
        local current = db.sections[section.key]
        if not current then
            db.sections[section.key] = {
                enable = false,
                font = db.global.font or DEFAULT_FONT,
                size = section.size or DEFAULT_SIZE,
                outline = section.outline or DEFAULT_OUTLINE,
                largeFont = db.global.font or DEFAULT_FONT,
                largeSize = section.largeSize,
                largeOutline = section.largeOutline,
            }
        else
            if current.enable == nil then current.enable = false end
            current.font = current.font or db.global.font or DEFAULT_FONT
            current.size = current.size or section.size or DEFAULT_SIZE
            current.outline = current.outline or section.outline or DEFAULT_OUTLINE
            current.largeFont = current.largeFont or db.global.font or DEFAULT_FONT
            current.largeSize = current.largeSize or section.largeSize
            current.largeOutline = current.largeOutline or section.largeOutline
        end
    end

    return db
end

addonTable.EnsureFontDB = EnsureFontDB

local function NormalizeOutline(outline)
    if not outline or outline == "NONE" then return "" end
    if outline == "SHADOW" then return "" end
    return outline
end

local function SetFont(obj, font, size, outline)
    if not obj or not obj.SetFont then return end
    obj:SetFont(font, size, NormalizeOutline(outline))
    if outline == "SHADOW" then
        obj:SetShadowColor(0, 0, 0, 1)
        obj:SetShadowOffset(1, -1)
    elseif obj.SetShadowColor then
        obj:SetShadowColor(0, 0, 0, 0)
        obj:SetShadowOffset(0, 0)
    end
end

local function GetNestedObject(path)
    local obj = _G[path[1]]
    for i = 2, #path do
        obj = obj and obj[path[i]]
    end
    return obj
end

local function ApplyObjectList(objects, fontPath, size, outline)
    for _, objectName in ipairs(objects or {}) do
        SetFont(_G[objectName], fontPath, size, outline)
    end
end

local function ApplySection(section, settings, fallback)
    if not settings and not fallback then return end
    if settings and not settings.enable and not fallback then return end

    local active = (settings and settings.enable) and settings or fallback
    if not active then return end

    local fontPath = GetFontPath(active.font)

    if section.key == "combat" then
        if not (settings and settings.enable) then return end
        _G.DAMAGE_TEXT_FONT = fontPath
        SetFont(_G.CombatTextFont, fontPath, active.size or section.size, active.outline or section.outline)
        return
    end

    if section.key == "name" then
        if not (settings and settings.enable) then return end
        _G.UNIT_NAME_FONT = fontPath
        return
    end

    if section.key == "nameplate" then
        local largePath = GetFontPath(active.largeFont or active.font)
        ApplyObjectList({ "SystemFont_NamePlate", "SystemFont_NamePlateFixed", "SystemFont_NamePlateCastBar", "SystemFont_NamePlate_Outlined" }, fontPath, active.size or section.size, active.outline or section.outline)
        ApplyObjectList({ "SystemFont_LargeNamePlate", "SystemFont_LargeNamePlateFixed" }, largePath, active.largeSize or section.largeSize or active.size or section.size, active.largeOutline or section.largeOutline or active.outline or section.outline)
        return
    end

    ApplyObjectList(section.objects, fontPath, active.size or section.size, active.outline or section.outline)

    if section.objectiveRange then
        for i = 12, 22 do
            SetFont(_G["ObjectiveTrackerFont" .. i], fontPath, active.size or section.size, active.outline or section.outline)
        end
    end

    if section.talkingObject then
        SetFont(GetNestedObject(section.talkingObject), fontPath, active.size or section.size, active.outline or section.outline)
    end

    if section.resizeErrors and _G.UIErrorsFrame then
        local size = active.size or section.size
        local diff = (size - 16) / 16
        if diff > 0 then
            _G.UIErrorsFrame:SetSize(512 * (diff + 1), 60 * ((diff * 1.75) + 1))
        else
            _G.UIErrorsFrame:SetSize(512, 60)
        end
    end
end

function addonTable.ApplyOakFonts()
    RegisterOakFonts()
    local db = EnsureFontDB()
    local global = db.global or {}
    local globalPath = GetFontPath(global.font)

    if db.replaceBlizzardFonts then
        _G.STANDARD_TEXT_FONT = globalPath
        for _, obj in ipairs({ _G.GameFontNormal, _G.GameFontHighlight, _G.GameFontNormalSmall, _G.GameFontHighlightSmall, _G.GameFontNormalLarge, _G.GameFontHighlightLarge }) do
            SetFont(obj, globalPath, global.size or DEFAULT_SIZE, global.outline or DEFAULT_OUTLINE)
        end
    end

    for _, section in ipairs(SECTIONS) do
        local fallback
        if db.replaceBlizzardFonts and section.key ~= "combat" and section.key ~= "name" then
            fallback = {
                font = global.font,
                size = section.size or global.size or DEFAULT_SIZE,
                outline = section.outline or global.outline or DEFAULT_OUTLINE,
                largeFont = global.font,
                largeSize = section.largeSize,
                largeOutline = section.largeOutline,
            }
        end
        ApplySection(section, db.sections[section.key], fallback)
    end
end

function addonTable.ApplyFontToAll(fontName)
    local db = EnsureFontDB()
    db.global.font = fontName or db.global.font or DEFAULT_FONT
    db.replaceBlizzardFonts = true
    for _, section in ipairs(SECTIONS) do
        local settings = db.sections[section.key]
        settings.enable = true
        settings.font = db.global.font
        if section.key == "nameplate" then
            settings.largeFont = db.global.font
        end
    end
end

function addonTable.ApplyOakFontPreset()
    local fontName = GetPreferredOakFontName()
    addonTable.ApplyFontToAll(fontName)
    addonTable.ApplyOakFonts()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        RegisterOakFonts()
        EnsureFontDB()
        addonTable.ApplyOakFonts()
    elseif event == "PLAYER_LOGIN" then
        addonTable.ApplyOakFonts()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
