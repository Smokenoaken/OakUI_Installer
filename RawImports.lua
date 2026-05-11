local addonName, addonTable = ...
local P = addonTable.Profiles

function addonTable.BuildRawImportsUI(parentFrame)
    local cWrap = addonTable.cWrap
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar 

    local RawTitle = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    RawTitle:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    RawTitle:SetJustifyH("LEFT")
    RawTitle:SetText(cWrap .. "Raw Imports|r")

    local RawDesc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    RawDesc:SetPoint("TOPLEFT", RawTitle, "BOTTOMLEFT", 0, -10)
    RawDesc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10) -- Dynamic stretch
    RawDesc:SetJustifyH("LEFT")
    RawDesc:SetText("Manual fallback strings if the auto-installer fails.")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_RawImportsScroll", parentFrame, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    ScrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -80)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 20) 
    
    -- Dynamically stretch child width
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end)
    ScrollChild:SetWidth(ScrollFrame:GetWidth() or 470)

    SkinScrollbar(ScrollFrame) 

    local imports = {
        { name = "Blizzard Edit Mode", var = P.EDITMODE_PROFILE, desc = "Copy this string and import it in Blizzard Edit Mode (Escape > Edit Mode > Layout dropdown > Import)." },
        { name = "Base UI Profile (Tank/DPS)", var = (P.BASE_UI_PROVIDER == "Ellesmere") and P.ELLESMERE_PROFILE or P.ELVUI_PROFILE, desc = "Manual fallback string for the selected base UI profile." },
        { name = "ElvUI Private (Tank/DPS)", var = P.ELVUI_PRIVATE, desc = "Manual fallback string for ElvUI's private profile import." },
        { name = "Base UI Profile (Healer)", var = (P.BASE_UI_PROVIDER == "Ellesmere") and P.ELLESMERE_PROFILE_HEALS or P.ELVUI_PROFILE_HEALS, desc = "Manual fallback string for the selected base UI healer profile." },
        { name = "ElvUI Private (Healer)", var = P.ELVUI_PRIVATE_HEALS, desc = "Manual fallback string for ElvUI's healer private profile import." },
        { name = "Ayije CDM", var = P.AYIJE_CDM_PROFILE, desc = "Import this into Ayije CDM's import/profile settings." },
        { name = "Chonky Character Sheet", var = P.CHONKY_PROFILE, desc = "Import this into Chonky Character Sheet's profile import box." },
        { name = "MPlusTimer", var = P.MPLUSTIMER_PROFILE, desc = "Import this into MPlusTimer's profile import field." },
        { name = "Details! Damage Meter", var = P.DETAILS_PROFILE, desc = "Import this into Details! Options > Profiles > Import Profile." },
        { name = "Platynator", var = P.PLATYNATOR_PROFILE, desc = "Import this into the Plater / Platynator profiles tab." },
        { name = "XIV_Databar Continued", var = P.XIV_PROFILE, desc = "Import this into the XIV_Databar profiles section." },
        { name = "BigWigs", var = P.BIGWIGS_PROFILE, desc = "Import this into BigWigs profile settings." },
    }

    local activeEditBoxes = {} 
    local yOffset = -10
    
    for i, data in ipairs(imports) do
        local title = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
        title:SetText(data.name)
        title:SetTextColor(1, 0.82, 0)
        
        -- Lock description vertical spacing so resizing doesn't cause overlap bugs
        local desc = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        desc:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -15, 0) -- Stretches text to window
        desc:SetJustifyH("LEFT")
        desc:SetText(data.desc)
        desc:SetTextColor(0.8, 0.8, 0.8)
        
        yOffset = yOffset - 40 -- Fixed gap between title and box

        local boxBg = CreateFrame("Frame", nil, ScrollChild, "BackdropTemplate")
        boxBg:SetHeight(80)
        -- Dynamic stretch!
        boxBg:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
        boxBg:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -5, yOffset)
        boxBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        boxBg:SetBackdropColor(0.08, 0.08, 0.1, 1)
        boxBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        local editBoxScroll = CreateFrame("ScrollFrame", "OakUI_RawEditScroll_"..i, boxBg, "UIPanelScrollFrameTemplate")
        editBoxScroll:SetPoint("TOPLEFT", boxBg, "TOPLEFT", 8, -8)
        editBoxScroll:SetPoint("BOTTOMRIGHT", boxBg, "BOTTOMRIGHT", -20, 8)
        SkinScrollbar(editBoxScroll) 
        
        local editBox = CreateFrame("EditBox", nil, editBoxScroll)
        editBox:SetMultiLine(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetAutoFocus(false)
        editBox:SetText(data.var or "String not found. Please check Profiles.lua.")
        editBox:SetScript("OnChar", function(self) self:SetText(data.var or "") end)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editBoxScroll:SetScrollChild(editBox)

        -- Make the internal text box dynamically expand with its parent
        editBoxScroll:SetScript("OnSizeChanged", function(self, width, height) editBox:SetWidth(width) end)
        editBox:SetWidth(editBoxScroll:GetWidth() or 410)

        table.insert(activeEditBoxes, editBox)

        yOffset = yOffset - 90

        local btn = MakeFlatButton(ScrollChild, "SELECT ALL", 100, 24)
        btn:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
        btn:SetScript("OnClick", function()
            for _, box in ipairs(activeEditBoxes) do
                box:ClearFocus()
                box:HighlightText(0, 0)
            end
            editBox:SetFocus()
            editBox:HighlightText()
        end)

        local helper = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        helper:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        helper:SetText("then press Ctrl-C to copy")
        helper:SetTextColor(0.5, 0.5, 0.5)

        yOffset = yOffset - 40 
    end
    
    ScrollChild:SetHeight(math.abs(yOffset))
end
