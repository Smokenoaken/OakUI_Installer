local addonName, addonTable = ...

local MEDIA_PATH = "Interface\\AddOns\\OakUI_Installer\\Media\\"
local BORDER_PATH = MEDIA_PATH .. "Borders\\"
local ROUND_THIN_BORDER_NAME = "OakUI Round Thin"
local ROUND_THIN_BORDER_PATH = BORDER_PATH .. "OakRoundThinBorder.png"
local ROUND_THIN_MASK_PATH = BORDER_PATH .. "OakRoundThinMask.png"
local ROUND_THIN_BORDER_WIDTH = 20
local ROUND_THIN_BORDER_HEIGHT = 20
local ROUND_THIN_BORDER_MARGIN = 0.48
local ROUND_THIN_BORDER_OUTSET = 1.5

local margins = {
    left = ROUND_THIN_BORDER_WIDTH * ROUND_THIN_BORDER_MARGIN,
    right = ROUND_THIN_BORDER_WIDTH * ROUND_THIN_BORDER_MARGIN,
    top = ROUND_THIN_BORDER_HEIGHT * ROUND_THIN_BORDER_MARGIN,
    bottom = ROUND_THIN_BORDER_HEIGHT * ROUND_THIN_BORDER_MARGIN,
}

addonTable.OAK_ROUND_THIN_BORDER_NAME = ROUND_THIN_BORDER_NAME
addonTable.OAK_ROUND_THIN_BORDER_KEY = "sm:" .. ROUND_THIN_BORDER_NAME
addonTable.OAK_ROUND_THIN_BORDER_PATH = ROUND_THIN_BORDER_PATH
addonTable.OAK_ROUND_THIN_MASK_PATH = ROUND_THIN_MASK_PATH
addonTable.OAK_ROUND_THIN_BORDER_MARGINS = margins

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

local function RegisterOakRoundThinBorderMedia()
    local LSM = GetLSM()
    if not LSM or addonTable._oakRoundThinBorderMediaRegistered then return end

    LSM:Register("border", ROUND_THIN_BORDER_NAME, ROUND_THIN_BORDER_PATH)
    LSM:Register("nineslice", ROUND_THIN_BORDER_NAME, {
        file = ROUND_THIN_BORDER_PATH,
        previewWidth = ROUND_THIN_BORDER_WIDTH,
        previewHeight = ROUND_THIN_BORDER_HEIGHT,
        padding = { left = 0, right = 0, top = 0, bottom = 0 },
        margins = margins,
        scaleModifier = 1,
        mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched,
    })
    LSM:Register("ninesliceborder", ROUND_THIN_BORDER_NAME, {
        nineslice = ROUND_THIN_BORDER_NAME,
        mask = {
            file = ROUND_THIN_MASK_PATH,
            margins = margins,
        },
    })
    addonTable._oakRoundThinBorderMediaRegistered = true
end
addonTable.RegisterOakRoundThinBorderMedia = RegisterOakRoundThinBorderMedia

local function RegisterOakRoundThinBorderRenderer()
    local E = _G.EllesmereUI
    if type(E) ~= "table" or E._oakRoundThinBorderRendererHooked then return end
    if type(E.ApplyBorderStyle) ~= "function" then return end

    local originalApplyBorderStyle = E.ApplyBorderStyle
    local originalSetBorderStyleColor = E.SetBorderStyleColor
    local margins = addonTable.OAK_ROUND_THIN_BORDER_MARGINS
    local borderStates = setmetatable({}, { __mode = "k" })
    local maskOnlyStates = setmetatable({}, { __mode = "k" })

    local function GetBorderState(borderFrame, create)
        if not borderFrame then return nil end
        local state = borderStates[borderFrame]
        if not state and create then
            state = {}
            borderStates[borderFrame] = state
        end
        return state
    end

    local function HideOakRoundThinBorder(borderFrame)
        local state = GetBorderState(borderFrame, false)
        local texture = state and state.texture
        if texture then texture:Hide() end
        local entries = state and state.maskEntries
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
        if borderFrame then borderStates[borderFrame] = nil end
    end

    local function HideEllesmereBorderSystems(borderFrame)
        local state = GetBorderState(borderFrame, true)
        if state.ellesmereHidden then return end

        local PP = E.PP
        local ppContainer = PP and type(PP.GetBorders) == "function" and PP.GetBorders(borderFrame)
        if ppContainer then
            if type(PP.HideBorder) == "function" then PP.HideBorder(borderFrame) end
            if ppContainer._top then ppContainer._top:SetAlpha(0) end
            if ppContainer._bottom then ppContainer._bottom:SetAlpha(0) end
            if ppContainer._left then ppContainer._left:SetAlpha(0) end
            if ppContainer._right then ppContainer._right:SetAlpha(0) end
        end

        local bdFrame = E._bdBorderData and E._bdBorderData[borderFrame]
        if bdFrame then bdFrame:Hide() end
        state.ellesmereHidden = true
    end

    local function GetOffset(value, fallback)
        if value == nil then return fallback end
        return value
    end

    local function CallWidgetMethodSafe(widget, methodName, ...)
        if not widget then return false, nil end
        local ok, method = pcall(function() return widget[methodName] end)
        if not ok or type(method) ~= "function" then return false, nil end
        local callOk, result = pcall(method, widget, ...)
        if callOk then return true, result end
        return false, nil
    end

    local function CallWidgetMethod(widget, methodName, ...)
        if not widget then return false, nil end
        local ok, method = pcall(function() return widget[methodName] end)
        if not ok or type(method) ~= "function" then return false, nil end
        local callOk, result = pcall(method, widget, ...)
        if callOk then return true, result end
        return false, nil
    end

    local function GetWidgetObjectTypeResult(widget, objectType)
        local ok, isType = CallWidgetMethod(widget, "IsObjectType", objectType)
        return ok, ok and isType
    end

    local function IsWidgetObjectType(widget, objectType)
        local _, isType = GetWidgetObjectTypeResult(widget, objectType)
        return isType
    end

    local function AddMaskTarget(targets, texture)
        if texture and type(texture.AddMaskTexture) == "function" then
            targets[texture] = true
        end
    end

    local function AddMaskGroup(groups, maskParent, anchorFrame, targets)
        if not maskParent or not anchorFrame or type(maskParent.CreateMaskTexture) ~= "function" or not targets or not next(targets) then return end
        groups[#groups + 1] = {
            maskParent = maskParent,
            anchorFrame = anchorFrame,
            targets = targets,
        }
    end

    local function GetFrameChildrenSafe(frame)
        if not frame then return nil end
        local ok, getChildren = pcall(function() return frame.GetChildren end)
        if not ok or type(getChildren) ~= "function" then return nil end
        local callOk, children = pcall(function() return { getChildren(frame) } end)
        if callOk then return children end
        return nil
    end

    local function AddStatusBarMaskGroup(groups, bar, seenStatusBars, anchorOverride)
        if not bar then return end
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
        if not bar then return end
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
            if objectTypeOk and child and not isStatusBar then
                AddChildStatusBarMaskGroups(groups, child, seenStatusBars, depth - 1, anchorOverride)
            end
        end
    end

    local function CollectOakRoundThinMaskGroups(owner, borderFrame, extraTarget)
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
        AddMaskTarget(ownerTargets, extraTarget)
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

    local function RemoveMaskEntries(entries)
        if not entries then return end
        for _, entry in ipairs(entries) do
            local mask = entry.mask
            for target in pairs(entry.targets or {}) do
                if target and target.RemoveMaskTexture and mask then
                    pcall(target.RemoveMaskTexture, target, mask)
                end
            end
        end
    end

    local function ApplyOakRoundThinMask(borderFrame, extraTarget)
        local owner = borderFrame and borderFrame:GetParent()
        if not owner then return end
        local state = GetBorderState(borderFrame, true)

        RemoveMaskEntries(state.maskEntries)

        local groups = CollectOakRoundThinMaskGroups(owner, borderFrame, extraTarget)
        local masks = state.masksByParent
        if not masks then
            masks = {}
            state.masksByParent = masks
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
        state.maskEntries = entries
        state.maskReady = true
    end

    local function RemoveOakRoundThinMaskOnly(anchorFrame)
        local state = anchorFrame and maskOnlyStates[anchorFrame]
        if not state then return end
        RemoveMaskEntries(state.entries)
        if state.mask then
            state.mask:Hide()
        end
        state.entries = nil
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

        local state = maskOnlyStates[maskParent]
        if not state then
            state = {}
            maskOnlyStates[maskParent] = state
        end

        local mask = state.mask
        if not mask or mask:GetParent() ~= maskParent then
            if mask then mask:Hide() end
            mask = maskParent:CreateMaskTexture()
            state.mask = mask
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
        state.entries = {
            { mask = mask, targets = targetSet },
        }
        return true
    end

    local function ApplyOakRoundThinBorder(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY, extraTarget)
        if not borderFrame or not size or size <= 0 then
            HideOakRoundThinBorder(borderFrame)
            if borderFrame then borderFrame:Hide() end
            return
        end

        HideEllesmereBorderSystems(borderFrame)
        local state = GetBorderState(borderFrame, true)
        local needsMaskRefresh = not state.maskReady or state.extraTarget ~= extraTarget
        state.extraTarget = extraTarget

        local texture = state.texture
        if not texture then
            texture = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            texture:SetTexture(ROUND_THIN_BORDER_PATH)
            if texture.SetTextureSliceMargins then
                texture:SetTextureSliceMargins(margins.left, margins.top, margins.right, margins.bottom)
            end
            if texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
                texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
            state.texture = texture
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

        if needsMaskRefresh then
            ApplyOakRoundThinMask(borderFrame, extraTarget)
        end
        if _G.C_Timer and _G.C_Timer.After and not state.deferredRefreshDone and not state.refreshPending then
            state.refreshPending = true
            _G.C_Timer.After(0, function()
                local current = GetBorderState(borderFrame, false)
                if current then
                    current.refreshPending = nil
                    current.deferredRefreshDone = true
                end
                if current and current.texture and current.texture:IsShown() then
                    ApplyOakRoundThinMask(borderFrame, current.extraTarget)
                end
            end)
        end
    end

    addonTable.ApplyOakRoundThinBorderFrame = ApplyOakRoundThinBorder
    addonTable.HideOakRoundThinBorderFrame = HideOakRoundThinBorder
    addonTable.ApplyOakRoundThinMaskOnly = ApplyOakRoundThinMaskOnly
    addonTable.RemoveOakRoundThinMaskOnly = RemoveOakRoundThinMaskOnly
    addonTable.HasOakRoundThinBorderFrame = function(borderFrame)
        local state = borderFrame and borderStates[borderFrame]
        return state and state.texture and state.texture:IsShown() or false
    end
    addonTable.HasOakRoundThinMaskOnly = function(maskParent)
        local state = maskParent and maskOnlyStates[maskParent]
        return state and state.entries ~= nil or false
    end

    function E.ApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey, normalizeScale)
        if IsOakRoundThinBorderKey(textureKey) then
            return ApplyOakRoundThinBorder(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY)
        end

        HideOakRoundThinBorder(borderFrame)
        return originalApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey, normalizeScale)
    end

    function E.SetBorderStyleColor(borderFrame, r, g, b, a)
        local state = borderFrame and borderStates[borderFrame]
        local texture = state and state.texture
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
