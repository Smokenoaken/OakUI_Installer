local addonName, addonTable = ...

function addonTable.HasOakNativeCorners()
    local E = _G.EllesmereUI
    return E and type(E.RoundCorners) == "function" and type(E.RoundedStyleOK) == "function"
end

function addonTable.GetOakCornerRadius()
    local db = _G.OakUI_DB and _G.OakUI_DB.visibility
    local value = db and tonumber(db.cornerRadius) or 8
    return math.max(0, math.min(16, math.floor(value + 0.5)))
end

function addonTable.SetOakCornerRadius(value, deferPrompt)
    value = math.max(0, math.min(16, math.floor((tonumber(value) or 8) + 0.5)))
    if value == addonTable.GetOakCornerRadius() then return end
    _G.OakUI_DB = _G.OakUI_DB or {}
    _G.OakUI_DB.visibility = _G.OakUI_DB.visibility or {}
    _G.OakUI_DB.visibility.cornerRadius = value
    if not deferPrompt and addonTable.ShowReloadPrompt then
        addonTable.ShowReloadPrompt("Reload to apply Corner Radius to all enabled rounded borders.")
    end
end

function addonTable.ApplyOakNativeCornerSettings(settings, styleKey)
    if not addonTable.HasOakNativeCorners() then return false end
    local E = _G.EllesmereUI
    local style = settings[styleKey]
    if not E.RoundedStyleOK(style) then
        settings[styleKey] = "solid"
    end
    settings.cornerRadius = addonTable.GetOakCornerRadius()
    return true
end

function addonTable.ApplyOakNativePartyCorners(settings)
    if not addonTable.HasOakNativeCorners() then return end
    settings.party_cornerRadius = addonTable.GetOakCornerRadius()
    local style = settings.party_borderTexture or settings.borderTexture
    if not _G.EllesmereUI.RoundedStyleOK(style) then style = "solid" end
    settings.party_borderTexture = style
end

function addonTable.CreateOakCornerPreview(parent, x, y, width)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    preview:SetSize(width, 40)
    local fill = preview:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.58, 0.39, 0.72, 1)
    local label = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    local opts = { roots = {}, textures = { fill }, border = preview, style = "solid" }
    function preview:UpdateRadius(value)
        value = math.max(0, math.min(16, math.floor(value + 0.5)))
        label:SetText("Corner Radius: " .. value)
        if addonTable.HasOakNativeCorners() then
            local E = _G.EllesmereUI
            E.ApplyBorderStyle(self, 1, 0, 0, 0, 1, "solid")
            E.RoundCorners(self, value, opts)
        end
    end
    preview:SetScript("OnShow", function(self) self:UpdateRadius(addonTable.GetOakCornerRadius()) end)
    preview:UpdateRadius(addonTable.GetOakCornerRadius())
    local apply = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    apply:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6)
    apply:SetSize(width, 22)
    apply:SetText("Apply Radius / Reload")
    apply:SetScript("OnClick", function()
        if addonTable.ShowReloadPrompt then
            addonTable.ShowReloadPrompt("Reload to apply Corner Radius to all enabled rounded borders.")
        end
    end)
    return preview
end

local iconMasks = setmetatable({}, { __mode = "k" })

function addonTable.RemoveOakIconCorners(icon)
    local state = icon and iconMasks[icon]
    if state and state.attached then
        pcall(icon.RemoveMaskTexture, icon, state.mask)
        state.attached = false
    end
end

function addonTable.ApplyOakIconCorners(icon)
    if not icon or (icon.IsForbidden and icon:IsForbidden()) then return end
    local parent = icon:GetParent()
    if not parent or (parent.IsForbidden and parent:IsForbidden()) then return end
    local radius = addonTable.GetOakCornerRadius()
    if radius == 0 then addonTable.RemoveOakIconCorners(icon); return end
    local w, h = icon:GetSize()
    if issecretvalue and (issecretvalue(w) or issecretvalue(h)) then return end
    if not w or not h or w <= 0 or h <= 0 then return end
    local index = math.max(1, math.min(16, math.floor(radius / math.min(w, h) * 32 + 0.5)))
    local state = iconMasks[icon]
    if not state then
        state = { mask = parent:CreateMaskTexture() }
        state.mask:SetAllPoints(icon)
        iconMasks[icon] = state
    end
    if state.index ~= index then
        addonTable.RemoveOakIconCorners(icon)
        state.mask:SetTexture("Interface\\AddOns\\OakUI_Installer\\Media\\Borders\\OakIconMask" .. string.format("%02d", index) .. ".tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        state.index = index
    end
    if not state.attached then
        state.attached = pcall(icon.AddMaskTexture, icon, state.mask)
    end
end
