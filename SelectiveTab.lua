local addonName, addonTable = ...
local P = addonTable.Profiles

-- Helper to fetch QUI's private core engine where the API actually lives
local function GetQUICore()
    if type(_G.QUI) == "table" and type(_G.QUI.QUICore) == "table" then
        return _G.QUI.QUICore
    end
    return nil
end

function addonTable.BuildSelectiveUI(parentFrame)
    local cWrap = addonTable.cWrap
    local r, g, b = addonTable.colors.r, addonTable.colors.g, addonTable.colors.b
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Selective QUI Import|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10)
    Desc:SetJustifyH("LEFT")
    Desc:SetText("Advanced: Choose exactly which modules of the OakUI profile you want to import. The category list is generated from your installed QUI version, so it matches the selective import options QUI currently supports.")

    -- Added Instruction Label
    local RoleHint = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    RoleHint:SetPoint("TOPLEFT", Desc, "BOTTOMLEFT", 0, -15)
    RoleHint:SetText(cWrap .. "Step 1:|r Select the source profile you want to import data from:")

    -- Role Selection Container
    local PendingRole = "dps"
    local RoleContainer = CreateFrame("Frame", nil, parentFrame)
    RoleContainer:SetSize(300, 30)
    RoleContainer:SetPoint("TOPLEFT", RoleHint, "BOTTOMLEFT", 0, -10)

    local RoleDPSBtn = MakeFlatButton(RoleContainer, "Tank / DPS Profile", 145, 30)
    RoleDPSBtn:SetPoint("LEFT", 0, 0)
    local RoleHealBtn = MakeFlatButton(RoleContainer, "Healer Profile", 145, 30)
    RoleHealBtn:SetPoint("RIGHT", 0, 0)

    -- Scrolling Category List
    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_SelectiveScroll", parentFrame, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    ScrollFrame:SetPoint("TOPLEFT", RoleContainer, "BOTTOMLEFT", 0, -15)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 60)
    SkinScrollbar(ScrollFrame)

    -- Explicit Error Label
    local errorLabel = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    errorLabel:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 10, -10)
    errorLabel:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -10, -10)
    errorLabel:SetJustifyH("LEFT")
    errorLabel:Hide()

    local selectedIDs = {}
    local checkRows = {}
    local rootRows = {}
    local RefreshAllStates, UpdateLayout

    -- Custom Checkbox Factory
    local function MakeCategoryCheckbox(parent, text, descText, initial, id, indent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(45)
        row.childRows = {} 
        row.originalDesc = descText -- Store original so we can append instructions
        
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        row.bg = bg

        local btn = CreateFrame("Button", nil, row)
        btn:SetSize(20, 20)
        btn:SetPoint("LEFT", row, "LEFT", indent, 0)
        
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0.3, 0.32, 0.38, 1)
        local inner = btn:CreateTexture(nil, "ARTWORK")
        inner:SetPoint("TOPLEFT", 2, -2)
        inner:SetPoint("BOTTOMRIGHT", -2, 2)
        
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        label:SetPoint("LEFT", btn, "RIGHT", 10, 2)
        label:SetText(text)
        
        local sub = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
        sub:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        sub:SetJustifyH("LEFT")
        sub:SetText(descText)
        sub:SetTextColor(0.6, 0.6, 0.6)
        row.sub = sub

        btn.isChecked = initial and true or false
        btn.UpdateState = function(self)
            if self.isChecked then 
                inner:SetColorTexture(r, g, b, 1) 
                selectedIDs[id] = true
            else 
                inner:SetColorTexture(0.137, 0.141, 0.172, 1) 
                selectedIDs[id] = nil
            end
        end
        btn:UpdateState()

        btn:SetScript("OnClick", function(self)
            self.isChecked = not self.isChecked
            self:UpdateState()
            if RefreshAllStates then RefreshAllStates() end 
        end)
        
        row.btn = btn
        return row
    end

    -- DYNAMIC LAYOUT ENGINE
    UpdateLayout = function()
        local yOffset = -5
        local visibleCount = 0
        
        local function LayoutRow(row)
            if row.isHiddenByParent then
                row:Hide()
                return
            end
            
            visibleCount = visibleCount + 1
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset)
            row:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", 0, yOffset)
            
            -- Recalculate alternating backgrounds so there are no visual gaps
            if visibleCount % 2 == 1 then 
                row.bg:SetColorTexture(0.2, 0.22, 0.28, 0.4) 
            else 
                row.bg:SetColorTexture(0,0,0,0) 
            end
            
            yOffset = yOffset - 45
            
            -- Recursively layout children
            for _, childRow in ipairs(row.childRows) do
                LayoutRow(childRow)
            end
        end
        
        for _, row in ipairs(rootRows) do
            LayoutRow(row)
        end
        
        ScrollChild:SetHeight(math.abs(yOffset))
    end

    -- THE CASCADE LOGIC
    local function CascadeState(row, hiddenByAncestor)
        row.isHiddenByParent = hiddenByAncestor
        
        -- If parent is checked, children are hidden and unchecked (preventing double-imports)
        local hideChildren = hiddenByAncestor or row.btn.isChecked
        
        for _, childRow in ipairs(row.childRows) do
            if hideChildren then
                childRow.btn.isChecked = false
                childRow.btn:UpdateState()
            end
            CascadeState(childRow, hideChildren)
        end
        
        -- Dynamic Instructional Text
        if #row.childRows > 0 then
            if row.btn.isChecked then
                row.sub:SetText(row.originalDesc .. " |cffeed200(Uncheck to show specific options)|r")
            else
                row.sub:SetText(row.originalDesc)
            end
        end
    end

    RefreshAllStates = function()
        for _, row in ipairs(rootRows) do
            CascadeState(row, false)
        end
        UpdateLayout()
    end

    -- Core Logic: Analyze the string and build the UI
    local function RefreshCategories()
        for _, row in ipairs(checkRows) do row:Hide() end
        checkRows = {}
        rootRows = {}
        selectedIDs = {}
        errorLabel:Hide()
        
        local str = (PendingRole == "dps") and P.QUI_PROFILE or P.QUI_PROFILE_HEALS
        
        if not str or str == "" then
            errorLabel:SetText("|cffff0000Error:|r Profile string is missing from Profiles.lua.")
            errorLabel:Show(); ScrollChild:SetHeight(100); return
        end
        
        local core = GetQUICore()
        if not core or not core.AnalyzeProfileImportString then
            errorLabel:SetText("|cffff0000Error:|r QUI is not loaded, or you are using an outdated version of QUI that lacks Selective Import.")
            errorLabel:Show(); ScrollChild:SetHeight(100); return
        end

        local ok, preview = core:AnalyzeProfileImportString(str)
        if not ok then
            errorLabel:SetText("|cffff0000String Analysis Failed:|r\n" .. tostring(preview))
            errorLabel:Show(); ScrollChild:SetHeight(150); return
        end

        -- Recursive function to build the Parent -> Child tree
        local function RenderCat(cat, indent, parentRow)
            if not cat.available then return end
            
            local row = MakeCategoryCheckbox(ScrollChild, cWrap..cat.label.."|r", cat.description or "", cat.recommended, cat.id, indent)
            table.insert(checkRows, row)
            
            if parentRow then
                table.insert(parentRow.childRows, row)
            else
                table.insert(rootRows, row)
            end
            
            if type(cat.children) == "table" then
                for _, child in ipairs(cat.children) do
                    RenderCat(child, indent + 20, row)
                end
            end
        end
        
        for _, cat in ipairs(preview.categories) do
            RenderCat(cat, 10, nil)
        end
        
        RefreshAllStates() -- This triggers layout placement and cascading
    end

    -- Window Resize Hook
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height) 
        ScrollChild:SetWidth(width) 
        UpdateLayout()
    end)

    -- Switch Role Data
    local function UpdateRoleVisuals()
        if PendingRole == "dps" then
            RoleDPSBtn.bg:SetColorTexture(r, g, b, 0.5); RoleDPSBtn.Text:SetTextColor(1, 1, 1)
            RoleHealBtn.bg:SetColorTexture(0.2, 0.22, 0.28, 1); RoleHealBtn.Text:SetTextColor(r, g, b)
        else
            RoleHealBtn.bg:SetColorTexture(r, g, b, 0.5); RoleHealBtn.Text:SetTextColor(1, 1, 1)
            RoleDPSBtn.bg:SetColorTexture(0.2, 0.22, 0.28, 1); RoleDPSBtn.Text:SetTextColor(r, g, b)
        end
        RefreshCategories()
    end
    RoleDPSBtn:SetScript("OnClick", function() PendingRole = "dps"; UpdateRoleVisuals() end)
    RoleHealBtn:SetScript("OnClick", function() PendingRole = "heals"; UpdateRoleVisuals() end)

    -- Bottom Controls
    local ImportBtn = MakeFlatButton(parentFrame, "IMPORT SELECTED", 160, 30)
    ImportBtn:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 15)
    ImportBtn.Text:SetTextColor(r, g, b)
    
    local SelectAllBtn = MakeFlatButton(parentFrame, "Select All", 100, 30)
    SelectAllBtn:SetPoint("RIGHT", ImportBtn, "LEFT", -10, 0)
    
    local SelectNoneBtn = MakeFlatButton(parentFrame, "Select None", 100, 30)
    SelectNoneBtn:SetPoint("RIGHT", SelectAllBtn, "LEFT", -10, 0)

    SelectAllBtn:SetScript("OnClick", function()
        for _, row in ipairs(rootRows) do 
            row.btn.isChecked = true; row.btn:UpdateState() 
        end
        RefreshAllStates()
    end)
    
    SelectNoneBtn:SetScript("OnClick", function()
        for _, row in ipairs(checkRows) do 
            row.btn.isChecked = false; row.btn:UpdateState() 
        end
        RefreshAllStates()
    end)

    -- Execution Trigger
    ImportBtn:SetScript("OnClick", function()
        local ids = {}
        for id, _ in pairs(selectedIDs) do table.insert(ids, id) end
        
        if #ids == 0 then 
            print("|cffff0000[OakUI]|r You must select at least one category to import!")
            return 
        end
        
        local str = (PendingRole == "dps") and P.QUI_PROFILE or P.QUI_PROFILE_HEALS
        local core = GetQUICore()
        
        if not str or not core or not core.ImportProfileSelectionFromString then
            print("|cffff0000[OakUI]|r Selective Import API is missing from QUI.")
            return
        end

        local ok, err = core:ImportProfileSelectionFromString(str, ids)
        if ok then
            StaticPopupDialogs["OAKUI_SELECTIVE_RELOAD"] = {
                text = "Selective Import successful! A UI Reload is required to apply the changes. Reload now?",
                button1 = "Yes", button2 = "No",
                OnAccept = function() ReloadUI() end,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
            StaticPopup_Show("OAKUI_SELECTIVE_RELOAD")
        else
            print("|cffff0000[OakUI]|r Import failed: " .. tostring(err))
        end
    end)

    parentFrame:SetScript("OnShow", function() UpdateRoleVisuals() end)
end
