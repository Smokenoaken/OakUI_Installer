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
DB_Frame:SetScript("OnEvent", function(self, event, addon)
    if addon == addonName then
        if not OakUI_DB then OakUI_DB = {} end
        if not OakUI_DB.chatFilters then
            OakUI_DB.chatFilters = {
                achievements = true, auctions = true, channels = true, experience = true,
                followers = true, loot = true, names = true, quests = true, collections = true,
                reputation = true, spells = true, status = true, tradeskills = true, money = true,
                hideTabs = true,
            }
        end
        if OakUI_DB.chatFilters.hideTabs == nil then OakUI_DB.chatFilters.hideTabs = true end
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
local TopLogo = HomeView:CreateTexture(nil, "ARTWORK"); TopLogo:SetSize(140, 140); TopLogo:SetPoint("TOP", HomeView, "TOP", 0, -30); TopLogo:SetTexture("Interface\\AddOns\\OakUI_Installer\\Media\\Logo.tga")
local WelcomeText = HomeView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); WelcomeText:SetPoint("TOP", TopLogo, "BOTTOM", 0, -10); WelcomeText:SetText(cWrap .. "OAK|r UI Installer")
local SubText = HomeView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); SubText:SetPoint("TOP", WelcomeText, "BOTTOM", 0, -20); SubText:SetPoint("LEFT", HomeView, "LEFT", 20, 0); SubText:SetPoint("RIGHT", HomeView, "RIGHT", -20, 0); SubText:SetJustifyH("CENTER")
SubText:SetText("Welcome to the OAK Flagship Suite.\n\n" .. cWrap .. "Note:|r The primary OAK profiles are built around a 1440p display with a UI Scale of 0.64.\n\nFollow OAK on socials below:")

local SocialContainer = CreateFrame("Frame", nil, HomeView); SocialContainer:SetSize(450, 40); SocialContainer:SetPoint("TOP", SubText, "BOTTOM", 0, -30)
local socials = { {name="YouTube", url="https://www.youtube.com/oakensoul"}, {name="Discord", url="https://discord.gg/fu4zQSGXp9"}, {name="Twitch", url="https://www.twitch.tv/oakensoul"}, {name="Patreon", url="https://www.patreon.com/Oakensoul"}, {name="Ko-Fi", url="https://ko-fi.com/oakensoul"} }
local sW = 80; local startX = -( (#socials * sW) + ((#socials - 1) * 8) ) / 2 + (sW / 2)
for i, soc in ipairs(socials) do
    local btn = MakeFlatButton(SocialContainer, soc.name, sW, 26); btn:SetPoint("CENTER", SocialContainer, "CENTER", startX + ((i-1) * (sW + 8)), 0)
    btn:SetScript("OnClick", function() ShowCopyBox(soc.url, "Press CTRL+C to copy the link:") end)
end

-- Create the empty frames for modular tabs
local InstallerView = CreateFrame("Frame", nil, RightPane); InstallerView:SetAllPoints(); InstallerView:Hide()
local ChatView = CreateFrame("Frame", nil, RightPane); ChatView:SetAllPoints(); ChatView:Hide()
local VisibilityView = CreateFrame("Frame", nil, RightPane); VisibilityView:SetAllPoints(); VisibilityView:Hide()
local SelectiveView = CreateFrame("Frame", nil, RightPane); SelectiveView:SetAllPoints(); SelectiveView:Hide()
local RawImportsView = CreateFrame("Frame", nil, RightPane); RawImportsView:SetAllPoints(); RawImportsView:Hide()
local FontsView = CreateFrame("Frame", nil, RightPane); FontsView:SetAllPoints(); FontsView:Hide()
local FAQView = CreateFrame("Frame", nil, RightPane); FAQView:SetAllPoints(); FAQView:Hide()
local ChangelogView = CreateFrame("Frame", nil, RightPane); ChangelogView:SetAllPoints(); ChangelogView:Hide()
local SupportersView = CreateFrame("Frame", nil, RightPane); SupportersView:SetAllPoints(); SupportersView:Hide()

-- Build the Installer right away since it contains the main loop
addonTable.BuildInstallerUI(InstallerView)

-- CHAT SETTINGS VIEW
local ChatTitle = ChatView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); ChatTitle:SetPoint("TOPLEFT", ChatView, "TOPLEFT", 15, -20); ChatTitle:SetJustifyH("LEFT"); ChatTitle:SetText(cWrap .. "Chat Settings|r")
local ChatDesc = ChatView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); ChatDesc:SetPoint("TOPLEFT", ChatTitle, "BOTTOMLEFT", 0, -10); ChatDesc:SetPoint("TOPRIGHT", ChatView, "TOPRIGHT", -15, -10); ChatDesc:SetJustifyH("LEFT"); ChatDesc:SetText("Native chat cleaning engine. Choose which filters should be activated.\n|cffff0000Note:|r Filter changes require a UI Reload to fully apply/remove hooks.")
local ChatScrollFrame = CreateFrame("ScrollFrame", "OakUI_ChatScroll", ChatView, "UIPanelScrollFrameTemplate"); local ChatScrollChild = CreateFrame("Frame", nil, ChatScrollFrame)
ChatScrollFrame:SetScrollChild(ChatScrollChild); ChatScrollFrame:SetPoint("TOPLEFT", ChatView, "TOPLEFT", 15, -100); ChatScrollFrame:SetPoint("BOTTOMRIGHT", ChatView, "BOTTOMRIGHT", -30, 50)
ChatScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end); ChatScrollChild:SetWidth(ChatScrollFrame:GetWidth() or 470)
SkinScrollbar(ChatScrollFrame)
local ChatDisableAllBtn = MakeFlatButton(ChatView, "Disable All", 100, 30); ChatDisableAllBtn:SetPoint("BOTTOMRIGHT", ChatView, "BOTTOMRIGHT", -30, 10)
local ChatEnableAllBtn = MakeFlatButton(ChatView, "Enable All", 100, 30); ChatEnableAllBtn:SetPoint("RIGHT", ChatDisableAllBtn, "LEFT", -10, 0)
local chatFiltersConfig = { { key = "hideTabs", name = "Hide Chat Tabs", desc = "Auto-hide tabs unless hovered." }, { key = "achievements", name = "Achievements", desc = "Simplify Achievement messages." }, { key = "channels", name = "Chat Channel Names", desc = "Abbreviate chat channel names." }, { key = "collections", name = "Collections", desc = "Simplify messages for Appearances/Mounts/Pets." }, { key = "experience", name = "Experience", desc = "Abbreviate level gains." }, { key = "followers", name = "Garrison Followers", desc = "Simplify follower updates." }, { key = "loot", name = "Loot & Currency", desc = "Simplify loot drops." }, { key = "names", name = "Player Names", desc = "Remove brackets from player names." }, { key = "quests", name = "Quests", desc = "Simplify quest progress." }, { key = "reputation", name = "Reputation", desc = "Simplify rep gain/loss." }, { key = "status", name = "Player Status", desc = "Simplify AFK/DND messages." } }
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

-- SUPPORTERS VIEW 
local SuppTitle = SupportersView:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); SuppTitle:SetPoint("TOPLEFT", SupportersView, "TOPLEFT", 15, -20); SuppTitle:SetJustifyH("LEFT"); SuppTitle:SetText(cWrap .. "Supporters|r")
local SuppDesc = SupportersView:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); SuppDesc:SetPoint("TOPLEFT", SuppTitle, "BOTTOMLEFT", 0, -10); SuppDesc:SetPoint("TOPRIGHT", SupportersView, "TOPRIGHT", -15, -10); SuppDesc:SetJustifyH("LEFT"); SuppDesc:SetText("A massive thank you to the amazing people who make this project possible!\nYour support means the world to me.")
local SuppScrollFrame = CreateFrame("ScrollFrame", "OakUI_SupportersScroll", SupportersView, "UIPanelScrollFrameTemplate"); local SuppScrollChild = CreateFrame("Frame", nil, SuppScrollFrame)
SuppScrollFrame:SetScrollChild(SuppScrollChild); SuppScrollFrame:SetPoint("TOPLEFT", SupportersView, "TOPLEFT", 15, -100); SuppScrollFrame:SetPoint("BOTTOMRIGHT", SupportersView, "BOTTOMRIGHT", -30, 60)
SuppScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end); SuppScrollChild:SetWidth(SuppScrollFrame:GetWidth() or 470)
SkinScrollbar(SuppScrollFrame) 
local patreons = P.PATREONS or {}; local syOffset = 0
for i, name in ipairs(patreons) do
    local row = CreateFrame("Frame", nil, SuppScrollChild); row:SetHeight(30); row:SetPoint("TOPLEFT", SuppScrollChild, "TOPLEFT", 0, syOffset); row:SetPoint("TOPRIGHT", SuppScrollChild, "TOPRIGHT", 0, syOffset)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); if i % 2 == 1 then bg:SetColorTexture(0.2, 0.22, 0.28, 0.4) else bg:SetColorTexture(0,0,0,0) end
    local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); txt:SetPoint("CENTER", row, "CENTER", 0, 0); txt:SetText(name)
    syOffset = syOffset - 30
end
SuppScrollChild:SetHeight(math.abs(syOffset))
local JoinPatreonBtn = MakeFlatButton(SupportersView, "Support on Patreon", 200, 30); JoinPatreonBtn:SetPoint("BOTTOM", SupportersView, "BOTTOM", 0, 15)
JoinPatreonBtn:SetScript("OnClick", function() ShowCopyBox("https://www.patreon.com/Oakensoul", "Press CTRL+C to copy the Patreon link:") end)

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
    btn:SetScript("OnClick", function(self) UpdateMenuHighlight(self); HomeView:Hide(); InstallerView:Hide(); ChatView:Hide(); VisibilityView:Hide(); SelectiveView:Hide(); RawImportsView:Hide(); FontsView:Hide(); ChangelogView:Hide(); FAQView:Hide(); SupportersView:Hide(); viewFrame:Show() end)
    table.insert(navButtons, btn); return btn
end

-- Home is now a standard nav button at the very top!
local HomeNavBtn = CreateNavButton(LeftPane, "Home", -20, HomeView)
local InstallerNavBtn = CreateNavButton(LeftPane, "MAIN INSTALLER", -50, InstallerView)
local ChatNavBtn = CreateNavButton(LeftPane, "Chat Settings", -80, ChatView)
local VisNavBtn = CreateNavButton(LeftPane, "QUI Visibility", -110, VisibilityView)
local SelectiveNavBtn = CreateNavButton(LeftPane, "Selective Import", -140, SelectiveView)
local RawImportsNavBtn = CreateNavButton(LeftPane, "Raw Imports", -170, RawImportsView)
local FontsNavBtn = CreateNavButton(LeftPane, "Custom Fonts", -200, FontsView)
local FAQNavBtn = CreateNavButton(LeftPane, "FAQ", -230, FAQView)
local ChangelogNavBtn = CreateNavButton(LeftPane, "Changelog", -260, ChangelogView)
local SuppNavBtn = CreateNavButton(LeftPane, "Supporters", -290, SupportersView)

local visibilityBuilt, selectiveBuilt, rawImportsBuilt, fontsBuilt, changelogBuilt, faqBuilt = false, false, false, false, false, false
VisNavBtn:HookScript("OnClick", function() if not visibilityBuilt and addonTable.BuildVisibilityUI then addonTable.BuildVisibilityUI(VisibilityView); visibilityBuilt = true end end)
SelectiveNavBtn:HookScript("OnClick", function() if not selectiveBuilt and addonTable.BuildSelectiveUI then addonTable.BuildSelectiveUI(SelectiveView); selectiveBuilt = true end end)
RawImportsNavBtn:HookScript("OnClick", function() if not rawImportsBuilt and addonTable.BuildRawImportsUI then addonTable.BuildRawImportsUI(RawImportsView); rawImportsBuilt = true end end)
FontsNavBtn:HookScript("OnClick", function() if not fontsBuilt and addonTable.BuildFontsUI then addonTable.BuildFontsUI(FontsView); fontsBuilt = true end end)
ChangelogNavBtn:HookScript("OnClick", function() if not changelogBuilt and addonTable.BuildChangelogUI then addonTable.BuildChangelogUI(ChangelogView); changelogBuilt = true end end)
FAQNavBtn:HookScript("OnClick", function() if not faqBuilt and addonTable.BuildFAQUI then addonTable.BuildFAQUI(FAQView); faqBuilt = true end end)

-- Reload UI sits alone at the bottom
local GlobalReloadBtn = MakeFlatButton(LeftPane, "Reload UI", 160, 30)
GlobalReloadBtn:SetPoint("BOTTOM", LeftPane, "BOTTOM", 0, 10)
GlobalReloadBtn:SetScript("OnClick", function() ReloadUI() end)

SLASH_OAKINSTALL1 = "/oakui"; SLASH_OAKINSTALL2 = "/oak"
SlashCmdList["OAKINSTALL"] = function() if UI:IsShown() then UI:Hide() else UI:Show(); HomeNavBtn:Click() end end