local addonName, addonTable = ...

function addonTable.BuildInstallerUI(parentFrame)
    local Inj = addonTable.Injectors
    local P = addonTable.Profiles
    local cWrap = addonTable.cWrap
    local r, g, b = addonTable.colors.r, addonTable.colors.g, addonTable.colors.b
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar
    local ShowCopyBox = addonTable.ShowCopyBox
    local ShowProfilePrompt = addonTable.ShowProfilePrompt

    local ListView = parentFrame

    local ListTitle = ListView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    ListTitle:SetPoint("TOPLEFT", ListView, "TOPLEFT", 15, -20)
    ListTitle:SetJustifyH("LEFT")
    ListTitle:SetText(cWrap .. "Main Installer|r")

    local ListDesc = ListView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ListDesc:SetPoint("TOPLEFT", ListTitle, "BOTTOMLEFT", 0, -10)
    ListDesc:SetPoint("TOPRIGHT", ListView, "TOPRIGHT", -15, -10)
    ListDesc:SetJustifyH("LEFT")
    ListDesc:SetJustifyV("TOP")
    
    -- The new friendly warning
    ListDesc:SetText("The definitive OAK experience built around the selected base UI framework.\n\n" ..
                     cWrap .. "Heads up:|r Using this tab will overwrite your current settings for supported addons.\n\n" ..
                     "Install individual profiles, or click 'Install All Profiles' at the bottom. Reload when installation is complete.")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_InstallerScroll", ListView, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    
    -- Pushed down from -135 to -175 to make room for the new warning text
    ScrollFrame:SetPoint("TOPLEFT", ListView, "TOPLEFT", 15, -175) 
    ScrollFrame:SetPoint("BOTTOMRIGHT", ListView, "BOTTOMRIGHT", -30, 50)
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end)
    ScrollChild:SetWidth(ScrollFrame:GetWidth() or 470)
    SkinScrollbar(ScrollFrame)

    local InstallAllBtn = MakeFlatButton(ListView, "Install All Profiles", 160, 30)
    InstallAllBtn:SetPoint("BOTTOMRIGHT", ListView, "BOTTOMRIGHT", -30, 10)
    InstallAllBtn.Text:SetTextColor(r, g, b) 

    local baseFolder = "EllesmereUI"
    local baseUrl = "https://www.curseforge.com/wow/addons/ellesmere-ui"
    local editModeAddon = { name = "Blizzard Edit Mode (Layout)", folder = nil, buttonText = "Import Layout", installedText = "Imported!", func = function()
        if Inj.EditMode and Inj.EditMode() then return end
        ShowCopyBox(Inj.GetEditMode(), cWrap .. "1.|r Press CTRL+C to copy the text below.\n" .. cWrap .. "2.|r Open ESC -> Edit Mode.\n" .. cWrap .. "3.|r Click the Layout Dropdown -> Import -> Paste.")
    end, manual = true, includeInAll = true, requiresReload = true }
    local chatLayoutAddon = { name = "OakUI Chat Layout", folder = nil, buttonText = "Apply Layout", installedText = "Applied!", func = function()
        if addonTable.ScheduleChatWindowsAfterEllesmereProfile then
            addonTable.ScheduleChatWindowsAfterEllesmereProfile(true)
        elseif addonTable.SetupChatWindows then
            addonTable.SetupChatWindows(true)
        end
    end, requiresReload = true, manual = true, includeInAll = true }
    local FlagshipAddons = {
        { name = "Ellesmere UI Profile", folder = baseFolder, url = baseUrl, func = Inj.BaseUI, requiresReload = true },
        editModeAddon,
        chatLayoutAddon,
        { name = "Danders Frames", folder = "DandersFrames", url = "https://www.curseforge.com/wow/addons/danders-frames", func = Inj.Danders, requiresReload = true, hasRoles = true },
        { name = "Platynator", folder = "Platynator", url = "https://www.curseforge.com/wow/addons/platynator", func = Inj.Platynator },
        { name = "XIV_Databar Continued", folder = "XIV_Databar_Continued", url = "https://www.curseforge.com/wow/addons/xiv-databar-continued", func = Inj.XIV },
        { name = "BigWigs (Optional)", folder = "BigWigs", url = "https://www.curseforge.com/wow/addons/big-wigs", func = Inj.BigWigs, requiresReload = false },
    }
    addonTable.FlagshipAddons = FlagshipAddons

    local DeprecatedAddons = {}

    local activeRows, deprecatedRows, isDeprecatedExpanded = {}, {}, false
    local DeprecatedHeader = CreateFrame("Button", nil, ScrollChild); DeprecatedHeader:SetHeight(26)
    local dhBg = DeprecatedHeader:CreateTexture(nil, "BACKGROUND"); dhBg:SetAllPoints(); dhBg:SetColorTexture(0.15, 0.15, 0.18, 1)
    local dhText = DeprecatedHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); dhText:SetPoint("CENTER"); dhText:SetText("Deprecated Installs ▼"); dhText:SetTextColor(0.6, 0.6, 0.6)
    DeprecatedHeader:SetScript("OnEnter", function() dhBg:SetColorTexture(0.2, 0.22, 0.28, 1) dhText:SetTextColor(0.8, 0.8, 0.8) end)
    DeprecatedHeader:SetScript("OnLeave", function() dhBg:SetColorTexture(0.15, 0.15, 0.18, 1) dhText:SetTextColor(0.6, 0.6, 0.6) end)

    local function LayoutRows()
        local yOffset = 0
        for _, row in ipairs(activeRows) do row:ClearAllPoints(); row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset); row:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", 0, yOffset); row:Show(); yOffset = yOffset - 40 end
        if #deprecatedRows > 0 then
            yOffset = yOffset - 10; DeprecatedHeader:ClearAllPoints(); DeprecatedHeader:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset); DeprecatedHeader:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", 0, yOffset); DeprecatedHeader:Show(); yOffset = yOffset - 26
            if isDeprecatedExpanded then
                dhText:SetText("Deprecated Installs ▲")
                for _, row in ipairs(deprecatedRows) do row:ClearAllPoints(); row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset); row:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", 0, yOffset); row:Show(); yOffset = yOffset - 40 end
            else
                dhText:SetText("Deprecated Installs ▼"); for _, row in ipairs(deprecatedRows) do row:Hide() end
            end
        else DeprecatedHeader:Hide() end
        ScrollChild:SetHeight(math.abs(yOffset))
    end
    DeprecatedHeader:SetScript("OnClick", function() isDeprecatedExpanded = not isDeprecatedExpanded; LayoutRows() end)

    local function CreateAddonRow(addon, isDeprecated, index)
        local row = CreateFrame("Frame", nil, ScrollChild); row:SetHeight(40) 
        local rbg = row:CreateTexture(nil, "BACKGROUND"); rbg:SetAllPoints(); if index % 2 == 1 then rbg:SetColorTexture(0.2, 0.22, 0.28, 0.4) else rbg:SetColorTexture(0,0,0,0) end
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); row.name:SetPoint("LEFT", 10, 0)
        row.btn = MakeFlatButton(row, "Install", 120, 26); row.btn:SetPoint("RIGHT", row, "RIGHT", -5, 0); addon.rowBtn = row.btn
        local row2btn = MakeFlatButton(row, "Healer", 85, 26); row2btn:SetPoint("RIGHT", row, "RIGHT", -5, 0); row2btn:Hide(); addon.rowBtn2 = row2btn
        addon.rowFrame = row; return row
    end

    for i, addon in ipairs(FlagshipAddons) do table.insert(activeRows, CreateAddonRow(addon, false, i)) end
    for i, addon in ipairs(DeprecatedAddons) do table.insert(deprecatedRows, CreateAddonRow(addon, true, i)) end
    InstallAllBtn:SetScript("OnClick", function() ShowProfilePrompt(true, FlagshipAddons, nil, nil) end); LayoutRows()

    local function UpdateAddonState(addon, isDeprecated)
        local row = addon.rowFrame; local isInstalled, isEnabled = true, true
        if addon.folder then
            local name, _, _, _, reason = C_AddOns.GetAddOnInfo(addon.folder)
            local isLoaded = C_AddOns.IsAddOnLoaded(addon.folder)
            local state = C_AddOns.GetAddOnEnableState(addon.folder)
            
            if not name or reason == "MISSING" then 
                isInstalled = false; isEnabled = false 
            elseif state == 0 and not isLoaded then 
                isEnabled = false 
            end
        end
        
        local displayName = addon.name
        if isDeprecated then displayName = "|cff888888" .. addon.name .. " (Deprecated)|r" end
        
        if not isInstalled then
            row.name:SetText(displayName .. " |cffff5555(Missing)|r"); row.btn:Enable(); row.btn.Text:SetText("Get Link"); row.btn.Text:SetTextColor(0.6, 0.6, 0.6)
            row.btn:SetScript("OnClick", function() ShowCopyBox(addon.url or "No URL found.", "Addon is missing from your AddOns folder!\nCopy the link below to download it:") end)
            if addon.rowBtn2 then addon.rowBtn2:Hide() end
        elseif not isEnabled then
            row.name:SetText(displayName .. " |cffffff55(Disabled)|r"); if addon.rowBtn2 then addon.rowBtn2:Hide() end
            row.btn:Enable(); row.btn:SetWidth(120); row.btn:ClearAllPoints(); row.btn:SetPoint("RIGHT", row, "RIGHT", -5, 0); row.btn.Text:SetText("Force Enable"); row.btn.Text:SetTextColor(r, g, b)
            row.btn:SetScript("OnClick", function() C_AddOns.EnableAddOn(addon.folder, UnitName("player")); ReloadUI() end)
        else
            row.name:SetText(displayName)
            if addon.hasRoles then
                addon.rowBtn2:Show(); addon.rowBtn:SetWidth(95); addon.rowBtn:ClearAllPoints(); addon.rowBtn:SetPoint("RIGHT", addon.rowBtn2, "LEFT", -5, 0); addon.rowBtn:Enable(); addon.rowBtn2:Enable()
                addon.rowBtn.Text:SetText("Tank/DPS"); addon.rowBtn.Text:SetTextColor(r, g, b); addon.rowBtn2.Text:SetText("Healer"); addon.rowBtn2.Text:SetTextColor(r, g, b)
                addon.rowBtn:SetScript("OnClick", function() ShowProfilePrompt(false, nil, addon, addon.func, "dps") end)
                addon.rowBtn2:SetScript("OnClick", function() ShowProfilePrompt(false, nil, addon, addon.func, "heals") end)
            else
                if addon.rowBtn2 then addon.rowBtn2:Hide() end
                addon.rowBtn:SetWidth(120); addon.rowBtn:ClearAllPoints(); addon.rowBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0); addon.rowBtn:Enable(); addon.rowBtn.Text:SetText(addon.buttonText or "Install"); addon.rowBtn.Text:SetTextColor(r, g, b)
                addon.rowBtn:SetScript("OnClick", function() 
                    if addon.manual then 
                        local success, err = pcall(addon.func)
                        if not success then
                            print("|cffff0000[OakUI] Error applying " .. addon.name .. ":|r " .. tostring(err))
                            return
                        end

                        addon.rowBtn:SetText(addon.installedText or "Copied/Applied!")
                        addon.rowBtn:Disable()
                        if addon.requiresReload then
                            StaticPopupDialogs["OAKUI_MANUAL_RELOAD"] = {
                                text = "Settings applied successfully! A UI Reload is required. Reload now?",
                                button1 = "Yes", button2 = "No",
                                OnAccept = function() ReloadUI() end,
                                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
                            }
                            StaticPopup_Show("OAKUI_MANUAL_RELOAD")
                        end
                    else 
                        ShowProfilePrompt(false, nil, addon, addon.func, "dps") 
                    end 
                end)
            end
        end
    end

    local function UpdateFlagshipList()
        for _, addon in ipairs(FlagshipAddons) do UpdateAddonState(addon, false) end
        for _, addon in ipairs(DeprecatedAddons) do UpdateAddonState(addon, true) end
    end
    ListView:SetScript("OnShow", UpdateFlagshipList)
    UpdateFlagshipList() -- Initialize on load
end
