local addonName, addonTable = ...

local function ShallowCopyArray(src)
    local out = {}
    for i, item in ipairs(src or {}) do out[i] = item end
    return out
end

function addonTable.BuildEllesmereSelectiveUI(parentFrame)
    local cWrap = addonTable.cWrap
    local colors = addonTable.colors
    local r, g, b = colors.r, colors.g, colors.b
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar

    local selectedRole = "dps"
    local selected = {}
    local rows = {}
    local parentByID = {}
    local childrenByID = {}
    local allNodes = {}
    local scrollChild

    local function RegisterNode(node, parentID)
        if type(node) ~= "table" or not node.id then return end
        allNodes[node.id] = node
        if parentID then
            parentByID[node.id] = parentID
            childrenByID[parentID] = childrenByID[parentID] or {}
            table.insert(childrenByID[parentID], node.id)
        end
        for _, child in ipairs(node.children or {}) do
            RegisterNode(child, node.id)
        end
    end

    local function BuildTreeForRole(role)
        allNodes = {}
        parentByID = {}
        childrenByID = {}

        local tree = {}
        for _, node in ipairs(addonTable.EllesmereSelectiveTree or {}) do
            local copy = {}
            for k, v in pairs(node) do
                if k ~= "children" then copy[k] = v end
            end
            copy.children = ShallowCopyArray(node.children)
            if node.dynamicChildren == "customCdmBars" and addonTable.GetOakEllesmereCustomCdmChildren then
                for _, child in ipairs(addonTable.GetOakEllesmereCustomCdmChildren(role) or {}) do
                    table.insert(copy.children, child)
                end
            end
            table.insert(tree, copy)
        end

        for _, node in ipairs(tree) do RegisterNode(node) end
        return tree
    end

    local function HasSelectedAncestor(id)
        local parentID = parentByID[id]
        while parentID do
            if selected[parentID] then return true end
            parentID = parentByID[parentID]
        end
        return false
    end

    local function HasSelectableAncestor(id)
        local parentID = parentByID[id]
        while parentID do
            local parentNode = allNodes[parentID]
            if parentNode and not parentNode.header then return true end
            parentID = parentByID[parentID]
        end
        return false
    end

    local function HasRecommendedSelectableAncestor(id)
        local parentID = parentByID[id]
        while parentID do
            local parentNode = allNodes[parentID]
            if parentNode and parentNode.recommended and not parentNode.header then return true end
            parentID = parentByID[parentID]
        end
        return false
    end

    local function SetNodeSelected(id, value, silent)
        local node = allNodes[id]
        if node and node.header then return end
        selected[id] = value and true or false
        if selected[id] and parentByID[id] then
            local parentNode = allNodes[parentByID[id]]
            if not (parentNode and parentNode.header) then
                selected[parentByID[id]] = false
            end
        end
        if not silent then
            for rowID, row in pairs(rows) do
                row.SetChecked(selected[rowID])
                local disabled = HasSelectedAncestor(rowID)
                row.SetDisabled(disabled)
            end
        end
    end

    local function SetPreset(mode)
        for id in pairs(allNodes) do selected[id] = false end

        if mode == "all" then
            for id, node in pairs(allNodes) do
                if not node.header and not HasSelectableAncestor(id) then
                    selected[id] = true
                end
            end
        elseif mode == "recommended" then
            for _, node in pairs(allNodes) do
                if node.recommended and not node.header and not HasRecommendedSelectableAncestor(node.id) then
                    selected[node.id] = true
                end
            end
        end

        for rowID, row in pairs(rows) do
            row.SetChecked(selected[rowID])
            row.SetDisabled(HasSelectedAncestor(rowID))
        end
    end

    local function BuildSelection()
        local out = {}
        local count = 0
        local function Collect(node, parentSelected)
            local nodeSelected = selected[node.id] and not node.header
            if nodeSelected and not parentSelected then
                out[node.id] = true
                count = count + 1
                parentSelected = true
            end
            for _, child in ipairs(node.children or {}) do
                Collect(child, parentSelected)
            end
        end
        for _, node in ipairs(scrollChild._tree or {}) do Collect(node, false) end
        return out, count
    end

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -14)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Selective Import|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -4)
    Desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10)
    Desc:SetFontObject("GameFontHighlightSmall")
    Desc:SetJustifyH("LEFT")
    Desc:SetText("Import OakUI's Ellesmere profile string by shared section or by individual Ellesmere addon.")

    local RoleRow = CreateFrame("Frame", nil, parentFrame)
    RoleRow:SetPoint("TOPLEFT", Desc, "BOTTOMLEFT", 0, -7)
    RoleRow:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, 0)
    RoleRow:SetHeight(26)

    local ProfileLabel = RoleRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ProfileLabel:SetPoint("LEFT", RoleRow, "LEFT", 0, 0)
    ProfileLabel:SetText("Profile")

    local ProfileEdit = CreateFrame("EditBox", nil, RoleRow, "InputBoxTemplate")
    ProfileEdit:SetSize(165, 22)
    ProfileEdit:SetPoint("LEFT", ProfileLabel, "RIGHT", 8, 0)
    ProfileEdit:SetAutoFocus(false)

    local RoleDPS = MakeFlatButton(RoleRow, "Tank/DPS", 82, 22)
    RoleDPS:SetPoint("LEFT", ProfileEdit, "RIGHT", 10, 0)
    RoleDPS.Text:SetFontObject(GameFontHighlightSmall)
    local RoleHealer = MakeFlatButton(RoleRow, "Healer", 82, 22)
    RoleHealer:SetPoint("LEFT", RoleDPS, "RIGHT", 6, 0)
    RoleHealer.Text:SetFontObject(GameFontHighlightSmall)

    local PresetRow = CreateFrame("Frame", nil, parentFrame)
    PresetRow:SetPoint("TOPLEFT", RoleRow, "BOTTOMLEFT", 0, -4)
    PresetRow:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, 0)
    PresetRow:SetHeight(24)

    local SelectAll = MakeFlatButton(PresetRow, "SELECT ALL", 104, 22)
    SelectAll:SetPoint("LEFT", PresetRow, "LEFT", 0, 0)
    SelectAll.Text:SetFontObject(GameFontHighlightSmall)
    local Recommended = MakeFlatButton(PresetRow, "RECOMMENDED", 124, 22)
    Recommended:SetPoint("LEFT", SelectAll, "RIGHT", 8, 0)
    Recommended.Text:SetFontObject(GameFontHighlightSmall)
    local Clear = MakeFlatButton(PresetRow, "CLEAR", 82, 22)
    Clear:SetPoint("LEFT", Recommended, "RIGHT", 8, 0)
    Clear.Text:SetFontObject(GameFontHighlightSmall)

    local Note = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    Note:SetPoint("TOPLEFT", PresetRow, "BOTTOMLEFT", 0, -3)
    Note:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, 0)
    Note:SetJustifyH("LEFT")
    Note:SetTextColor(0.62, 0.62, 0.62)
    Note:SetText("Addon checkboxes use EUI's per-addon import model. Recommended leaves shared Theme and Layout unchecked.")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_EllesmereSelectiveScroll", parentFrame, "UIPanelScrollFrameTemplate")
    scrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(scrollChild)
    ScrollFrame:SetPoint("TOPLEFT", Note, "BOTTOMLEFT", 0, -6)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 55)
    scrollChild:SetWidth(ScrollFrame:GetWidth() or 560)
    SkinScrollbar(ScrollFrame)

    local function CreateRow(parent, node, depth, yOffset)
        local row = CreateFrame("Frame", nil, parent)
        local indent = depth * 18
        local isHeader = node.header == true
        row:SetHeight(isHeader and 28 or 26)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset)

        local cb = CreateFrame("Button", nil, row)
        cb:SetSize(16, 16)
        local border = cb:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(r, g, b, 0.8)
        local inner = cb:CreateTexture(nil, "ARTWORK")
        inner:SetPoint("TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", -2, 2)

        local title = row:CreateFontString(nil, "OVERLAY", (isHeader or depth == 0) and "GameFontNormalSmall" or "GameFontHighlightSmall")
        title:SetJustifyH("LEFT")
        title:SetJustifyV("TOP")
        title:SetText(node.label or node.id)

        local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetJustifyH("LEFT")
        desc:SetJustifyV("TOP")
        desc:SetText(node.description or "")

        row.Layout = function(width)
            width = width or parent:GetWidth() or 560
            cb:ClearAllPoints()
            title:ClearAllPoints()
            desc:ClearAllPoints()

            if width < 500 then
                local left = 5 + indent
                local textLeft = isHeader and left or (left + 24)
                local textWidth = math.max(170, width - textLeft - 8)

                cb:SetShown(not isHeader)
                cb:SetPoint("TOPLEFT", row, "TOPLEFT", left, -5)
                title:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -3)
                title:SetWidth(textWidth)
                desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
                desc:SetWidth(textWidth)

                local titleHeight = math.max(11, title:GetStringHeight() or 11)
                local descHeight = math.max(11, desc:GetStringHeight() or 11)
                row:SetHeight(math.max(isHeader and 32 or 30, titleHeight + descHeight + 8))
            else
                local left = 5 + indent
                local titleWidth = math.max(100, math.min(isHeader and 205 or (185 - indent), width * 0.33))
                local descLeft = isHeader and math.max(218, left + titleWidth + 22) or math.max(218, left + 24 + titleWidth + 18)
                local descWidth = math.max(180, width - descLeft - 8)

                cb:SetShown(not isHeader)
                cb:SetPoint("LEFT", row, "LEFT", left, 0)
                if isHeader then
                    title:SetPoint("LEFT", row, "LEFT", left, 0)
                else
                    title:SetPoint("LEFT", cb, "RIGHT", 8, 0)
                end
                title:SetWidth(titleWidth)
                desc:SetPoint("TOPLEFT", row, "TOPLEFT", descLeft, -5)
                desc:SetWidth(descWidth)

                local descHeight = math.max(12, desc:GetStringHeight() or 12)
                row:SetHeight(math.max(isHeader and 28 or 24, descHeight + 8))
            end
        end
        row.Layout(scrollChild and scrollChild:GetWidth())

        local checked = false
        row.SetChecked = function(value)
            checked = value and true or false
            if checked then
                inner:SetColorTexture(r, g, b, 1)
            else
                inner:SetColorTexture(0.08, 0.09, 0.11, 1)
            end
        end
        row.SetDisabled = function(disabled)
            if isHeader then
                row:SetAlpha(1)
                cb:EnableMouse(false)
                title:SetTextColor(r, g, b, 1)
                desc:SetTextColor(0.62, 0.62, 0.62, 1)
                return
            end
            local alpha = disabled and 0.42 or 1
            row:SetAlpha(alpha)
            cb:EnableMouse(not disabled)
            local tr, tg, tb = depth == 0 and r or 0.86, depth == 0 and g or 0.86, depth == 0 and b or 0.86
            if disabled then tr, tg, tb = 0.46, 0.48, 0.52 end
            title:SetTextColor(tr, tg, tb, 1)
            desc:SetTextColor(disabled and 0.42 or 0.62, disabled and 0.44 or 0.62, disabled and 0.48 or 0.62, 1)
        end
        if isHeader then
            cb:EnableMouse(false)
        else
            cb:SetScript("OnClick", function()
                SetNodeSelected(node.id, not checked)
            end)
        end
        row.SetChecked(selected[node.id])
        row.SetDisabled(HasSelectedAncestor(node.id))
        rows[node.id] = row
        return row
    end

    local function RenderTree(resetPreset)
        for _, row in pairs(rows) do row:Hide() end
        rows = {}

        local tree = BuildTreeForRole(selectedRole)
        scrollChild._tree = tree
        local y = -2

        local function RenderNode(node, depth)
            local row = CreateRow(scrollChild, node, depth, y)
            y = y - row:GetHeight() - 2
            for _, child in ipairs(node.children or {}) do
                RenderNode(child, depth + 1)
            end
        end

        for _, node in ipairs(tree) do RenderNode(node, 0) end
        scrollChild:SetHeight(math.abs(y) + 12)
        if resetPreset then
            SetPreset("recommended")
        else
            for rowID, row in pairs(rows) do
                row.SetChecked(selected[rowID])
                row.SetDisabled(HasSelectedAncestor(rowID))
            end
        end
    end

    ScrollFrame:SetScript("OnSizeChanged", function(self, width)
        if not scrollChild then return end
        scrollChild:SetWidth(width)
        if scrollChild._tree then
            RenderTree(false)
        end
    end)

    local function SetRole(role)
        selectedRole = role == "heals" and "heals" or "dps"
        ProfileEdit:SetText(addonTable.GetOakEllesmereRoleProfileName and addonTable.GetOakEllesmereRoleProfileName(selectedRole) or "OakUI")
        local healer = selectedRole == "heals"
        RoleDPS.bg:SetColorTexture(healer and 0.2 or r, healer and 0.22 or g, healer and 0.28 or b, healer and 1 or 0.5)
        RoleHealer.bg:SetColorTexture(healer and r or 0.2, healer and g or 0.22, healer and b or 0.28, healer and 0.5 or 1)
        RenderTree(true)
    end

    RoleDPS:SetScript("OnClick", function() SetRole("dps") end)
    RoleHealer:SetScript("OnClick", function() SetRole("heals") end)

    SelectAll:SetScript("OnClick", function() SetPreset("all") end)
    Recommended:SetScript("OnClick", function() SetPreset("recommended") end)
    Clear:SetScript("OnClick", function() SetPreset("clear") end)

    local ApplySelected = MakeFlatButton(parentFrame, "Apply Selected", 125, 28)
    ApplySelected:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -160, 14)
    ApplySelected.Text:SetTextColor(r, g, b)
    local ApplyAll = MakeFlatButton(parentFrame, "Apply All", 115, 28)
    ApplyAll:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 14)
    ApplyAll.Text:SetTextColor(r, g, b)

    local function PromptReload()
        if addonTable.ShowReloadPrompt then
            addonTable.ShowReloadPrompt("Ellesmere settings were applied.\n\nReload your UI to finish rebuilding all frames.")
        end
    end

    ApplySelected:SetScript("OnClick", function()
        local selection, count = BuildSelection()
        if count == 0 then
            print("|cffff0000[OakUI]|r Select at least one Ellesmere section to import.")
            return
        end
        if addonTable.ApplyOakEllesmereProfileImport and addonTable.ApplyOakEllesmereProfileImport(ProfileEdit:GetText(), selectedRole, selection, false) then
            PromptReload()
        end
    end)

    ApplyAll:SetScript("OnClick", function()
        if addonTable.ApplyOakEllesmereProfileImportAll and addonTable.ApplyOakEllesmereProfileImportAll(ProfileEdit:GetText(), selectedRole, false) then
            PromptReload()
        end
    end)

    SetRole("dps")
end
