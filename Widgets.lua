local addonName, addonTable = ...
local Inj = addonTable.Injectors

local _, playerClass = UnitClass("player")
local classColor = C_ClassColor.GetClassColor(playerClass)
local r, g, b = classColor.r, classColor.g, classColor.b
local cWrap = "|c" .. classColor:GenerateHexColor()

-- Expose core colors to other files
addonTable.cWrap = cWrap
addonTable.colors = { r = r, g = g, b = b }

-- ==========================================
-- GLOBAL UI HELPERS
-- ==========================================
function addonTable.SkinScrollbar(scrollFrame)
    local sb = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and (scrollFrame:GetName().."ScrollBar")]
    if sb then
        local function NukeButton(btn)
            if btn then btn:Hide(); btn:SetNormalTexture(""); btn:SetPushedTexture(""); btn:SetHighlightTexture(""); btn:SetDisabledTexture(""); btn.Show = function() end end
        end
        NukeButton(sb.ScrollUpButton or _G[sb:GetName().."ScrollUpButton"])
        NukeButton(sb.ScrollDownButton or _G[sb:GetName().."ScrollDownButton"])
        
        local name = sb:GetName()
        if name then
            for _, part in ipairs({"Top", "Bottom", "Middle"}) do
                local tex = _G[name..part]
                if tex then tex:Hide(); tex.Show = function() end end
            end
        end
        local thumb = sb:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            thumb:SetVertexColor(r, g, b, 0.8)
            thumb:SetSize(4, 40)
        end
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 15, -15)
        sb:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 15, 15)
    end
end

function addonTable.MakeFlatButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.2, 0.22, 0.28, 1); btn.bg = bg
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); btn.Text:SetPoint("CENTER"); btn.Text:SetText(text)
    btn:SetScript("OnEnter", function(self) if self:IsEnabled() then self.bg:SetColorTexture(0.3, 0.32, 0.38, 1) end end)
    btn:SetScript("OnLeave", function(self) if self:IsEnabled() then self.bg:SetColorTexture(0.2, 0.22, 0.28, 1) end end)
    btn.DisableStyle = function(self) 
        self.bg:SetColorTexture(0.1, 0.1, 0.1, 1); self.Text:SetTextColor(0.4, 0.4, 0.4)
        if self.Text:GetText() == "Installed" or self.Text:GetText() == "Applied!" or self.Text:GetText() == "Copied!" then self.Text:SetTextColor(0.1, 1, 0.1) end
    end
    btn.EnableStyle = function(self) self.bg:SetColorTexture(0.2, 0.22, 0.28, 1); self.Text:SetTextColor(1, 1, 1) end
    hooksecurefunc(btn, "Disable", btn.DisableStyle); hooksecurefunc(btn, "Enable", btn.EnableStyle)
    return btn
end

function addonTable.MakeFlatCheckbox(parent, text, dbKey)
    local btn = CreateFrame("Button", nil, parent); btn:SetSize(20, 20)
    local border = btn:CreateTexture(nil, "BACKGROUND"); border:SetAllPoints(); border:SetColorTexture(0.3, 0.32, 0.38, 1)
    local inner = btn:CreateTexture(nil, "ARTWORK"); inner:SetPoint("TOPLEFT", 2, -2); inner:SetPoint("BOTTOMRIGHT", -2, 2)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); label:SetPoint("LEFT", btn, "RIGHT", 10, 0); label:SetText(text)
    btn.UpdateState = function(self)
        if OakUI_DB.chatFilters[dbKey] then inner:SetColorTexture(r, g, b, 1) else inner:SetColorTexture(0.137, 0.141, 0.172, 1) end
    end
    btn:SetScript("OnClick", function(self)
        OakUI_DB.chatFilters[dbKey] = not OakUI_DB.chatFilters[dbKey]
        self:UpdateState()
    end)
    return btn
end

-- ==========================================
-- DIALOG FRAMES (COPY, ROLE, RELOAD)
-- ==========================================
local CopyFrame = CreateFrame("Frame", "OakUI_StandaloneCopyFrame", UIParent, "BackdropTemplate")
CopyFrame:SetSize(450, 160); CopyFrame:SetPoint("CENTER"); 
CopyFrame:SetFrameStrata("FULLSCREEN_DIALOG"); CopyFrame:Hide() -- FIX: Elevated to float over OakUI Main
CopyFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 }); CopyFrame:SetBackdropColor(0.137, 0.141, 0.172, 1); CopyFrame:SetBackdropBorderColor(r, g, b, 1) 
local CopyTitle = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); CopyTitle:SetPoint("TOP", 0, -15); CopyTitle:SetText(cWrap .. "Action Required|r")
local CopyDesc = CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); CopyDesc:SetPoint("TOP", CopyTitle, "BOTTOM", 0, -15); CopyDesc:SetWidth(410); CopyDesc:SetJustifyH("CENTER")
local EditBox = CreateFrame("EditBox", nil, CopyFrame, "InputBoxTemplate"); EditBox:SetSize(380, 30); EditBox:SetPoint("TOP", CopyDesc, "BOTTOM", 0, -15); EditBox:SetAutoFocus(false)
EditBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end); EditBox:SetScript("OnEscapePressed", function() CopyFrame:Hide() end)
local CloseCopyBtn = addonTable.MakeFlatButton(CopyFrame, "Close", 100, 26); CloseCopyBtn:SetPoint("BOTTOM", 0, 15); CloseCopyBtn:SetScript("OnClick", function() CopyFrame:Hide() end)

function addonTable.ShowCopyBox(text, instructions)
    if not text or text == "" then text = "No string found!" end
    CopyDesc:SetText(instructions or "Press CTRL+C to copy the string below:")
    EditBox:SetText(text); CopyFrame:Show(); EditBox:ClearFocus()
end

local ProfilePromptFrame = CreateFrame("Frame", "OakUI_ProfilePromptFrame", UIParent, "BackdropTemplate")
ProfilePromptFrame:SetSize(400, 220); ProfilePromptFrame:SetPoint("CENTER", UIParent, "CENTER"); 
ProfilePromptFrame:SetFrameStrata("FULLSCREEN_DIALOG"); ProfilePromptFrame:Hide() -- FIX: Elevated to float over OakUI Main
ProfilePromptFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 }); ProfilePromptFrame:SetBackdropColor(0.137, 0.141, 0.172, 1); ProfilePromptFrame:SetBackdropBorderColor(r, g, b, 1)
local PromptTitle = ProfilePromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); PromptTitle:SetPoint("TOP", 0, -15); PromptTitle:SetText(cWrap .. "Profile Installation|r")
local PendingRole = "dps"
local RoleContainer = CreateFrame("Frame", nil, ProfilePromptFrame); RoleContainer:SetSize(260, 30); RoleContainer:SetPoint("TOP", PromptTitle, "BOTTOM", 0, -15)
local RoleDPSBtn = addonTable.MakeFlatButton(RoleContainer, "Tank / DPS", 125, 30); RoleDPSBtn:SetPoint("LEFT", 0, 0)
local RoleHealBtn = addonTable.MakeFlatButton(RoleContainer, "Healer", 125, 30); RoleHealBtn:SetPoint("RIGHT", 0, 0)
local PromptDesc = ProfilePromptFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); PromptDesc:SetPoint("TOP", RoleContainer, "BOTTOM", 0, -15); PromptDesc:SetText("Enter a profile name to safely inject this setup:")
local PromptEditBox = CreateFrame("EditBox", nil, ProfilePromptFrame, "InputBoxTemplate"); PromptEditBox:SetSize(250, 30); PromptEditBox:SetPoint("TOP", PromptDesc, "BOTTOM", 0, -10); PromptEditBox:SetAutoFocus(true)
PromptEditBox:SetScript("OnEscapePressed", function() ProfilePromptFrame:Hide() end)

local function UpdateRoleVisuals(role)
    PendingRole = role or PendingRole or "dps"
    local isHealer = PendingRole == "heals"
    RoleDPSBtn.bg:SetColorTexture(isHealer and 0.2 or r, isHealer and 0.22 or g, isHealer and 0.28 or b, isHealer and 1 or 0.5)
    RoleDPSBtn.Text:SetTextColor(isHealer and r or 1, isHealer and g or 1, isHealer and b or 1)
    RoleHealBtn.bg:SetColorTexture(isHealer and r or 0.2, isHealer and g or 0.22, isHealer and b or 0.28, isHealer and 0.5 or 1)
    RoleHealBtn.Text:SetTextColor(isHealer and 1 or r, isHealer and 1 or g, isHealer and 1 or b)
    PromptEditBox:SetText(isHealer and "OakUI-Healer" or "OakUI-Tank/DPS")
end
RoleDPSBtn:SetScript("OnClick", function() UpdateRoleVisuals("dps") end); RoleHealBtn:SetScript("OnClick", function() UpdateRoleVisuals("heals") end)
local InstallBtn = addonTable.MakeFlatButton(ProfilePromptFrame, "Install", 100, 26); InstallBtn:SetPoint("BOTTOMRIGHT", ProfilePromptFrame, "BOTTOM", -5, 15); InstallBtn.Text:SetTextColor(r, g, b)
local CancelBtn = addonTable.MakeFlatButton(ProfilePromptFrame, "Cancel", 100, 26); CancelBtn:SetPoint("BOTTOMLEFT", ProfilePromptFrame, "BOTTOM", 5, 15); CancelBtn:SetScript("OnClick", function() ProfilePromptFrame:Hide() end)

local ReloadPromptFrame = CreateFrame("Frame", "OakUI_ReloadPromptFrame", UIParent, "BackdropTemplate")
ReloadPromptFrame:SetSize(420, 160); ReloadPromptFrame:SetPoint("CENTER", UIParent, "CENTER"); 
ReloadPromptFrame:SetFrameStrata("TOOLTIP"); ReloadPromptFrame:Hide() -- TOOLTIP is highest possible
ReloadPromptFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 }); ReloadPromptFrame:SetBackdropColor(0.137, 0.141, 0.172, 1); ReloadPromptFrame:SetBackdropBorderColor(r, g, b, 1)
local ReloadTitle = ReloadPromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); ReloadTitle:SetPoint("TOP", 0, -15); ReloadTitle:SetText(cWrap .. "OAK UI|r")
local ReloadDesc = ReloadPromptFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); ReloadDesc:SetPoint("TOP", ReloadTitle, "BOTTOM", 0, -15); ReloadDesc:SetJustifyH("CENTER")
local DoReloadBtn = addonTable.MakeFlatButton(ReloadPromptFrame, "Reload UI", 140, 26); DoReloadBtn:SetPoint("BOTTOMRIGHT", ReloadPromptFrame, "BOTTOM", -5, 15)
local LaterBtn = addonTable.MakeFlatButton(ReloadPromptFrame, "Later", 100, 26); LaterBtn:SetPoint("BOTTOMLEFT", ReloadPromptFrame, "BOTTOM", 5, 15); LaterBtn:SetScript("OnClick", function() ReloadPromptFrame:Hide() end)

function addonTable.ShowReloadPrompt(message, buttonText, buttonFunc)
    ReloadDesc:SetText(message or "A UI Reload is required to apply the changes.")
    DoReloadBtn.Text:SetText(buttonText or "Reload UI")
    DoReloadBtn:SetScript("OnClick", function()
        if type(buttonFunc) == "function" then
            buttonFunc()
        else
            ReloadUI()
        end
    end)
    ReloadPromptFrame:Show()
end

local function ShowCompletionPrompt()
    ReloadDesc:SetText("Profile(s) injected successfully!\n\nReload your UI to finish applying OakUI.")
    DoReloadBtn.Text:SetText("Reload UI")
    DoReloadBtn:SetScript("OnClick", function() ReloadUI() end)
    ReloadPromptFrame:Show()
end

-- ==========================================
-- INSTALLATION LOGIC ENGINE
-- ==========================================
local PendingInstallFunc, PendingInstallAddon, PendingAddonList, PendingIsAll = nil, nil, nil, false
local function InstallCallback(requiresReload) if requiresReload or PendingIsAll then ShowCompletionPrompt() end end
function addonTable.ShowInstallCompletionPrompt()
    ShowCompletionPrompt()
end

local function DoInstallAction()
    ProfilePromptFrame:Hide()
    local profileName = PromptEditBox:GetText()
    if not profileName or profileName == "" then profileName = "OakUI" end
    
    if PendingIsAll then 
        local installedCount = Inj.ExecuteInstallAll(PendingAddonList, profileName, PendingRole, InstallCallback)
        if installedCount and installedCount > 0 and addonTable.MarkInstallerComplete then addonTable.MarkInstallerComplete() end
    else 
        local success, err = pcall(PendingInstallFunc, profileName, PendingRole)
        if not success then print("|cffff0000[OakUI] Error installing profile:|r " .. tostring(err)) end
        if PendingInstallAddon.rowBtn then PendingInstallAddon.rowBtn:SetText(PendingInstallAddon.installedText or "Installed"); PendingInstallAddon.rowBtn:Disable() end
        if PendingInstallAddon.rowBtn2 then PendingInstallAddon.rowBtn2:SetText("Installed"); PendingInstallAddon.rowBtn2:Disable() end
        if PendingInstallAddon.requiresReload then InstallCallback(true) end
    end
end
InstallBtn:SetScript("OnClick", DoInstallAction); PromptEditBox:SetScript("OnEnterPressed", DoInstallAction)

function Inj.ExecuteInstallAll(addonList, profileName, role, callback)
    local anyReload = false
    local installedCount = 0
    for i, addon in ipairs(addonList) do
        local isReady = true
        if addon.folder then
            local name, _, _, _, reason = C_AddOns.GetAddOnInfo(addon.folder)
            local isLoaded = C_AddOns.IsAddOnLoaded(addon.folder)
            local state = C_AddOns.GetAddOnEnableState(addon.folder) 
            
            if not name or reason == "MISSING" then
                isReady = false
            elseif state == 0 and not isLoaded then
                isReady = false
            end
        end
        
        if isReady and (not addon.manual or addon.includeInAll) then
            local success, err = pcall(addon.func, profileName, role)
            if not success then
                print("|cffff0000[OakUI] Error installing " .. addon.name .. ":|r " .. tostring(err))
            else
                if addon.rowBtn then addon.rowBtn:SetText(addon.installedText or "Installed"); addon.rowBtn:Disable() end
                if addon.rowBtn2 then addon.rowBtn2:SetText("Installed"); addon.rowBtn2:Disable() end
                if addon.requiresReload then anyReload = true end
                installedCount = installedCount + 1
            end
        end
    end
    if addonTable.ApplyOakFontPreset then
        local success, err = pcall(addonTable.ApplyOakFontPreset)
        if success then
            anyReload = true
        else
            print("|cffff0000[OakUI] Error applying OakUI fonts:|r " .. tostring(err))
        end
    end
    if addonTable.ApplyOakVisibilityDefaults then
        local success, err = pcall(addonTable.ApplyOakVisibilityDefaults)
        if success then
            anyReload = true
        else
            print("|cffff0000[OakUI] Error applying OakUI visibility defaults:|r " .. tostring(err))
        end
    end
    if callback then callback(anyReload) end
    return installedCount
end

function addonTable.QuickInstallAll(profileName, role)
    if not profileName and not role and addonTable.ShowProfilePrompt then
        addonTable.ShowProfilePrompt(true, addonTable.FlagshipAddons or {}, nil, nil)
        return 0
    end

    profileName = profileName or "OakUI"
    role = role or "dps"

    local installedCount = Inj.ExecuteInstallAll(addonTable.FlagshipAddons or {}, profileName, role, nil)
    if installedCount and installedCount > 0 and addonTable.MarkInstallerComplete then
        addonTable.MarkInstallerComplete()
    end
    ShowCompletionPrompt()
    return installedCount
end

function addonTable.ShowProfilePrompt(isAll, addonList, singleAddon, singleFunc, forcedRole)
    PendingIsAll = isAll; PendingAddonList = addonList; PendingInstallAddon = singleAddon; PendingInstallFunc = singleFunc
    local showRoles = singleAddon and singleAddon.hasRoles
    if isAll and addonList then
        for _, addon in ipairs(addonList) do
            if addon.hasRoles then
                showRoles = true
                break
            end
        end
    end

    UpdateRoleVisuals(forcedRole or "dps")
    if showRoles then
        RoleContainer:Show()
        PromptDesc:ClearAllPoints()
        PromptDesc:SetPoint("TOP", RoleContainer, "BOTTOM", 0, -15)
        ProfilePromptFrame:SetHeight(220)
    else
        RoleContainer:Hide()
        PromptDesc:ClearAllPoints()
        PromptDesc:SetPoint("TOP", PromptTitle, "BOTTOM", 0, -15)
        ProfilePromptFrame:SetHeight(180)
        PromptEditBox:SetText("OakUI")
    end
    ProfilePromptFrame:Show(); PromptEditBox:HighlightText(); PromptEditBox:SetFocus()
end
