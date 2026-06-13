-- Reference implementation for adding the OakUI-tested "Round Thin" border
-- directly to EllesmereUI.
--
-- Expected asset paths:
-- Interface\AddOns\EllesmereUI\Media\Borders\RoundThinBorder.png
-- Interface\AddOns\EllesmereUI\Media\Borders\RoundThinMask.png

local E = _G.EllesmereUI
if type(E) ~= "table" then return end

local BORDER_NAME = "Round Thin"
local BORDER_KEY = "sm:" .. BORDER_NAME
local BORDER_PATH = "Interface\\AddOns\\EllesmereUI\\Media\\Borders\\RoundThinBorder.png"
local MASK_PATH = "Interface\\AddOns\\EllesmereUI\\Media\\Borders\\RoundThinMask.png"
local BORDER_WIDTH = 20
local BORDER_HEIGHT = 20
local BORDER_MARGIN = 0.48
local BORDER_OUTSET = 1.5

local MARGINS = {
    left = BORDER_WIDTH * BORDER_MARGIN,
    right = BORDER_WIDTH * BORDER_MARGIN,
    top = BORDER_HEIGHT * BORDER_MARGIN,
    bottom = BORDER_HEIGHT * BORDER_MARGIN,
}

local function GetLSM()
    return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
end

local function IsRoundThinBorderKey(textureKey)
    return textureKey == BORDER_NAME
        or textureKey == BORDER_KEY
        or textureKey == BORDER_PATH
end

local function RegisterRoundThinBorderStyle()
    local LSM = GetLSM()
    if not LSM then return end

    LSM:Register("border", BORDER_NAME, BORDER_PATH)
    LSM:Register("nineslice", BORDER_NAME, {
        file = BORDER_PATH,
        previewWidth = BORDER_WIDTH,
        previewHeight = BORDER_HEIGHT,
        padding = { left = 0, right = 0, top = 0, bottom = 0 },
        margins = MARGINS,
        scaleModifier = 1,
        mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched,
    })
    LSM:Register("ninesliceborder", BORDER_NAME, {
        nineslice = BORDER_NAME,
        mask = {
            file = MASK_PATH,
            margins = MARGINS,
        },
    })
end

local function AddMaskTarget(targets, texture)
    if texture and texture.AddMaskTexture then
        targets[texture] = true
    end
end

local function AddMaskGroup(groups, maskParent, anchorFrame, targets)
    if not maskParent or not anchorFrame or not maskParent.CreateMaskTexture or not targets or not next(targets) then return end
    groups[#groups + 1] = {
        maskParent = maskParent,
        anchorFrame = anchorFrame,
        targets = targets,
    }
end

local function GetFrameChildrenSafe(frame)
    if not frame or type(frame.GetChildren) ~= "function" then return nil end
    local ok, children = pcall(function()
        return { frame:GetChildren() }
    end)
    if ok then return children end
    return nil
end

local function AddStatusBarMaskGroup(groups, bar, seenStatusBars, anchorOverride)
    if not bar or not bar.GetStatusBarTexture then return end
    if seenStatusBars then
        if seenStatusBars[bar] then return end
        seenStatusBars[bar] = true
    end

    local targets = {}
    AddMaskTarget(targets, bar:GetStatusBarTexture())
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

local function AddChildStatusBarMaskGroups(groups, frame, seenStatusBars, depth, anchorOverride)
    if not frame or not frame.GetChildren or (depth or 0) <= 0 then return end
    local children = GetFrameChildrenSafe(frame)
    if not children then return end

    for _, child in ipairs(children) do
        if child and child.IsObjectType and child:IsObjectType("StatusBar") then
            AddStatusBarMaskGroup(groups, child, seenStatusBars, anchorOverride)
        else
            AddChildStatusBarMaskGroups(groups, child, seenStatusBars, depth - 1, anchorOverride)
        end
    end
end

local function CollectRoundThinMaskGroups(owner, borderFrame)
    local groups = {}
    if not owner then return groups end

    local seenStatusBars = {}
    local ownerTargets = {}
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

    if owner.IsObjectType and owner:IsObjectType("StatusBar") then
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
    AddChildStatusBarMaskGroups(groups, owner, seenStatusBars, 2, borderFrame)

    return groups
end

local function RemoveRoundThinMaskEntries(owner)
    local entries = owner and owner._roundThinMaskEntries
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
    if owner then owner._roundThinMaskEntries = nil end
end

local function ApplyRoundThinMask(borderFrame)
    local owner = borderFrame and borderFrame:GetParent()
    if not owner then return end

    RemoveRoundThinMaskEntries(borderFrame)

    local groups = CollectRoundThinMaskGroups(owner, borderFrame)
    local masks = borderFrame._roundThinMasksByParent
    if not masks then
        masks = {}
        borderFrame._roundThinMasksByParent = masks
    end

    local entries = {}
    for _, group in ipairs(groups) do
        local mask = masks[group.maskParent]
        if not mask or mask:GetParent() ~= group.maskParent then
            if mask then mask:Hide() end
            mask = group.maskParent:CreateMaskTexture()
            masks[group.maskParent] = mask
        end

        mask:SetTexture(MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if mask.SetTextureSliceMargins then
            mask:SetTextureSliceMargins(MARGINS.left, MARGINS.top, MARGINS.right, MARGINS.bottom)
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

    borderFrame._roundThinMaskEntries = entries
end

local function RemoveRoundThinMaskOnly(maskParent)
    local entries = maskParent and maskParent._roundThinMaskOnlyEntries
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
    if maskParent and maskParent._roundThinMaskOnly then
        maskParent._roundThinMaskOnly:Hide()
    end
    if maskParent then maskParent._roundThinMaskOnlyEntries = nil end
end

local function ApplyRoundThinMaskOnly(maskParent, targets, anchorFrame)
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

    RemoveRoundThinMaskOnly(maskParent)

    local mask = maskParent._roundThinMaskOnly
    if not mask or mask:GetParent() ~= maskParent then
        if mask then mask:Hide() end
        mask = maskParent:CreateMaskTexture()
        maskParent._roundThinMaskOnly = mask
    end

    mask:SetTexture(MASK_PATH, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if mask.SetTextureSliceMargins then
        mask:SetTextureSliceMargins(MARGINS.left, MARGINS.top, MARGINS.right, MARGINS.bottom)
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

    maskParent._roundThinMaskOnlyEntries = {
        { mask = mask, targets = targetSet },
    }
    return true
end

local function HideRoundThinBorderFrame(borderFrame)
    local texture = borderFrame and borderFrame._roundThinBorderTexture
    if texture then texture:Hide() end
    RemoveRoundThinMaskEntries(borderFrame)
end

local function HideExistingEllesmereBorderSystems(borderFrame)
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

local function ApplyRoundThinBorderFrame(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY)
    if not borderFrame or not size or size <= 0 then
        HideRoundThinBorderFrame(borderFrame)
        if borderFrame then borderFrame:Hide() end
        return
    end

    HideExistingEllesmereBorderSystems(borderFrame)

    local texture = borderFrame._roundThinBorderTexture
    if not texture then
        texture = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        borderFrame._roundThinBorderTexture = texture
        if texture.SetTextureSliceMargins then
            texture:SetTextureSliceMargins(MARGINS.left, MARGINS.top, MARGINS.right, MARGINS.bottom)
        end
        if texture.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
            texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
        end
    end

    texture:SetTexture(BORDER_PATH)

    local padX = BORDER_OUTSET + (offsetOverride or 0)
    local padY = BORDER_OUTSET + (offsetYOverride or 0)
    local sx = shiftX or 0
    local sy = shiftY or 0

    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", -padX + sx, padY + sy)
    texture:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", padX + sx, -padY + sy)
    texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
    texture:Show()
    borderFrame:Show()

    ApplyRoundThinMask(borderFrame)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            if borderFrame and borderFrame._roundThinBorderTexture and borderFrame._roundThinBorderTexture:IsShown() then
                ApplyRoundThinMask(borderFrame)
            end
        end)
    end
end

local function HookEllesmereBorderStyle()
    if E._roundThinBorderRendererHooked or type(E.ApplyBorderStyle) ~= "function" then return end

    local originalApplyBorderStyle = E.ApplyBorderStyle
    local originalSetBorderStyleColor = E.SetBorderStyleColor

    function E.ApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey)
        if IsRoundThinBorderKey(textureKey) then
            return ApplyRoundThinBorderFrame(borderFrame, size, r, g, b, a, offsetOverride, offsetYOverride, shiftX, shiftY)
        end

        HideRoundThinBorderFrame(borderFrame)
        return originalApplyBorderStyle(borderFrame, size, r, g, b, a, textureKey, offsetOverride, offsetYOverride, shiftX, shiftY, addonKey, sizeKey)
    end

    function E.SetBorderStyleColor(borderFrame, r, g, b, a)
        local texture = borderFrame and borderFrame._roundThinBorderTexture
        if texture and texture:IsShown() then
            texture:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
            return
        end

        if originalSetBorderStyleColor then
            return originalSetBorderStyleColor(borderFrame, r, g, b, a)
        end
    end

    E._roundThinBorderRendererHooked = true
end

E.ROUND_THIN_BORDER_NAME = BORDER_NAME
E.ROUND_THIN_BORDER_KEY = BORDER_KEY
E.ROUND_THIN_BORDER_PATH = BORDER_PATH
E.ROUND_THIN_MASK_PATH = MASK_PATH
E.ROUND_THIN_BORDER_MARGINS = MARGINS
E.IsRoundThinBorderKey = IsRoundThinBorderKey
E.RegisterRoundThinBorderStyle = RegisterRoundThinBorderStyle
E.ApplyRoundThinBorderFrame = ApplyRoundThinBorderFrame
E.HideRoundThinBorderFrame = HideRoundThinBorderFrame
E.ApplyRoundThinMaskOnly = ApplyRoundThinMaskOnly
E.RemoveRoundThinMaskOnly = RemoveRoundThinMaskOnly

RegisterRoundThinBorderStyle()
HookEllesmereBorderStyle()
