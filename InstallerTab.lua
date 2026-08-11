local addonName, addonTable = ...

local function TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsAddonReady(folder)
    if not folder then return true end
    if not C_AddOns or not C_AddOns.GetAddOnInfo then return false end
    local name, _, _, _, reason = C_AddOns.GetAddOnInfo(folder)
    if not name or reason == "MISSING" then return false end
    if C_AddOns.GetAddOnEnableState and C_AddOns.GetAddOnEnableState(folder, UnitName("player")) == 0 then
        return false
    end
    return true
end

local OPTIONAL_PROFILE_FOLDERS = {
    dbm = "DBM-Core",
    bigwigs = "BigWigs",
    blizzi = "BliZzi_Interrupts",
    wmarker = "wMarker",
}

local function IsOptionalProfileReady(key)
    return IsAddonReady(OPTIONAL_PROFILE_FOLDERS[key])
end

local function OptionalProfileEnabled(options, key)
    return IsOptionalProfileReady(key) and not (options and options.optionalProfiles and options.optionalProfiles[key] == false)
end

local function BuildInstallerAddons(Inj, cWrap, ShowCopyBox)
    local baseUrl = "https://www.curseforge.com/wow/addons/ellesmere-ui"
    return {
        { name = "Ellesmere UI Profile", folder = "EllesmereUI", url = baseUrl, func = Inj.BaseUI, requiresReload = true, hasRoles = true, includeInAll = true },
        {
            name = "Blizzard Edit Mode (Layout)",
            folder = nil,
            buttonText = "Import Layout",
            installedText = "Imported!",
            func = function()
                if Inj.EditMode and Inj.EditMode() then return end
                ShowCopyBox(Inj.GetEditMode(), cWrap .. "1.|r Press CTRL+C to copy the text below.\n" .. cWrap .. "2.|r Open ESC -> Edit Mode.\n" .. cWrap .. "3.|r Click the Layout Dropdown -> Import -> Paste.")
            end,
            manual = true,
            includeInAll = true,
            requiresReload = true,
        },
        {
            name = "OakUI Chat Layout",
            folder = nil,
            buttonText = "Apply Layout",
            installedText = "Applied!",
            func = function()
                if addonTable.QueueOakChatLayoutAfterReload then
                    addonTable.QueueOakChatLayoutAfterReload()
                end
            end,
            manual = true,
            includeInAll = true,
            requiresReload = true,
        },
        { name = "DBM (Optional)", folder = "DBM-Core", url = "https://www.curseforge.com/wow/addons/deadly-boss-mods", func = Inj.DBM, requiresReload = false },
        { name = "BigWigs (Optional)", folder = "BigWigs", url = "https://www.curseforge.com/wow/addons/big-wigs", func = Inj.BigWigs, requiresReload = false },
        { name = "Blizzi Party Tools (Optional)", folder = "BliZzi_Interrupts", url = "https://www.curseforge.com/wow/addons/blizzi-party-tools", func = Inj.BlizziPartyTools, requiresReload = false },
        { name = "wMarker (Optional)", folder = "wMarker", url = "https://www.curseforge.com/wow/addons/wmarker", func = Inj.WMarker, requiresReload = false },
    }
end

local function SelectionPreset(mode)
    local selected = {}
    local function Walk(node, parentSelected)
        if type(node) ~= "table" then return end
        if not node.header then
            if mode == "all" then
                selected[node.id] = true
                parentSelected = true
            elseif mode == "recommended" and node.recommended and not parentSelected then
                selected[node.id] = true
                parentSelected = true
            end
        end
        for _, child in ipairs(node.children or {}) do
            Walk(child, parentSelected)
        end
    end
    for _, node in ipairs(addonTable.EllesmereSelectiveTree or {}) do Walk(node, false) end
    return selected
end

function addonTable.BuildInstallerUI(parentFrame)
    local Inj = addonTable.Injectors
    local cWrap = addonTable.cWrap
    local colors = addonTable.colors
    local r, g, b = colors.r, colors.g, colors.b
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar
    local ShowCopyBox = addonTable.ShowCopyBox

    local FlagshipAddons = BuildInstallerAddons(Inj, cWrap, ShowCopyBox)
    addonTable.FlagshipAddons = FlagshipAddons

    local function GetDefaultLayoutKey()
        local preset = addonTable.GetOakRecommendedLayoutPreset and addonTable.GetOakRecommendedLayoutPreset()
        return (type(preset) == "table" and preset.key) or "native"
    end

    local state = {
        mode = "fresh",
        roles = { dps = true, heals = false },
        profiles = {
            dps = addonTable.GetOakEllesmereRoleProfileName and addonTable.GetOakEllesmereRoleProfileName("dps") or "OakUI Tank/DPS",
            heals = addonTable.GetOakEllesmereRoleProfileName and addonTable.GetOakEllesmereRoleProfileName("heals") or "OakUI Healer",
        },
        autoAssign = false,
        layoutKey = GetDefaultLayoutKey(),
        layoutTouched = false,
        selection = SelectionPreset("recommended"),
        chatLayout = true,
        optionalProfiles = {
            dbm = true,
            bigwigs = true,
            blizzi = true,
            wmarker = true,
        },
        visibility = {
            unitFrames = true,
            actionBars = true,
            cdm = true,
            chat = true,
            showPlayerInGroup = true,
            chatLineFade = true,
            disableChatFade = false,
        },
        rounded = { all = true },
    }

    local function ResetInstallerState(options)
        options = options or {}
        state.mode = options.mode or "fresh"
        state.roles.dps = options.dps == true
        state.roles.heals = options.heals == true
        if not state.roles.dps and not state.roles.heals then
            state.roles.dps = true
        end
        state.profiles.dps = options.dpsProfile or (addonTable.GetOakEllesmereRoleProfileName and addonTable.GetOakEllesmereRoleProfileName("dps") or "OakUI Tank/DPS")
        state.profiles.heals = options.healsProfile or (addonTable.GetOakEllesmereRoleProfileName and addonTable.GetOakEllesmereRoleProfileName("heals") or "OakUI Healer")
        state.autoAssign = options.autoAssign == true
        state.layoutKey = options.layoutKey or GetDefaultLayoutKey()
        state.layoutTouched = options.layoutKey ~= nil
        state.selection = SelectionPreset(options.selectionMode or "recommended")
        state.chatLayout = options.chatLayout ~= false
        state.optionalProfiles = {
            dbm = OptionalProfileEnabled(options, "dbm"),
            bigwigs = OptionalProfileEnabled(options, "bigwigs"),
            blizzi = OptionalProfileEnabled(options, "blizzi"),
            wmarker = OptionalProfileEnabled(options, "wmarker"),
        }
        state.visibility = {
            unitFrames = true,
            actionBars = true,
            cdm = true,
            chat = true,
            showPlayerInGroup = true,
            chatLineFade = true,
            disableChatFade = false,
        }
        state.rounded = { all = true }
    end

    local title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -16)
    title:SetJustifyH("LEFT")
    title:SetText(cWrap .. "Main Installer|r")

    local desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Guided fresh install or selective update with profile, visibility, and rounded-border choices.")

    local stepLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stepLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    stepLabel:SetTextColor(0.62, 0.62, 0.62)

    local content = CreateFrame("Frame", nil, parentFrame)
    content:SetPoint("TOPLEFT", stepLabel, "BOTTOMLEFT", 0, -10)
    content:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -15, 50)

    local preview = CreateFrame("Frame", nil, content, "BackdropTemplate")
    preview:SetSize(160, 104)
    preview:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -2)
    preview:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    preview:SetBackdropColor(0.08, 0.08, 0.1, 1)
    preview:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)
    preview.texture = preview:CreateTexture(nil, "ARTWORK")
    preview.texture:SetPoint("TOPLEFT", preview, "TOPLEFT", 6, -6)
    preview.texture:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -6, 24)
    preview.texture:SetTexCoord(0, 1, 0, 1)
    preview.caption = preview:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    preview.caption:SetPoint("BOTTOMLEFT", preview, "BOTTOMLEFT", 6, 6)
    preview.caption:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -6, 6)
    preview.caption:SetJustifyH("CENTER")
    preview.caption:SetTextColor(0.62, 0.62, 0.62)

    local pages = {}
    local currentStep = 1
    local stepOrder = { "mode", "layout", "profiles", "addons", "selective", "visibility", "rounded", "review" }
    local previewVisible = true

    local function AnchorPage(page)
        if not page then return end
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        if previewVisible then
            page:SetPoint("TOPRIGHT", preview, "TOPLEFT", -12, 0)
            page:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
        else
            page:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 0)
        end
    end

    local function LayoutContent(width)
        previewVisible = (width or content:GetWidth() or 0) >= 560
        preview:SetShown(previewVisible)
        for _, page in pairs(pages) do
            AnchorPage(page)
        end
    end
    content:SetScript("OnSizeChanged", function(self, width)
        LayoutContent(width)
    end)

    local function SetPreview(key, label)
        local path = "Interface\\AddOns\\OakUI_Installer\\Media\\InstallerPreviews\\" .. tostring(key or "default")
        local ok = preview.texture:SetTexture(path)
        preview.texture:SetShown(ok == true)
        preview.caption:SetText(label or "")
    end

    local function ClearPage(page)
        for _, child in ipairs({ page:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
        for _, region in ipairs({ page:GetRegions() }) do
            region:Hide()
        end
    end

    local function MakePage(key)
        local page = CreateFrame("Frame", nil, content)
        AnchorPage(page)
        page:Hide()
        pages[key] = page
        return page
    end

    local function MakeCheckbox(parent, label, description, getter, setter, y, indent, previewKey)
        local row = CreateFrame("Button", nil, parent)
        row:SetHeight(description and 34 or 24)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", indent or 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)

        local box = row:CreateTexture(nil, "BACKGROUND")
        box:SetSize(18, 18)
        box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        box:SetColorTexture(0.3, 0.32, 0.38, 1)
        local inner = row:CreateTexture(nil, "ARTWORK")
        inner:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 1)
        text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 1)
        text:SetJustifyH("LEFT")
        text:SetText(label)

        local note
        if description and description ~= "" then
            note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -1)
            note:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -1)
            note:SetJustifyH("LEFT")
            note:SetTextColor(0.62, 0.62, 0.62)
            note:SetText(description)
        end

        local function Update()
            if getter() then
                inner:SetColorTexture(r, g, b, 1)
            else
                inner:SetColorTexture(0.137, 0.141, 0.172, 1)
            end
        end
        row.UpdateState = Update
        row:SetScript("OnClick", function()
            setter(not getter())
            Update()
        end)
        row:SetScript("OnEnter", function()
            if previewKey then SetPreview(previewKey, label) end
        end)
        Update()
        return row
    end

    local function MakeChoice(parent, label, description, key, value, y, height)
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(height or 64)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

        local head = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        head:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
        head:SetText(label)
        local body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -3)
        body:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 6)
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        if body.SetMaxLines then body:SetMaxLines(3) end
        body:SetTextColor(0.72, 0.72, 0.72)
        body:SetText(description)

        local function Update()
            local selected = state[key] == value
            row:SetBackdropColor(selected and r or 0.1, selected and g or 0.1, selected and b or 0.12, selected and 0.22 or 1)
            head:SetTextColor(selected and r or 1, selected and g or 1, selected and b or 1)
        end
        row:SetScript("OnClick", function()
            state[key] = value
            for _, sibling in ipairs(parent._choices or {}) do sibling.Update() end
        end)
        row:SetScript("OnEnter", function() SetPreview(value, label) end)
        parent._choices = parent._choices or {}
        parent._choices[#parent._choices + 1] = row
        row.Update = Update
        Update()
        return row
    end

    local function MakeLayoutChoice(parent, preset, x, y)
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetSize(206, 52)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)

        local head = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        head:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
        head:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
        head:SetJustifyH("LEFT")
        if head.SetWordWrap then head:SetWordWrap(false) end
        if head.SetMaxLines then head:SetMaxLines(1) end
        head:SetText(preset.label)

        local body = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
        body:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -2)
        body:SetJustifyH("LEFT")
        if body.SetWordWrap then body:SetWordWrap(false) end
        if body.SetMaxLines then body:SetMaxLines(1) end
        body:SetTextColor(0.72, 0.72, 0.72)
        body:SetText(preset.desc)

        local function Update()
            local selected = state.layoutKey == preset.key
            row:SetBackdropColor(selected and r or 0.1, selected and g or 0.1, selected and b or 0.12, selected and 0.22 or 1)
            head:SetTextColor(selected and r or 1, selected and g or 1, selected and b or 1)
        end
        row:SetScript("OnClick", function()
            state.layoutKey = preset.key
            state.layoutTouched = true
            for _, sibling in ipairs(parent._layoutChoices or {}) do sibling.Update() end
        end)
        row:SetScript("OnEnter", function() SetPreview("layout", "Layout Preset") end)
        parent._layoutChoices = parent._layoutChoices or {}
        parent._layoutChoices[#parent._layoutChoices + 1] = row
        row.Update = Update
        Update()
        return row
    end

    local function BuildModePage()
        local page = MakePage("mode")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Install Type|r")
        local copy = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        copy:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
        copy:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -6)
        copy:SetJustifyH("LEFT")
        copy:SetText("Fresh install applies OakUI exactly as shipped. Selective update lets existing users refresh only chosen EUI sections.")
        MakeChoice(page, "Fresh Install", "Import complete OakUI EUI data, visibility, chat layout, rounded borders, and the optional addon profiles you choose.", "mode", "fresh", -66, 64)
        MakeChoice(page, "Selective Update", "Use when updating OakUI. To preserve personal customizations, import only modules or sections you have not personalized.", "mode", "selective", -138, 76)
        return page
    end

    local function BuildLayoutPage()
        local page = MakePage("layout")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Layout Preset|r")

        local copy = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        copy:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
        copy:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -6)
        copy:SetJustifyH("LEFT")
        copy:SetText("Sets EUI's UI scale preset while preserving imported EUI anchors. Element sizes are not scaled.")

        local recommendedLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        recommendedLabel:SetPoint("TOPLEFT", copy, "BOTTOMLEFT", 0, -14)

        local alternateLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        alternateLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -142)
        alternateLabel:SetText(cWrap .. "Alternate Resolutions|r")

        page.RefreshLayoutChoices = function()
            for _, btn in ipairs(page._layoutChoices or {}) do
                btn:Hide()
                btn:SetParent(nil)
            end
            page._layoutChoices = {}

            local recommendedGroup, alternatives, detected, recommended
            if addonTable.GetOakLayoutPresetGroups then
                recommendedGroup, alternatives, detected, recommended = addonTable.GetOakLayoutPresetGroups()
            end
            if not recommendedGroup or #recommendedGroup == 0 then
                local presets = addonTable.GetOakLayoutPresets and addonTable.GetOakLayoutPresets() or {}
                recommended = presets[1]
                recommendedGroup = recommended and { recommended } or {}
                alternatives = {}
                for index = 2, #presets do alternatives[#alternatives + 1] = presets[index] end
            end

            if recommended and not state.layoutTouched then
                state.layoutKey = recommended.key
            end

            local detectedLabel = "Your Resolution"
            if type(detected) == "table" and detected.width and detected.height then
                detectedLabel = detectedLabel .. " (" .. detected.width .. "x" .. detected.height .. ")"
            end
            recommendedLabel:SetText(cWrap .. detectedLabel .. "|r")

            for index, preset in ipairs(recommendedGroup or {}) do
                local col = (index - 1) % 2
                local row = math.floor((index - 1) / 2)
                MakeLayoutChoice(page, preset, col * 216, -78 - (row * 56))
            end

            local recommendedRows = math.max(1, math.ceil(#(recommendedGroup or {}) / 2))
            local alternateY = -86 - (recommendedRows * 56)
            alternateLabel:ClearAllPoints()
            alternateLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, alternateY)

            for index, preset in ipairs(alternatives or {}) do
                local col = (index - 1) % 2
                local row = math.floor((index - 1) / 2)
                MakeLayoutChoice(page, preset, col * 216, alternateY - 26 - (row * 56))
            end
        end
        page.RefreshLayoutChoices()
        return page
    end

    local function BuildProfilesPage()
        local page = MakePage("profiles")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Profiles|r")

        local dpsBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
        dpsBox:SetSize(190, 22)
        dpsBox:SetPoint("TOPLEFT", page, "TOPLEFT", 185, -42)
        dpsBox:SetAutoFocus(false)
        dpsBox:SetText(state.profiles.dps)
        dpsBox:SetScript("OnTextChanged", function(self) state.profiles.dps = TrimText(self:GetText()) end)
        local healsBox = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
        healsBox:SetSize(190, 22)
        healsBox:SetPoint("TOPLEFT", page, "TOPLEFT", 185, -88)
        healsBox:SetAutoFocus(false)
        healsBox:SetText(state.profiles.heals)
        healsBox:SetScript("OnTextChanged", function(self) state.profiles.heals = TrimText(self:GetText()) end)

        local roleRows = {}
        local function UpdateRoleRows()
            for _, row in ipairs(roleRows) do
                if row.UpdateState then row:UpdateState() end
            end
        end
        roleRows[1] = MakeCheckbox(page, "Tank/DPS Profile", "Import this profile.", function() return state.roles.dps end, function(v)
            state.roles.dps = v == true
            if not state.roles.dps and not state.roles.heals then state.roles.heals = true end
            UpdateRoleRows()
        end, -42, 0, "profiles-dps")
        roleRows[2] = MakeCheckbox(page, "Healer Profile", "Import this profile.", function() return state.roles.heals end, function(v)
            state.roles.heals = v == true
            if not state.roles.dps and not state.roles.heals then state.roles.dps = true end
            UpdateRoleRows()
        end, -88, 0, "profiles-healer")
        MakeCheckbox(page, "Assign Profiles To Specs", "Use EUI's existing spec profile assignment so healer specs use the Healer profile and other specs use Tank/DPS.", function() return state.autoAssign end, function(v) state.autoAssign = v end, -140, 0, "profiles-auto")
        return page
    end

    local function BuildAddonsPage()
        local page = MakePage("addons")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Addon Profiles|r")

        local copy = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        copy:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
        copy:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -8)
        copy:SetJustifyH("LEFT")
        copy:SetText("Choose which optional third-party addon profiles OakUI should install. Uncheck anything you have customized and want to keep.")

        local y = -64
        if IsOptionalProfileReady("dbm") then
            MakeCheckbox(page, "Install DBM Profile", "Imports OakUI's DBM profile and positions DBM Large bars above the target frame.", function() return state.optionalProfiles.dbm end, function(v) state.optionalProfiles.dbm = v end, y, 0, "addons")
            y = y - 48
        else
            state.optionalProfiles.dbm = false
        end
        if IsOptionalProfileReady("bigwigs") then
            MakeCheckbox(page, "Install BigWigs Profile", "Imports OakUI's BigWigs profile and timeline settings.", function() return state.optionalProfiles.bigwigs end, function(v) state.optionalProfiles.bigwigs = v end, y, 0, "addons")
            y = y - 48
        else
            state.optionalProfiles.bigwigs = false
        end
        if IsOptionalProfileReady("blizzi") then
            MakeCheckbox(page, "Install Blizzi Profile", "Imports Blizzi Party Tools profiles matching the selected EUI profile names.", function() return state.optionalProfiles.blizzi end, function(v) state.optionalProfiles.blizzi = v end, y, 0, "addons")
            y = y - 48
        else
            state.optionalProfiles.blizzi = false
        end
        if IsOptionalProfileReady("wmarker") then
            MakeCheckbox(page, "Install wMarker Profile", "Imports OakUI's raid marker, ready check, and countdown layout into wMarker.", function() return state.optionalProfiles.wmarker end, function(v) state.optionalProfiles.wmarker = v end, y, 0, "addons")
            y = y - 48
        else
            state.optionalProfiles.wmarker = false
        end
        if y == -64 then
            local none = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            none:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -66)
            none:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -66)
            none:SetJustifyH("LEFT")
            none:SetTextColor(0.72, 0.72, 0.72)
            none:SetText("No supported optional addon profiles are available. Install and enable DBM, BigWigs, Blizzi Party Tools, or wMarker to import those profiles.")
        end
        return page
    end

    local function BuildSelectivePage()
        local page = MakePage("selective")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Selective Import|r")

        local selectAll = MakeFlatButton(page, "Select All", 92, 22)
        selectAll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
        local recommended = MakeFlatButton(page, "Recommended", 112, 22)
        recommended:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
        local clear = MakeFlatButton(page, "Clear", 76, 22)
        clear:SetPoint("LEFT", recommended, "RIGHT", 8, 0)

        local scroll = CreateFrame("ScrollFrame", "OakUI_GuidedSelectiveScroll", page, "UIPanelScrollFrameTemplate")
        local child = CreateFrame("Frame", nil, scroll)
        scroll:SetScrollChild(child)
        scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -58)
        scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -18, 0)
        child:SetWidth(380)
        SkinScrollbar(scroll)
        scroll:SetScript("OnSizeChanged", function(self, width) child:SetWidth(width) end)

        local rows = {}
        local function RefreshRows()
            for id, row in pairs(rows) do
                if row.Update then row.Update() end
            end
        end
        local function AddNode(node, depth, y)
            if node.header then
                local header = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
                header:SetText(cWrap .. (node.label or node.id) .. "|r")
                y = y - 22
            else
                local row = MakeCheckbox(child, node.label or node.id, node.description, function()
                    return state.selection[node.id] == true
                end, function(value)
                    state.selection[node.id] = value or nil
                end, y, depth * 16, "selective")
                rows[node.id] = row
                y = y - row:GetHeight() - 3
            end
            for _, childNode in ipairs(node.children or {}) do
                y = AddNode(childNode, depth + 1, y)
            end
            return y
        end

        local y = -2
        for _, node in ipairs(addonTable.EllesmereSelectiveTree or {}) do
            y = AddNode(node, 0, y)
        end
        child:SetHeight(math.abs(y) + 10)

        selectAll:SetScript("OnClick", function() state.selection = SelectionPreset("all"); RefreshRows() end)
        recommended:SetScript("OnClick", function() state.selection = SelectionPreset("recommended"); RefreshRows() end)
        clear:SetScript("OnClick", function() state.selection = {}; RefreshRows() end)
        return page
    end

    local function BuildVisibilityPage()
        local page = MakePage("visibility")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Visibility|r")
        MakeCheckbox(page, "Chat Window Layout", "Reapply OakUI's saved chat window positions and tabs.", function() return state.chatLayout end, function(v) state.chatLayout = v end, -38, 0, "visibility-chatlayout")
        MakeCheckbox(page, "Hide Chat", "Hide the chat background and use OakUI's chat fade choice.", function() return state.visibility.chat end, function(v) state.visibility.chat = v end, -78, 0, "visibility-chat")
        MakeCheckbox(page, "Hide Unit Frames", "Hide player/pet frames without a target using EUI visibility settings.", function() return state.visibility.unitFrames end, function(v) state.visibility.unitFrames = v end, -118, 0, "visibility-unitframes")
        MakeCheckbox(page, "Show Player In Group", "If unit frames are hidden, show the player frame while in a party or raid.", function() return state.visibility.showPlayerInGroup end, function(v) state.visibility.showPlayerInGroup = v end, -158, 0, "visibility-playergroup")
        MakeCheckbox(page, "Hide Cooldown Manager", "Hide EUI CDM and resource bars without a target.", function() return state.visibility.cdm end, function(v) state.visibility.cdm = v end, -198, 0, "visibility-cdm")
        MakeCheckbox(page, "Hide Action Bars", "Use mouseover visibility for EUI action bars.", function() return state.visibility.actionBars end, function(v) state.visibility.actionBars = v end, -238, 0, "visibility-actionbars")
        MakeCheckbox(page, "Chat Line Fade", "Use Blizzard per-line fading instead of EUI full-text idle fade.", function() return state.visibility.chatLineFade and not state.visibility.disableChatFade end, function(v) state.visibility.chatLineFade = v; if v then state.visibility.disableChatFade = false end end, -288, 0, "visibility-chatfade")
        MakeCheckbox(page, "Disable Chat Fade", "Set EUI Idle Fade Strength to 0 and keep chat visible.", function() return state.visibility.disableChatFade end, function(v) state.visibility.disableChatFade = v; if v then state.visibility.chatLineFade = false end end, -328, 0, "visibility-chatvisible")
        return page
    end

    local function BuildRoundedPage()
        local page = MakePage("rounded")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Rounded Borders|r")
        MakeCheckbox(page, "OakUI Rounded Borders", "Apply OakUI's rounded border renderer to supported EUI frames, bars, Dragon Riding bars, nameplates, boss mods, damage meters, and Blizzi interrupts.", function() return state.rounded.all end, function(v) state.rounded.all = v end, -42, 0, "rounded")
        return page
    end

    local reviewText
    local function BuildReviewPage()
        local page = MakePage("review")
        local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
        heading:SetText(cWrap .. "Review|r")
        reviewText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        reviewText:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
        reviewText:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -10)
        reviewText:SetJustifyH("LEFT")
        reviewText:SetJustifyV("TOP")
        return page
    end

    BuildModePage()
    BuildLayoutPage()
    BuildProfilesPage()
    BuildAddonsPage()
    BuildSelectivePage()
    BuildVisibilityPage()
    BuildRoundedPage()
    BuildReviewPage()

    local backBtn = MakeFlatButton(parentFrame, "Back", 92, 28)
    backBtn:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 15, 12)
    local nextBtn = MakeFlatButton(parentFrame, "Next", 112, 28)
    nextBtn:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -15, 12)
    nextBtn.Text:SetTextColor(r, g, b)

    local function StepKey()
        return stepOrder[currentStep]
    end

    local function GetRoleSummary()
        if state.roles.dps and state.roles.heals then return state.profiles.dps .. " and " .. state.profiles.heals end
        if state.roles.heals then return state.profiles.heals end
        return state.profiles.dps
    end

    local function UpdateReview()
        if not reviewText then return end
        local mode = state.mode == "fresh" and "Fresh Install" or "Selective Update"
        local sections = state.mode == "fresh" and "All EUI sections" or "Selected EUI sections"
        local auto = state.autoAssign and state.roles.dps and state.roles.heals and "Enabled" or "Skipped"
        local layoutPreset = addonTable.GetOakLayoutPresets and addonTable.GetOakLayoutPresets()
        local layoutLabel = "OakUI Native"
        for _, preset in ipairs(layoutPreset or {}) do
            if preset.key == state.layoutKey then
                layoutLabel = preset.label
                break
            end
        end
        local function HiddenShown(value)
            return value and "Hidden" or "Shown"
        end
        reviewText:SetText(
            cWrap .. "Install Type:|r " .. mode .. "\n" ..
            cWrap .. "Layout Preset:|r " .. layoutLabel .. "\n" ..
            cWrap .. "Profiles:|r " .. GetRoleSummary() .. "\n" ..
            cWrap .. "Import Scope:|r " .. sections .. "\n" ..
            cWrap .. "EUI Spec Assignment:|r " .. auto .. "\n\n" ..
            cWrap .. "Addon Profiles:|r DBM " .. (state.optionalProfiles.dbm and "Install" or "Skip") ..
            ", BigWigs " .. (state.optionalProfiles.bigwigs and "Install" or "Skip") ..
            ", Blizzi " .. (state.optionalProfiles.blizzi and "Install" or "Skip") ..
            ", wMarker " .. (state.optionalProfiles.wmarker and "Install" or "Skip") .. "\n" ..
            cWrap .. "Chat Layout:|r " .. (state.chatLayout and "Apply" or "Skip") .. "\n" ..
            cWrap .. "Visibility:|r Chat " .. HiddenShown(state.visibility.chat) ..
            ", Unit Frames " .. HiddenShown(state.visibility.unitFrames) ..
            ", Player In Group " .. (state.visibility.showPlayerInGroup and "Shown" or "Normal") ..
            ", Cooldown Manager " .. HiddenShown(state.visibility.cdm) ..
            ", Action Bars " .. HiddenShown(state.visibility.actionBars) .. "\n" ..
            cWrap .. "Rounded Borders:|r " .. (state.rounded.all and "On" or "Off") .. "\n\n" ..
            "Click Install to apply these choices. OakUI will prompt you to reload when it finishes."
        )
    end

    local function NormalizeStep(step)
        if step < 1 then return 1 end
        if step > #stepOrder then return #stepOrder end
        if stepOrder[step] == "selective" and state.mode ~= "selective" then
            return NormalizeStep(step + (step > currentStep and 1 or -1))
        end
        return step
    end

    local function ShowStep(step)
        currentStep = NormalizeStep(step)
        for key, page in pairs(pages) do
            if key == StepKey() then page:Show() else page:Hide() end
        end
        local key = StepKey()
        stepLabel:SetText("Step " .. currentStep .. " of " .. #stepOrder)
        backBtn:SetShown(currentStep > 1)
        nextBtn.Text:SetText(key == "review" and "Install" or "Next")
        if key == "layout" and pages.layout and pages.layout.RefreshLayoutChoices then
            pages.layout.RefreshLayoutChoices()
        end
        if key == "review" then UpdateReview() end
        SetPreview(key, key == "mode" and "Install Type" or key == "layout" and "Layout Preset" or key == "profiles" and "Profiles" or key == "addons" and "Addon Profiles" or key == "selective" and "Selective Import" or key == "visibility" and "Visibility" or key == "rounded" and "Rounded Borders" or "Review")
    end

    function addonTable.ResetOakGuidedInstaller()
        ResetInstallerState()
        ShowStep(1)
    end

    local function ApplyOptionalProfile(addon, role)
        if not addon or not addon.func or not IsAddonReady(addon.folder) then return end
        local profileName = role == "heals" and state.profiles.heals or state.profiles.dps
        local ok, err = pcall(addon.func, profileName, role)
        if not ok then
            print("|cffff0000[OakUI] Error installing " .. addon.name .. ":|r " .. tostring(err))
        end
    end

    local installerModal
    local function ShowOakInstallerModal(options)
        options = options or {}
        if not installerModal then
            local rootFrame = _G.OakUIProfileManager or parentFrame:GetParent() or UIParent
            installerModal = CreateFrame("Frame", "OakUI_InstallerModal", rootFrame, "BackdropTemplate")
            installerModal:SetSize(430, 174)
            installerModal:SetPoint("CENTER", rootFrame, "CENTER", 0, 0)
            installerModal:SetFrameStrata("FULLSCREEN_DIALOG")
            installerModal:SetFrameLevel((rootFrame.GetFrameLevel and rootFrame:GetFrameLevel() or 900) + 80)
            installerModal:SetToplevel(true)
            installerModal:EnableMouse(true)
            installerModal:SetMovable(true)
            installerModal:RegisterForDrag("LeftButton")
            installerModal:SetScript("OnDragStart", function(self) self:StartMoving() end)
            installerModal:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
            installerModal:Hide()
            installerModal:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
            installerModal:SetBackdropColor(0.106, 0.106, 0.129, 0.98)
            installerModal:SetBackdropBorderColor(r, g, b, 1)

            installerModal.Text = installerModal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            installerModal.Text:SetPoint("TOPLEFT", installerModal, "TOPLEFT", 24, -24)
            installerModal.Text:SetPoint("TOPRIGHT", installerModal, "TOPRIGHT", -24, -24)
            installerModal.Text:SetJustifyH("CENTER")
            installerModal.Text:SetJustifyV("MIDDLE")
            installerModal.Text:SetTextColor(1, 1, 1)

            installerModal.Accept = MakeFlatButton(installerModal, "Okay", 144, 26)
            installerModal.Accept:SetPoint("BOTTOMRIGHT", installerModal, "BOTTOM", -6, 18)
            installerModal.Accept:SetFrameLevel(installerModal:GetFrameLevel() + 20)
            installerModal.Accept:EnableMouse(true)
            installerModal.Accept:RegisterForClicks("AnyUp")

            installerModal.Cancel = MakeFlatButton(installerModal, "Cancel", 144, 26)
            installerModal.Cancel:SetPoint("BOTTOMLEFT", installerModal, "BOTTOM", 6, 18)
            installerModal.Cancel:SetFrameLevel(installerModal:GetFrameLevel() + 20)
            installerModal.Cancel:EnableMouse(true)
            installerModal.Cancel:RegisterForClicks("AnyUp")
        end

        local modalParent = installerModal:GetParent()
        installerModal:SetFrameLevel((modalParent and modalParent.GetFrameLevel and modalParent:GetFrameLevel() or 900) + 80)
        installerModal.Accept:SetFrameLevel(installerModal:GetFrameLevel() + 20)
        installerModal.Cancel:SetFrameLevel(installerModal:GetFrameLevel() + 20)
        installerModal:SetHeight(options.height or 174)
        installerModal:SetBackdropBorderColor(r, g, b, 1)
        installerModal.Text:SetText(options.text or "")
        installerModal.Accept.Text:SetText(options.acceptText or "Okay")
        installerModal.Cancel.Text:SetText(options.cancelText or "Cancel")
        installerModal.Cancel:SetShown(options.cancelText ~= false)

        installerModal.Accept:SetScript("OnClick", function()
            installerModal:Hide()
            if type(options.onAccept) == "function" then options.onAccept() end
        end)
        installerModal.Cancel:SetScript("OnClick", function()
            installerModal:Hide()
            if type(options.onCancel) == "function" then options.onCancel() end
        end)

        if options.cancelText == false then
            installerModal.Accept:ClearAllPoints()
            installerModal.Accept:SetPoint("BOTTOM", installerModal, "BOTTOM", 0, 18)
        else
            installerModal.Accept:ClearAllPoints()
            installerModal.Accept:SetPoint("BOTTOMRIGHT", installerModal, "BOTTOM", -6, 18)
        end

        installerModal:Show()
        if installerModal.Raise then installerModal:Raise() end
        return installerModal
    end

    local function BlockInstallInCombat()
        if not (InCombatLockdown and InCombatLockdown()) then return false end
        ShowOakInstallerModal({
            text = "OakUI cannot install profiles while you are in combat.\n\nLeave combat and run the install again.",
            acceptText = "Okay",
            cancelText = false,
        })
        return true
    end

    local function AddExistingProfile(existing, seen, profileName)
        profileName = TrimText(profileName)
        if profileName == "" or seen[profileName] then return end
        local db = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB
        local profiles = db and db.profiles
        if type(profiles) == "table" and type(profiles[profileName]) == "table" then
            seen[profileName] = true
            table.insert(existing, profileName)
        end
    end

    local function GetFreshInstallExistingProfiles()
        local existing, seen = {}, {}
        if state.mode ~= "fresh" then return existing end
        if state.roles.dps then AddExistingProfile(existing, seen, state.profiles.dps) end
        if state.roles.heals then AddExistingProfile(existing, seen, state.profiles.heals) end
        return existing
    end

    local function DeleteFreshInstallProfiles(profileNames)
        if type(profileNames) ~= "table" then return true end
        if not _G.EllesmereUI or type(_G.EllesmereUI.DeleteProfile) ~= "function" then
            print("|cffff0000[OakUI]|r EllesmereUI profile delete API is unavailable. Install cancelled.")
            return false
        end

        for _, profileName in ipairs(profileNames) do
            if profileName == "Default" then
                print("|cffff0000[OakUI]|r OakUI will not overwrite EllesmereUI's Default profile. Choose another profile name.")
                ShowStep(3)
                return false
            end
        end

        for _, profileName in ipairs(profileNames) do
            local ok, err = pcall(_G.EllesmereUI.DeleteProfile, profileName)
            if not ok then
                print("|cffff0000[OakUI]|r Could not delete existing EllesmereUI profile '" .. tostring(profileName) .. "': " .. tostring(err))
                return false
            end
        end
        return true
    end

    local function ConfirmFreshInstallOverwriteIfNeeded(continueFunc)
        local existing = GetFreshInstallExistingProfiles()
        if #existing == 0 then return false end

        for _, profileName in ipairs(existing) do
            if profileName == "Default" then
                print("|cffff0000[OakUI]|r OakUI will not overwrite EllesmereUI's Default profile. Choose another profile name.")
                ShowStep(3)
                return true
            end
        end

        ShowOakInstallerModal({
            text = "Fresh install will overwrite the existing EllesmereUI profile(s):\n\n" .. table.concat(existing, "\n") .. "\n\nDelete the old profile data and continue?",
            acceptText = "Overwrite",
            cancelText = "Cancel",
            height = 188,
            onAccept = function()
                if DeleteFreshInstallProfiles(existing) then
                    continueFunc()
                end
            end,
        })
        return true
    end

    local function ApplyInstall(skipFreshOverwriteCheck)
        if BlockInstallInCombat() then return end

        if not state.roles.dps and not state.roles.heals then
            print("|cffff0000[OakUI]|r Select at least one profile to import.")
            ShowStep(2)
            return
        end

        if not skipFreshOverwriteCheck and ConfirmFreshInstallOverwriteIfNeeded(function()
            ApplyInstall(true)
        end) then
            return
        end

        local selection = state.mode == "fresh" and { all = true } or state.selection
        if addonTable.SetOakLayoutPreset then
            addonTable.SetOakLayoutPreset(state.layoutKey)
        end

        -- Set the rounded-border preference before importing profile strings.
        -- The import hooks then normalize every imported profile using the
        -- same preference, including opt-out fallback borders.
        if addonTable.ApplyOakInstallerRoundedBorders then
            addonTable.ApplyOakInstallerRoundedBorders(state.rounded)
        end

        local importedDPS, importedHeals
        local chatLayoutApplied = false
        if state.mode == "fresh" then
            if state.roles.dps then
                local ok, err = pcall(Inj.Ellesmere, state.profiles.dps, "dps")
                importedDPS = ok
                if not ok then print("|cffff0000[OakUI] Error importing Tank/DPS EUI profile:|r " .. tostring(err)) end
            end
            if state.roles.heals then
                local ok, err = pcall(Inj.Ellesmere, state.profiles.heals, "heals")
                importedHeals = ok
                if not ok then print("|cffff0000[OakUI] Error importing Healer EUI profile:|r " .. tostring(err)) end
            end
        else
            if state.roles.dps then
                importedDPS = addonTable.ApplyOakEllesmereProfileImport(state.profiles.dps, "dps", selection, false)
            end
            if state.roles.heals then
                importedHeals = addonTable.ApplyOakEllesmereProfileImport(state.profiles.heals, "heals", selection, false)
            end
        end

        if state.mode == "fresh" then
            if Inj.EditMode then pcall(Inj.EditMode) end
            if addonTable.ApplyOakFontPreset then pcall(addonTable.ApplyOakFontPreset) end
        end

        if addonTable.RegisterOakRoleProfileName then
            if importedDPS then addonTable.RegisterOakRoleProfileName("dps", state.profiles.dps) end
            if importedHeals then addonTable.RegisterOakRoleProfileName("heals", state.profiles.heals) end
        end

        if state.chatLayout then
            if addonTable.ScheduleChatWindowsAfterEllesmereProfile then
                chatLayoutApplied = addonTable.ScheduleChatWindowsAfterEllesmereProfile(true) == true
            elseif addonTable.SetupChatWindows then
                chatLayoutApplied = addonTable.SetupChatWindows(true) == true
            end
        end

        if state.autoAssign and state.roles.dps and state.roles.heals and addonTable.AssignOakEllesmereProfilesToSpecs then
            addonTable.AssignOakEllesmereProfilesToSpecs(state.profiles.dps, state.profiles.heals)
        end

        if addonTable.ApplyOakInstallerVisibilityTweaks then
            addonTable.ApplyOakInstallerVisibilityTweaks(state.visibility)
        end
        if addonTable.ApplyOakInstallerRoundedBorders then
            addonTable.ApplyOakInstallerRoundedBorders(state.rounded)
        end

        for _, addon in ipairs(FlagshipAddons) do
            if addon.name == "Blizzi Party Tools (Optional)" then
                if state.optionalProfiles.blizzi then
                    if state.roles.dps then ApplyOptionalProfile(addon, "dps") end
                    if state.roles.heals then ApplyOptionalProfile(addon, "heals") end
                end
            elseif addon.name == "DBM (Optional)" or addon.name == "BigWigs (Optional)" then
                if addon.name == "DBM (Optional)" and state.optionalProfiles.dbm then
                    ApplyOptionalProfile(addon, "dps")
                elseif addon.name == "BigWigs (Optional)" and state.optionalProfiles.bigwigs then
                    ApplyOptionalProfile(addon, "dps")
                end
            elseif addon.name == "wMarker (Optional)" and state.optionalProfiles.wmarker then
                ApplyOptionalProfile(addon, "dps")
            end
        end

        if addonTable.SetOakInstallActiveEllesmereProfile and (importedDPS or importedHeals) then
            local ok, err = pcall(
                addonTable.SetOakInstallActiveEllesmereProfile,
                state.profiles.dps,
                state.profiles.heals,
                importedDPS == true,
                importedHeals == true
            )
            if not ok then
                print("|cffff0000[OakUI]|r Could not set active EllesmereUI profile after install: " .. tostring(err))
            end
        end

        if addonTable.MarkInstallerComplete and (importedDPS or importedHeals) then
            addonTable.MarkInstallerComplete()
        end
        if state.mode == "fresh" and (importedDPS or importedHeals) and addonTable.MarkEllesmereCDMRepopulateAfterReload then
            addonTable.MarkEllesmereCDMRepopulateAfterReload()
        end
        if state.chatLayout and chatLayoutApplied then
            if addonTable.MarkOakChatGeometryAfterReload then
                addonTable.MarkOakChatGeometryAfterReload()
            elseif addonTable.MarkOakChatLayoutAfterReload then
                addonTable.MarkOakChatLayoutAfterReload()
            end
        end
        local function ShowReloadPrompt()
            ShowOakInstallerModal({
                text = "OakUI install is complete.\n\nReload your UI now?",
                acceptText = "Reload UI",
                cancelText = "Later",
                onAccept = function()
                    if ReloadUI then ReloadUI() end
                end,
            })
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, ShowReloadPrompt)
        else
            ShowReloadPrompt()
        end
    end

    function addonTable.ApplyOakQuickInstall(options)
        ResetInstallerState({
            mode = "fresh",
            dps = options and options.dps,
            heals = options and options.heals,
            dpsProfile = options and options.dpsProfile,
            healsProfile = options and options.healsProfile,
            autoAssign = options and options.autoAssign,
            layoutKey = options and options.layoutKey or "native",
            selectionMode = "all",
            chatLayout = true,
            optionalProfiles = options and options.optionalProfiles,
        })
        ApplyInstall()
    end

    backBtn:SetScript("OnClick", function() ShowStep(currentStep - 1) end)
    nextBtn:SetScript("OnClick", function()
        if StepKey() == "review" then
            ApplyInstall()
        else
            ShowStep(currentStep + 1)
        end
    end)

    parentFrame:SetScript("OnShow", function() ShowStep(currentStep) end)
    ShowStep(1)
end
