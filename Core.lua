local addonName, addonTable = ...
local P = addonTable.Profiles 

-- Fetch Variables passed down from Widgets.lua
local cWrap = addonTable.cWrap
local r, g, b = addonTable.colors.r, addonTable.colors.g, addonTable.colors.b
local MakeFlatButton = addonTable.MakeFlatButton
local MakeFlatCheckbox = addonTable.MakeFlatCheckbox
local SkinScrollbar = addonTable.SkinScrollbar
local ShowCopyBox = addonTable.ShowCopyBox

local DB_Frame = CreateFrame("Frame")
DB_Frame:RegisterEvent("ADDON_LOADED")
DB_Frame:RegisterEvent("PLAYER_LOGIN")
DB_Frame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        if not OakUI_DB then OakUI_DB = {} end
        if not OakUI_DB.install then OakUI_DB.install = { characters = {} } end
        if not OakUI_DB.install.characters then OakUI_DB.install.characters = {} end
        if OakUI_DB.hideBaseMigrationNotice == nil then OakUI_DB.hideBaseMigrationNotice = false end
        if not OakUI_DB.minimap then OakUI_DB.minimap = { hide = false, angle = -45 } end
        if OakUI_DB.minimap.hide == nil then OakUI_DB.minimap.hide = false end
        if not OakUI_DB.minimap.angle then OakUI_DB.minimap.angle = -45 end
        if not OakUI_DB.actionBars then OakUI_DB.actionBars = { hide = false } end
        if OakUI_DB.actionBars.hide == nil then OakUI_DB.actionBars.hide = false end
        if not OakUI_DB.chatFilters then
            OakUI_DB.chatFilters = {
                achievements = true, auctions = true, channels = true, experience = true,
                followers = true, loot = true, names = true, quests = true, collections = true,
                reputation = true, spells = true, status = true, tradeskills = true, money = true,
            }
        end
        if addonTable.EnsureFontDB then addonTable.EnsureFontDB() end
        if addonTable.BypassElvUIInstaller then addonTable.BypassElvUIInstaller() end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ==========================================
-- MAIN UI FRAMEWORK 
-- ==========================================
local UI = CreateFrame("Frame", "OakUIProfileManager", UIParent, "BackdropTemplate")
UI:SetSize(700, 520); UI:SetPoint("CENTER"); UI:Hide(); 
UI:SetFrameStrata("DIALOG")
UI:SetMovable(true); UI:EnableMouse(true); 
UI:SetResizable(true); UI:SetResizeBounds(700, 520, 1400, 1000) 
UI:RegisterForDrag("LeftButton")
UI:SetScript("OnDragStart", UI.StartMoving); UI:SetScript("OnDragStop", UI.StopMovingOrSizing)
UI:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
UI:SetBackdropColor(0.106, 0.106, 0.129, 1); UI:SetBackdropBorderColor(r, g, b, 1)

local TitleBar = CreateFrame("Frame", nil, UI); TitleBar:SetSize(700, 30); TitleBar:SetPoint("TOPLEFT", UI, "TOPLEFT", 0, 0); TitleBar:SetPoint("TOPRIGHT", UI, "TOPRIGHT", 0, 0)
local tbBg = TitleBar:CreateTexture(nil, "BACKGROUND"); tbBg:SetAllPoints(); tbBg:SetColorTexture(0.137, 0.141, 0.172, 1)
local TitleText = TitleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); TitleText:SetPoint("LEFT", TitleBar, "LEFT", 15, 0); TitleText:SetText(cWrap .. "OAK UI|r Profile Manager")

local CloseBtn = CreateFrame("Button", nil, TitleBar); CloseBtn:SetSize(30, 30); CloseBtn:SetPoint("RIGHT", TitleBar, "RIGHT", 0, 0)
local clBg = CloseBtn:CreateTexture(nil, "BACKGROUND"); clBg:SetAllPoints(); clBg:SetColorTexture(0, 0, 0, 0)
CloseBtn.Text = CloseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); CloseBtn.Text:SetPoint("CENTER"); CloseBtn.Text:SetText("X")
CloseBtn:SetScript("OnEnter", function() clBg:SetColorTexture(r, g, b, 0.5) end); CloseBtn:SetScript("OnLeave", function() clBg:SetColorTexture(0, 0, 0, 0) end); CloseBtn:SetScript("OnClick", function() UI:Hide() end)

local VersionText = TitleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
VersionText:SetPoint("RIGHT", CloseBtn, "LEFT", -5, 0); VersionText:SetText("|cff888888v" .. (P.VERSION or "Unknown") .. "|r")

local LeftPane = CreateFrame("Frame", nil, UI); LeftPane:SetPoint("TOPLEFT", UI, "TOPLEFT", 10, -40); LeftPane:SetPoint("BOTTOMRIGHT", UI, "BOTTOMLEFT", 180, 10) 
local lpBg = LeftPane:CreateTexture(nil, "BACKGROUND"); lpBg:SetAllPoints(); lpBg:SetColorTexture(0.137, 0.141, 0.172, 1)

local RightPane = CreateFrame("Frame", nil, UI); RightPane:SetPoint("TOPLEFT", LeftPane, "TOPRIGHT", 5, 0); RightPane:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -10, 10)
local rpBg = RightPane:CreateTexture(nil, "BACKGROUND"); rpBg:SetAllPoints(); rpBg:SetColorTexture(0.137, 0.141, 0.172, 1)

local ResizeGrip = CreateFrame("Button", nil, UI); ResizeGrip:SetSize(16, 16); ResizeGrip:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -2, 2)
ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"); ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"); ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
ResizeGrip:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then UI:StartSizing("BOTTOMRIGHT") end end)
ResizeGrip:SetScript("OnMouseUp", function(self, button) UI:StopMovingOrSizing() end)

-- ==========================================
-- VIEW ROUTING (Tabs & Menus)
-- ==========================================
local HomeView = CreateFrame("Frame", nil, RightPane); HomeView:SetAllPoints()
local BrandRow = CreateFrame("Frame", nil, HomeView); BrandRow:SetSize(430, 135); BrandRow:SetPoint("TOP", HomeView, "TOP", 0, -25)
local ForText = BrandRow:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); ForText:SetPoint("CENTER", BrandRow, "CENTER", 0, 0); ForText:SetText(cWrap .. "For|r")
local TopLogo = BrandRow:CreateTexture(nil, "ARTWORK"); TopLogo:SetSize(125, 125); TopLogo:SetPoint("RIGHT", ForText, "LEFT", -36, 0); TopLogo:SetTexture("Interface\\AddOns\\OakUI_Installer\\Media\\Logo.tga")
local EllesmereLogo = BrandRow:CreateTexture(nil, "ARTWORK"); EllesmereLogo:SetSize(125, 125); EllesmereLogo:SetPoint("LEFT", ForText, "RIGHT", 36, 0); EllesmereLogo:SetTexture("Interface\\AddOns\\EllesmereUI\\media\\eg-logo.tga")
local WelcomeText = HomeView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); WelcomeText:SetPoint("TOP", BrandRow, "BOTTOM", 0, -5); WelcomeText:SetText(cWrap .. "Installer|r")
local SubText = HomeView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); SubText:SetPoint("TOP", WelcomeText, "BOTTOM", 0, -20); SubText:SetPoint("LEFT", HomeView, "LEFT", 20, 0); SubText:SetPoint("RIGHT", HomeView, "RIGHT", -20, 0); SubText:SetJustifyH("CENTER")
SubText:SetText("Welcome to the OAK Flagship Suite.\n\n" .. cWrap .. "Note:|r The primary OAK profiles are built around a 1440p display with a UI Scale of 0.64.")

local QuickInstallBtn = MakeFlatButton(HomeView, "Quick Install", 160, 32)
QuickInstallBtn:SetPoint("TOP", SubText, "BOTTOM", 0, -25)
QuickInstallBtn.Text:SetTextColor(r, g, b)
QuickInstallBtn:SetScript("OnClick", function()
    if addonTable.QuickInstallAll then
        addonTable.QuickInstallAll()
    end
end)

local QuickInstallNote = HomeView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
QuickInstallNote:SetPoint("TOP", QuickInstallBtn, "BOTTOM", 0, -10)
QuickInstallNote:SetPoint("LEFT", HomeView, "LEFT", 30, 0)
QuickInstallNote:SetPoint("RIGHT", HomeView, "RIGHT", -30, 0)
QuickInstallNote:SetJustifyH("CENTER")
QuickInstallNote:SetText("Installs all supported profiles and applies OAK visibility settings to match the OakUI layout.")
QuickInstallNote:SetTextColor(0.75, 0.75, 0.75)

local MinimapOption = CreateFrame("Frame", nil, HomeView)
MinimapOption:SetSize(220, 24)
MinimapOption:SetPoint("TOP", QuickInstallNote, "BOTTOM", 0, -18)
local HideMinimapCheck = CreateFrame("Button", nil, MinimapOption)
HideMinimapCheck:SetSize(18, 18)
HideMinimapCheck:SetPoint("LEFT", MinimapOption, "LEFT", 0, 0)
local HideMinimapBorder = HideMinimapCheck:CreateTexture(nil, "BACKGROUND")
HideMinimapBorder:SetAllPoints()
HideMinimapBorder:SetColorTexture(0.3, 0.32, 0.38, 1)
local HideMinimapInner = HideMinimapCheck:CreateTexture(nil, "ARTWORK")
HideMinimapInner:SetPoint("TOPLEFT", 2, -2)
HideMinimapInner:SetPoint("BOTTOMRIGHT", -2, 2)
local HideMinimapLabel = MinimapOption:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
HideMinimapLabel:SetPoint("LEFT", HideMinimapCheck, "RIGHT", 8, 0)
HideMinimapLabel:SetText("Hide Minimap Button")
HideMinimapCheck.UpdateState = function(self)
    local checked = OakUI_DB and OakUI_DB.minimap and OakUI_DB.minimap.hide
    if checked then
        HideMinimapInner:SetColorTexture(r, g, b, 1)
    else
        HideMinimapInner:SetColorTexture(0.137, 0.141, 0.172, 1)
    end
end
HideMinimapCheck:SetScript("OnClick", function(self)
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.minimap then OakUI_DB.minimap = { hide = false, angle = -45 } end
    OakUI_DB.minimap.hide = not OakUI_DB.minimap.hide
    self:UpdateState()
    if addonTable.SetMinimapButtonHidden then addonTable.SetMinimapButtonHidden(OakUI_DB.minimap.hide) end
end)
C_Timer.After(0.5, function() HideMinimapCheck:UpdateState() end)

local SocialContainer = CreateFrame("Frame", nil, HomeView); SocialContainer:SetSize(450, 40); SocialContainer:SetPoint("TOP", MinimapOption, "BOTTOM", 0, -18)
local socials = { {name="YouTube", url="https://www.youtube.com/oakensoul"}, {name="Discord", url="https://discord.gg/FRGUFaEEVd"}, {name="Twitch", url="https://www.twitch.tv/oakensoul"}, {name="Patreon", url="https://www.patreon.com/Oakensoul"}, {name="Ko-Fi", url="https://ko-fi.com/oakensoul"} }
local sW = 80; local startX = -( (#socials * sW) + ((#socials - 1) * 8) ) / 2 + (sW / 2)
for i, soc in ipairs(socials) do
    local btn = MakeFlatButton(SocialContainer, soc.name, sW, 26); btn:SetPoint("CENTER", SocialContainer, "CENTER", startX + ((i-1) * (sW + 8)), 0)
    btn:SetScript("OnClick", function() ShowCopyBox(soc.url, "Press CTRL+C to copy the link:") end)
end

-- Create the empty frames for modular tabs
local InstallerView = CreateFrame("Frame", nil, RightPane); InstallerView:SetAllPoints(); InstallerView:Hide()
local ChatView = CreateFrame("Frame", nil, RightPane); ChatView:SetAllPoints(); ChatView:Hide()
local VisibilityView = CreateFrame("Frame", nil, RightPane); VisibilityView:SetAllPoints(); VisibilityView:Hide()
local RawImportsView = CreateFrame("Frame", nil, RightPane); RawImportsView:SetAllPoints(); RawImportsView:Hide()
local FontsView = CreateFrame("Frame", nil, RightPane); FontsView:SetAllPoints(); FontsView:Hide()
local ChangelogView = CreateFrame("Frame", nil, RightPane); ChangelogView:SetAllPoints(); ChangelogView:Hide()
local SupportersView = CreateFrame("Frame", nil, RightPane); SupportersView:SetAllPoints(); SupportersView:Hide()

-- Build the Installer right away since it contains the main loop
addonTable.BuildInstallerUI(InstallerView)

-- CHAT SETTINGS VIEW
local ChatTitle = ChatView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); ChatTitle:SetPoint("TOPLEFT", ChatView, "TOPLEFT", 15, -20); ChatTitle:SetJustifyH("LEFT"); ChatTitle:SetText(cWrap .. "Chat Cleaning|r")
local ChatDesc = ChatView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); ChatDesc:SetPoint("TOPLEFT", ChatTitle, "BOTTOMLEFT", 0, -10); ChatDesc:SetPoint("TOPRIGHT", ChatView, "TOPRIGHT", -15, -10); ChatDesc:SetJustifyH("LEFT"); ChatDesc:SetText("Native chat cleaning engine. Choose which filters should be activated, or apply the OakUI two-window chat layout.\n|cffff0000Note:|r Filter and layout changes require a UI Reload to fully apply/remove hooks.")
local ChatScrollFrame = CreateFrame("ScrollFrame", "OakUI_ChatScroll", ChatView, "UIPanelScrollFrameTemplate"); local ChatScrollChild = CreateFrame("Frame", nil, ChatScrollFrame)
ChatScrollFrame:SetScrollChild(ChatScrollChild); ChatScrollFrame:SetPoint("TOPLEFT", ChatView, "TOPLEFT", 15, -100); ChatScrollFrame:SetPoint("BOTTOMRIGHT", ChatView, "BOTTOMRIGHT", -30, 50)
ChatScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end); ChatScrollChild:SetWidth(ChatScrollFrame:GetWidth() or 470)
SkinScrollbar(ChatScrollFrame)
local ChatDisableAllBtn = MakeFlatButton(ChatView, "Disable All", 100, 30); ChatDisableAllBtn:SetPoint("BOTTOMRIGHT", ChatView, "BOTTOMRIGHT", -30, 10)
local ChatEnableAllBtn = MakeFlatButton(ChatView, "Enable All", 100, 30); ChatEnableAllBtn:SetPoint("RIGHT", ChatDisableAllBtn, "LEFT", -10, 0)
local ChatLayoutBtn = MakeFlatButton(ChatView, "Apply Chat Layout", 150, 30); ChatLayoutBtn:SetPoint("RIGHT", ChatEnableAllBtn, "LEFT", -10, 0); ChatLayoutBtn.Text:SetTextColor(r, g, b)
local chatFiltersConfig = { { key = "achievements", name = "Achievements", desc = "Simplify Achievement messages." }, { key = "collections", name = "Collections", desc = "Simplify messages for Appearances/Mounts/Pets." }, { key = "experience", name = "Experience", desc = "Abbreviate level gains." }, { key = "followers", name = "Garrison Followers", desc = "Simplify follower updates." }, { key = "loot", name = "Loot & Currency", desc = "Simplify loot drops." }, { key = "quests", name = "Quests", desc = "Simplify quest progress." }, { key = "reputation", name = "Reputation", desc = "Simplify rep gain/loss." }, { key = "status", name = "Player Status", desc = "Simplify AFK/DND messages." } }
local chatCheckboxes = {}
local function InitChatSettings()
    local cyOffset = 0
    for i, filter in ipairs(chatFiltersConfig) do
        local row = CreateFrame("Frame", nil, ChatScrollChild); row:SetHeight(40); row:SetPoint("TOPLEFT", ChatScrollChild, "TOPLEFT", 0, cyOffset); row:SetPoint("TOPRIGHT", ChatScrollChild, "TOPRIGHT", 0, cyOffset)
        local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); if i % 2 == 1 then bg:SetColorTexture(0.2, 0.22, 0.28, 0.4) else bg:SetColorTexture(0,0,0,0) end
        local cb = MakeFlatCheckbox(row, cWrap .. filter.name .. "|r", filter.key); cb:SetPoint("LEFT", row, "LEFT", 10, 0)
        local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); desc:SetPoint("LEFT", cb, "RIGHT", 150, 0); desc:SetText(filter.desc); desc:SetTextColor(0.6, 0.6, 0.6)
        table.insert(chatCheckboxes, cb); C_Timer.After(0.5, function() cb:UpdateState() end)
        cyOffset = cyOffset - 40
    end
    ChatScrollChild:SetHeight(math.abs(cyOffset))
end
InitChatSettings()
ChatEnableAllBtn:SetScript("OnClick", function() for _, f in ipairs(chatFiltersConfig) do OakUI_DB.chatFilters[f.key] = true end; for _, cb in ipairs(chatCheckboxes) do cb:UpdateState() end end)
ChatDisableAllBtn:SetScript("OnClick", function() for _, f in ipairs(chatFiltersConfig) do OakUI_DB.chatFilters[f.key] = false end; for _, cb in ipairs(chatCheckboxes) do cb:UpdateState() end end)
ChatLayoutBtn:SetScript("OnClick", function()
    if addonTable.ScheduleChatWindowsAfterEllesmereProfile then
        addonTable.ScheduleChatWindowsAfterEllesmereProfile(false)
    elseif addonTable.SetupChatWindows then
        addonTable.SetupChatWindows(false)
    end
end)

-- SUPPORTERS VIEW 
local SuppTitle = SupportersView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); SuppTitle:SetPoint("TOPLEFT", SupportersView, "TOPLEFT", 15, -20); SuppTitle:SetJustifyH("LEFT"); SuppTitle:SetText(cWrap .. "Supporters|r")
local SuppDesc = SupportersView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); SuppDesc:SetPoint("TOPLEFT", SuppTitle, "BOTTOMLEFT", 0, -10); SuppDesc:SetPoint("TOPRIGHT", SupportersView, "TOPRIGHT", -15, -10); SuppDesc:SetJustifyH("LEFT"); SuppDesc:SetText("A massive thank you to the amazing people who make this project possible!\nYour support means the world to me.")
local patreons = P.PATREONS or {}
local topSupporters = {}
local supporters = {}
for _, name in ipairs(patreons) do
    if name == "Mandos" then
        table.insert(topSupporters, name)
    else
        table.insert(supporters, name)
    end
end

local SupportersGrid = CreateFrame("Frame", nil, SupportersView)
SupportersGrid:SetPoint("TOPLEFT", SupportersView, "TOPLEFT", 15, -110)
SupportersGrid:SetPoint("BOTTOMRIGHT", SupportersView, "BOTTOMRIGHT", -15, 55)

local supporterColumns = 3
local supporterCellWidth = 160
local supporterColumnGap = 12
local supporterRowHeight = 16

local function AddCenteredSupporterText(text, row, special)
    local cell = SupportersGrid:CreateFontString(nil, "OVERLAY", special and "GameFontNormalLarge" or "GameFontHighlightSmall")
    cell:SetPoint("TOP", SupportersGrid, "TOP", 0, -((row - 1) * supporterRowHeight))
    cell:SetWidth(260)
    cell:SetJustifyH("CENTER")
    if cell.SetWordWrap then cell:SetWordWrap(false) end
    if cell.SetMaxLines then cell:SetMaxLines(1) end
    cell:SetText(special and "|cffF6D365" .. text .. "|r" or text)
end

local function AddSupporterText(text, col, row, special)
    local cell = SupportersGrid:CreateFontString(nil, "OVERLAY", special and "GameFontNormalLarge" or "GameFontHighlightSmall")
    local columnOffset = (col - ((supporterColumns + 1) / 2)) * (supporterCellWidth + supporterColumnGap)
    cell:SetPoint("TOP", SupportersGrid, "TOP", columnOffset, -((row - 1) * supporterRowHeight))
    cell:SetWidth(supporterCellWidth)
    cell:SetJustifyH("CENTER")
    if cell.SetWordWrap then cell:SetWordWrap(false) end
    if cell.SetMaxLines then cell:SetMaxLines(1) end
    cell:SetText(special and "|cffF6D365" .. text .. "|r" or text)
end

local gridRow = 1

if #topSupporters > 0 then
    local header = SupportersGrid:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", SupportersGrid, "TOP", 0, 0)
    header:SetText(cWrap .. "Top Supporters|r")
    gridRow = gridRow + 1
    for _, name in ipairs(topSupporters) do
        AddCenteredSupporterText(name, gridRow, true)
        gridRow = gridRow + 1
    end
    gridRow = gridRow + 1
end

local header = SupportersGrid:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOP", SupportersGrid, "TOP", 0, -((gridRow - 1) * supporterRowHeight))
header:SetText(cWrap .. "Supporters|r")
gridRow = gridRow + 1

for i, name in ipairs(supporters) do
    local col = ((i - 1) % supporterColumns) + 1
    local row = gridRow + math.floor((i - 1) / supporterColumns)
    AddSupporterText(name, col, row, false)
end
local JoinPatreonBtn = MakeFlatButton(SupportersView, "Support on Patreon", 200, 30); JoinPatreonBtn:SetPoint("BOTTOM", SupportersView, "BOTTOM", 0, 15)
JoinPatreonBtn:SetScript("OnClick", function() ShowCopyBox("https://www.patreon.com/Oakensoul", "Press CTRL+C to copy the Patreon link:") end)

-- BASE UI MIGRATION NOTICE
local MigrationNotice = CreateFrame("Frame", "OakUI_BaseMigrationNotice", UIParent, "BackdropTemplate")
MigrationNotice:SetSize(500, 310)
MigrationNotice:SetPoint("CENTER")
MigrationNotice:SetFrameStrata("FULLSCREEN_DIALOG")
MigrationNotice:Hide()
MigrationNotice:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
MigrationNotice:SetBackdropColor(0.137, 0.141, 0.172, 1)
MigrationNotice:SetBackdropBorderColor(r, g, b, 1)

local MigrationTitle = MigrationNotice:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
MigrationTitle:SetPoint("TOP", MigrationNotice, "TOP", 0, -18)
MigrationTitle:SetText(cWrap .. "OAK UI Has Moved On From QUI|r")

local MigrationText = MigrationNotice:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
MigrationText:SetPoint("TOPLEFT", MigrationNotice, "TOPLEFT", 24, -55)
MigrationText:SetPoint("TOPRIGHT", MigrationNotice, "TOPRIGHT", -24, -55)
MigrationText:SetJustifyH("LEFT")
local baseProvider = P.BASE_UI_PROVIDER or "ElvUI"
local addonSummary
if baseProvider == "Ellesmere" then
    addonSummary = "- EllesmereUI\n- Danders Frames\n- Platynator\n- XIV_Databar Continued\n- DBM, BigWigs, and Blizzi Party Tools are optional"
else
    addonSummary = "- ElvUI\n- Ayije CDM\n- Chonky Character Sheet\n- MPlusTimer\n- Platynator\n- Details! Damage Meter\n- XIV_Databar Continued\n- DBM, BigWigs, and Blizzi Party Tools are optional"
end
MigrationText:SetText("This version of OAK UI no longer uses QUI as its base.\n\nCurrent OAK setup uses:\n" .. addonSummary)

local DontShowAgain = CreateFrame("Button", nil, MigrationNotice)
DontShowAgain:SetSize(20, 20)
DontShowAgain:SetPoint("BOTTOMLEFT", MigrationNotice, "BOTTOMLEFT", 28, 58)
local DontShowBorder = DontShowAgain:CreateTexture(nil, "BACKGROUND")
DontShowBorder:SetAllPoints()
DontShowBorder:SetColorTexture(0.3, 0.32, 0.38, 1)
local DontShowInner = DontShowAgain:CreateTexture(nil, "ARTWORK")
DontShowInner:SetPoint("TOPLEFT", 2, -2)
DontShowInner:SetPoint("BOTTOMRIGHT", -2, 2)
local DontShowLabel = MigrationNotice:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
DontShowLabel:SetPoint("LEFT", DontShowAgain, "RIGHT", 10, 0)
DontShowLabel:SetText("Do not show this again")
DontShowAgain.checked = false
DontShowAgain.UpdateState = function(self)
    if self.checked then
        DontShowInner:SetColorTexture(r, g, b, 1)
    else
        DontShowInner:SetColorTexture(0.137, 0.141, 0.172, 1)
    end
end
DontShowAgain:SetScript("OnClick", function(self)
    self.checked = not self.checked
    self:UpdateState()
end)
DontShowAgain:UpdateState()

local MigrationOK = MakeFlatButton(MigrationNotice, "Got It", 110, 28)
MigrationOK:SetPoint("BOTTOMRIGHT", MigrationNotice, "BOTTOMRIGHT", -24, 20)
MigrationOK.Text:SetTextColor(r, g, b)
MigrationOK:SetScript("OnClick", function()
    if DontShowAgain.checked then
        if not OakUI_DB then OakUI_DB = {} end
        OakUI_DB.hideBaseMigrationNotice = true
    end
    MigrationNotice:Hide()
end)

local function ShowBaseMigrationNotice()
    if OakUI_DB and OakUI_DB.hideBaseMigrationNotice then return end
    DontShowAgain.checked = false
    DontShowAgain:UpdateState()
    MigrationNotice:Show()
end

-- ==========================================
-- NAVIGATION MENU
-- ==========================================

local navButtons = {}
local function UpdateMenuHighlight(selectedBtn)
    for _, btn in ipairs(navButtons) do
        if btn == selectedBtn then btn.selected = true; btn.bg:SetColorTexture(r, g, b, 0.2); btn.Text:SetText(cWrap .. btn.baseText)
        else btn.selected = false; btn.bg:SetColorTexture(0, 0, 0, 0); btn.Text:SetText("|cffffffff" .. btn.baseText) end
    end
end

local function CreateNavButton(parent, text, yOffset, viewFrame)
    local btn = CreateFrame("Button", nil, parent); btn:SetSize(160, 30); btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 0); btn.bg = bg; btn.baseText = text
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); btn.Text:SetPoint("LEFT", 10, 0); btn.Text:SetText("|cffffffff" .. text)
    btn:SetScript("OnEnter", function(self) if not self.selected then bg:SetColorTexture(1, 1, 1, 0.05) end end)
    btn:SetScript("OnLeave", function(self) if not self.selected then bg:SetColorTexture(0, 0, 0, 0) end end)
    -- Hide all frames
    btn:SetScript("OnClick", function(self) UpdateMenuHighlight(self); HomeView:Hide(); InstallerView:Hide(); ChatView:Hide(); VisibilityView:Hide(); RawImportsView:Hide(); FontsView:Hide(); ChangelogView:Hide(); SupportersView:Hide(); viewFrame:Show() end)
    table.insert(navButtons, btn); return btn
end

-- Home is now a standard nav button at the very top!
local HomeNavBtn = CreateNavButton(LeftPane, "Home", -20, HomeView)
local InstallerNavBtn = CreateNavButton(LeftPane, "MAIN INSTALLER", -50, InstallerView)
local ChatNavBtn = CreateNavButton(LeftPane, "Chat Cleaning", -80, ChatView)
local VisNavBtn = CreateNavButton(LeftPane, "Ellesmere Tweaks", -110, VisibilityView)
local RawImportsNavBtn = CreateNavButton(LeftPane, "Raw Imports", -140, RawImportsView)
local FontsNavBtn = CreateNavButton(LeftPane, "Custom Fonts", -170, FontsView)
local ChangelogNavBtn = CreateNavButton(LeftPane, "Changelog", -200, ChangelogView)
local SuppNavBtn = CreateNavButton(LeftPane, "Supporters", -230, SupportersView)

local visibilityBuilt, rawImportsBuilt, fontsBuilt, changelogBuilt = false, false, false, false
VisNavBtn:HookScript("OnClick", function() if not visibilityBuilt and addonTable.BuildVisibilityUI then addonTable.BuildVisibilityUI(VisibilityView); visibilityBuilt = true end end)
RawImportsNavBtn:HookScript("OnClick", function() if not rawImportsBuilt and addonTable.BuildRawImportsUI then addonTable.BuildRawImportsUI(RawImportsView); rawImportsBuilt = true end end)
FontsNavBtn:HookScript("OnClick", function() if not fontsBuilt and addonTable.BuildFontsUI then addonTable.BuildFontsUI(FontsView); fontsBuilt = true end end)
ChangelogNavBtn:HookScript("OnClick", function() if not changelogBuilt and addonTable.BuildChangelogUI then addonTable.BuildChangelogUI(ChangelogView); changelogBuilt = true end end)

local MinimapButton
local function EnsureMinimapDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.minimap then OakUI_DB.minimap = { hide = false, angle = -45 } end
    if OakUI_DB.minimap.hide == nil then OakUI_DB.minimap.hide = false end
    if not OakUI_DB.minimap.angle then OakUI_DB.minimap.angle = -45 end
    return OakUI_DB.minimap
end

local function UpdateMinimapButtonPosition()
    if not MinimapButton or not Minimap then return end
    local db = EnsureMinimapDB()
    local angle = math.rad(db.angle or -45)
    local radius = 80
    MinimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateMinimapButtonVisibility()
    if not MinimapButton then return end
    local db = EnsureMinimapDB()
    if db.hide then MinimapButton:Hide() else MinimapButton:Show() end
end

function addonTable.SetMinimapButtonHidden(hidden)
    local db = EnsureMinimapDB()
    db.hide = hidden and true or false
    UpdateMinimapButtonVisibility()
end

local function CreateOakMinimapButton()
    if MinimapButton or not Minimap then return end
    EnsureMinimapDB()

    MinimapButton = CreateFrame("Button", "OakUI_MinimapButton", Minimap)
    MinimapButton:SetSize(32, 32)
    MinimapButton:SetFrameStrata("MEDIUM")
    MinimapButton:RegisterForClicks("LeftButtonUp")
    MinimapButton:RegisterForDrag("LeftButton")
    MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = MinimapButton:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(52, 52)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = MinimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\OakUI_Installer\\Media\\Logo.tga")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    MinimapButton:SetScript("OnClick", function()
        if addonTable.OpenInstaller then addonTable.OpenInstaller("home") end
    end)
    MinimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(cWrap .. "OAK UI|r")
        GameTooltip:AddLine("Click to open the installer.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move.", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    MinimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MinimapButton:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            x, y = x / scale, y / scale
            local radians = math.atan2 and math.atan2(y - cy, x - cx) or math.atan(y - cy, x - cx)
            EnsureMinimapDB().angle = math.deg(radians)
            UpdateMinimapButtonPosition()
        end)
    end)
    MinimapButton:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    UpdateMinimapButtonPosition()
    UpdateMinimapButtonVisibility()
end

-- Reload UI sits alone at the bottom
local GlobalReloadBtn = MakeFlatButton(LeftPane, "Reload UI", 160, 30)
GlobalReloadBtn:SetPoint("BOTTOM", LeftPane, "BOTTOM", 0, 10)
GlobalReloadBtn:SetScript("OnClick", function() ReloadUI() end)

function addonTable.OpenInstaller(tab)
    UI:Show()
    if tab == "installer" then
        InstallerNavBtn:Click()
    else
        HomeNavBtn:Click()
    end
end

local function GetCharacterInstallKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

function addonTable.MarkInstallerSeen()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.install then OakUI_DB.install = { characters = {} } end
    if not OakUI_DB.install.characters then OakUI_DB.install.characters = {} end
    local state = OakUI_DB.install.characters[GetCharacterInstallKey()] or {}
    state.seen = true
    state.seenVersion = P.VERSION or "Unknown"
    state.seenTime = time and time() or 0
    OakUI_DB.install.characters[GetCharacterInstallKey()] = state
end

function addonTable.MarkInstallerComplete()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.install then OakUI_DB.install = { characters = {} } end
    if not OakUI_DB.install.characters then OakUI_DB.install.characters = {} end
    local state = OakUI_DB.install.characters[GetCharacterInstallKey()] or {}
    state.seen = true
    state.seenVersion = P.VERSION or "Unknown"
    state.seenTime = state.seenTime or (time and time() or 0)
    state.completed = true
    state.version = P.VERSION or "Unknown"
    state.time = time and time() or 0
    OakUI_DB.install.characters[GetCharacterInstallKey()] = state
end

DB_Frame:HookScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    if not OakUI_DB or not OakUI_DB.install or not OakUI_DB.install.characters then return end

    CreateOakMinimapButton()
    if HideMinimapCheck and HideMinimapCheck.UpdateState then HideMinimapCheck:UpdateState() end
    if addonTable.BypassElvUIInstaller then
        addonTable.BypassElvUIInstaller()
        C_Timer.After(0.2, addonTable.BypassElvUIInstaller)
        C_Timer.After(1.2, addonTable.BypassElvUIInstaller)
    end

    local state = OakUI_DB.install.characters[GetCharacterInstallKey()]
    if not state or state.seen ~= true then
        C_Timer.After(1, function()
            if addonTable.BypassElvUIInstaller then addonTable.BypassElvUIInstaller() end
            if addonTable.OpenInstaller then
                addonTable.OpenInstaller("home")
                addonTable.MarkInstallerSeen()
                ShowBaseMigrationNotice()
            end
        end)
    end

    self:UnregisterEvent("PLAYER_LOGIN")
end)

SLASH_OAKINSTALL1 = "/oakui"; SLASH_OAKINSTALL2 = "/oak"
SlashCmdList["OAKINSTALL"] = function() if UI:IsShown() then UI:Hide() else addonTable.OpenInstaller("home") end end
