local addonName, addonTable = ...

local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "SHADOW" }

local function SetShown(frame, shown)
    if frame.SetShown then
        frame:SetShown(shown)
    elseif shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function CreateLabel(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local openMenu
local function CreateDropdown(parent, width, valuesFunc, onSelect)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 26)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(0.08, 0.08, 0.09, 1)
    button:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.Text:SetPoint("RIGHT", button, "RIGHT", -22, 0)
    button.Text:SetJustifyH("LEFT")
    if button.Text.SetWordWrap then button.Text:SetWordWrap(false) end

    local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", button, "RIGHT", -7, 0)
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, button, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, 220)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    menu:SetBackdropColor(0.04, 0.04, 0.05, 1)
    menu:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
    menu:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -24, 4)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(width - 28)
    scroll:SetScrollChild(child)
    if addonTable.SkinScrollbar then addonTable.SkinScrollbar(scroll) end

    local function Populate()
        for _, region in ipairs({ child:GetChildren() }) do region:Hide() end

        local values = valuesFunc()
        local y = 0
        for i, value in ipairs(values) do
            local row = select(i, child:GetChildren())
            if not row then
                row = CreateFrame("Button", nil, child)
                row:SetHeight(22)
                row:SetPoint("LEFT", child, "LEFT", 0, 0)
                row:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.Text:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.Text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.Text:SetJustifyH("LEFT")
                if row.Text.SetWordWrap then row.Text:SetWordWrap(false) end
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.bg:SetColorTexture(1, 1, 1, 0)
                row:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.08) end)
                row:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) end)
            end
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
            row.value = value
            row.Text:SetText(value)
            row:SetScript("OnClick", function(self)
                button:SetValue(self.value)
                onSelect(self.value)
                menu:Hide()
                if openMenu == menu then openMenu = nil end
            end)
            row:Show()
            y = y - 22
        end
        child:SetHeight(math.max(1, #values * 22))
    end

    button:SetScript("OnClick", function()
        if openMenu and openMenu ~= menu then openMenu:Hide() end
        if menu:IsShown() then
            menu:Hide()
            openMenu = nil
        else
            Populate()
            menu:Show()
            openMenu = menu
        end
    end)

    function button:SetValue(value)
        self.value = value
        self.Text:SetText(value or "")
    end

    return button
end

local function CreateCheckbox(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(20, 20)
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.border:SetColorTexture(0.3, 0.32, 0.38, 1)
    button.inner = button:CreateTexture(nil, "ARTWORK")
    button.inner:SetPoint("TOPLEFT", 2, -2)
    button.inner:SetPoint("BOTTOMRIGHT", -2, 2)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    button.label:SetText(text)
    button:SetScript("OnClick", onClick)
    function button:SetCheckedState(checked)
        self.checked = checked and true or false
        local colors = addonTable.colors or { r = 0.58, g = 0.51, b = 0.79 }
        if self.checked then
            self.inner:SetColorTexture(colors.r, colors.g, colors.b, 1)
        else
            self.inner:SetColorTexture(0.137, 0.141, 0.172, 1)
        end
    end
    return button
end

local function CreateSizeBox(parent, onChanged)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(52, 24)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(2)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        onChanged(tonumber(self:GetText()))
    end)
    box:SetScript("OnEditFocusLost", function(self)
        onChanged(tonumber(self:GetText()))
    end)
    return box
end

function addonTable.BuildFontsUI(parentFrame)
    local cWrap = addonTable.cWrap or "|cffffffff"
    local colors = addonTable.colors or { r = 0.58, g = 0.51, b = 0.79 }
    local db = addonTable.EnsureFontDB()
    local selectedKey = addonTable.FontSections[1].key

    local title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -16)
    title:SetJustifyH("LEFT")
    title:SetText(cWrap .. "Custom Fonts|r")

    local desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, 0)
    desc:SetFontObject("GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetText("Uses LibSharedMedia fonts when available. Combat and floating name font changes require a full game restart or relog.")

    CreateLabel(parentFrame, "Default Font", 15, -72)
    local defaultFont = CreateDropdown(parentFrame, 175, addonTable.GetFontChoices, function(value)
        db.global.font = value
    end)
    defaultFont:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -90)
    defaultFont:SetValue(db.global.font)

    CreateLabel(parentFrame, "Font Size", 205, -72)
    local defaultSize = CreateSizeBox(parentFrame, function(value)
        db.global.size = math.max(8, math.min(64, value or 14))
    end)
    defaultSize:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 205, -90)
    defaultSize:SetText(tostring(db.global.size or 14))

    CreateLabel(parentFrame, "Font Outline", 275, -72)
    local defaultOutline = CreateDropdown(parentFrame, 125, function() return OUTLINES end, function(value)
        db.global.outline = value
    end)
    defaultOutline:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 275, -90)
    defaultOutline:SetValue(db.global.outline or "NONE")

    local replaceBlizz = CreateCheckbox(parentFrame, "Replace Blizzard Fonts", function(self)
        db.replaceBlizzardFonts = not db.replaceBlizzardFonts
        self:SetCheckedState(db.replaceBlizzardFonts)
        if addonTable.ApplyOakFonts then addonTable.ApplyOakFonts() end
    end)
    replaceBlizz:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -124)
    replaceBlizz:SetCheckedState(db.replaceBlizzardFonts)

    local applyAll = addonTable.MakeFlatButton(parentFrame, "Apply Font To All", 135, 26)
    applyAll:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 315, -124)

    local list = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    list:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -156)
    list:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 15, 45)
    list:SetWidth(205)
    list:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    list:SetBackdropColor(0.08, 0.08, 0.09, 1)
    list:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

    local listScroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -24, 4)
    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetWidth(180)
    listScroll:SetScrollChild(listChild)
    listScroll:SetScript("OnSizeChanged", function(self, width)
        listChild:SetWidth(width)
    end)
    if addonTable.SkinScrollbar then addonTable.SkinScrollbar(listScroll) end

    local detail = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 10, 0)
    detail:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -15, 45)
    detail:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    detail:SetBackdropColor(0.08, 0.08, 0.09, 1)
    detail:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

    local sectionTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sectionTitle:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -14)

    local enable = CreateCheckbox(detail, "Enable", function(self)
        local settings = db.sections[selectedKey]
        settings.enable = not settings.enable
        self:SetCheckedState(settings.enable)
    end)
    enable:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -48)

    CreateLabel(detail, "Font", 14, -88)
    local sectionFont = CreateDropdown(detail, 230, addonTable.GetFontChoices, function(value)
        db.sections[selectedKey].font = value
    end)
    sectionFont:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -106)

    CreateLabel(detail, "Font Size", 14, -140)
    local sectionSize = CreateSizeBox(detail, function(value)
        db.sections[selectedKey].size = math.max(8, math.min(64, value or 14))
    end)
    sectionSize:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -158)

    CreateLabel(detail, "Font Outline", 84, -140)
    local sectionOutline = CreateDropdown(detail, 160, function() return OUTLINES end, function(value)
        db.sections[selectedKey].outline = value
    end)
    sectionOutline:SetPoint("TOPLEFT", detail, "TOPLEFT", 84, -158)

    local largeLabel = CreateLabel(detail, "Larger Font", 14, -202)
    local largeFont = CreateDropdown(detail, 230, addonTable.GetFontChoices, function(value)
        db.sections[selectedKey].largeFont = value
    end)
    largeFont:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -220)

    local largeSizeLabel = CreateLabel(detail, "Larger Size", 14, -254)
    local largeSize = CreateSizeBox(detail, function(value)
        db.sections[selectedKey].largeSize = math.max(8, math.min(64, value or 11))
    end)
    largeSize:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -272)

    local largeOutlineLabel = CreateLabel(detail, "Larger Outline", 84, -254)
    local largeOutline = CreateDropdown(detail, 160, function() return OUTLINES end, function(value)
        db.sections[selectedKey].largeOutline = value
    end)
    largeOutline:SetPoint("TOPLEFT", detail, "TOPLEFT", 84, -272)

    local note = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 14, 14)
    note:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -14, 14)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.75, 0.75, 0.75)

    local rows = {}
    local function RefreshDetail()
        local section
        for _, entry in ipairs(addonTable.FontSections) do
            if entry.key == selectedKey then section = entry break end
        end
        local settings = db.sections[selectedKey]
        sectionTitle:SetText(cWrap .. (section and section.name or selectedKey) .. "|r")
        enable:SetCheckedState(settings.enable)
        sectionFont:SetValue(settings.font)
        sectionSize:SetText(tostring(settings.size or (section and section.size) or 14))
        sectionOutline:SetValue(settings.outline or "NONE")

        local isNameplate = selectedKey == "nameplate"
        SetShown(largeLabel, isNameplate)
        SetShown(largeFont, isNameplate)
        SetShown(largeSizeLabel, isNameplate)
        SetShown(largeSize, isNameplate)
        SetShown(largeOutlineLabel, isNameplate)
        SetShown(largeOutline, isNameplate)
        if isNameplate then
            largeFont:SetValue(settings.largeFont or settings.font)
            largeSize:SetText(tostring(settings.largeSize or 11))
            largeOutline:SetValue(settings.largeOutline or "OUTLINE")
        end

        if section and section.restart then
            note:SetText("|cffff3333Requires a full game restart or relog after applying.|r")
        else
            note:SetText("Most changes apply immediately. Some already-created Blizzard frames may need a reload to redraw.")
        end

        for _, row in ipairs(rows) do
            if row.key == selectedKey then
                row.bg:SetColorTexture(colors.r, colors.g, colors.b, 0.22)
                row.Text:SetText(cWrap .. row.name .. "|r")
            else
                row.bg:SetColorTexture(1, 1, 1, 0)
                row.Text:SetText("|cffffffff" .. row.name .. "|r")
            end
        end
    end

    local y = -4
    for _, section in ipairs(addonTable.FontSections) do
        local row = CreateFrame("Button", nil, listChild)
        row:SetHeight(18)
        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, y)
        row.key = section.key
        row.name = section.name
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)
        row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.Text:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.Text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.Text:SetJustifyH("LEFT")
        if row.Text.SetWordWrap then row.Text:SetWordWrap(false) end
        row:SetScript("OnClick", function(self)
            selectedKey = self.key
            RefreshDetail()
        end)
        rows[#rows + 1] = row
        y = y - 18
    end
    listChild:SetHeight(math.abs(y) + 4)

    local apply = addonTable.MakeFlatButton(parentFrame, "Apply Fonts", 120, 28)
    apply:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -15, 12)
    apply.Text:SetTextColor(colors.r, colors.g, colors.b)
    apply:SetScript("OnClick", function()
        if addonTable.ApplyOakFonts then addonTable.ApplyOakFonts() end
        if addonTable.ShowReloadPrompt then
            addonTable.ShowReloadPrompt("Fonts applied.\n\nReload applies most Blizzard text. Combat and floating character names require a full game restart or relog.", "Reload UI", function() ReloadUI() end)
        end
    end)

    applyAll:SetScript("OnClick", function()
        if addonTable.ApplyFontToAll then addonTable.ApplyFontToAll(db.global.font) end
        replaceBlizz:SetCheckedState(db.replaceBlizzardFonts)
        RefreshDetail()
    end)

    RefreshDetail()
end
