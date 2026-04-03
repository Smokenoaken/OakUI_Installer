local addonName, addonTable = ...

-- ==========================================
-- FEATURE: AUTO-SETUP CHAT WINDOWS
-- ==========================================
local function ForceTransparency(frame, numID)
    if frame then
        FCF_SetWindowColor(frame, 0, 0, 0)
        FCF_SetWindowAlpha(frame, 0)
    end
    -- FIX: Pass explicit numeric ID to avoid API errors
    if numID and type(numID) == "number" then
        SetChatWindowColor(numID, 0, 0, 0)
        SetChatWindowAlpha(numID, 0)
    end
end

function addonTable.SetupChatWindows(silent)
    -- 1. Setup General Window (ChatFrame1)
    local cf1 = ChatFrame1
    FCF_SetWindowName(cf1, "General")
    
    FCF_SetChatWindowFontSize(nil, cf1, 14)
    ForceTransparency(cf1, 1)
    
    ChatFrame_RemoveAllMessageGroups(cf1)
    local generalGroups = { 
        "SAY", "EMOTE", "YELL", "WHISPER", "BN_WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", 
        "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "IGNORED", "ERRORS", 
        "CHANNEL", "BLIZZARD_SERVICE", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER", 
        "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER" 
    }
    for _, group in pairs(generalGroups) do ChatFrame_AddMessageGroup(cf1, group) end

    -- 2. Find or Create Loot Window Safely
    local lootFrame = nil
    local lootID = nil
    for i = 1, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        if name == "Loot" then
            lootFrame = _G["ChatFrame"..i]
            lootID = i
            break
        end
    end
    
    if not lootFrame then
        local frame, newID = FCF_OpenNewWindow("Loot")
        lootFrame = frame
        lootID = newID
        SetChatWindowName(lootID, "Loot")
    end

    if lootFrame and lootID then
        FCF_UnDockFrame(lootFrame)
        lootFrame:SetUserPlaced(true)
        lootFrame:ClearAllPoints()
        
        lootFrame:SetPoint("BOTTOMLEFT", cf1, "TOPLEFT", 0, 32)
        lootFrame:SetSize(cf1:GetWidth(), 180)
        
        FCF_SavePositionAndDimensions(lootFrame)
        FCF_SetChatWindowFontSize(nil, lootFrame, 14)
        ForceTransparency(lootFrame, lootID)
        
        ChatFrame_RemoveAllMessageGroups(lootFrame)
        local lootGroups = { 
            "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL", 
            "LOOT", "CURRENCY", "MONEY", "COMBAT_MISC_INFO", "SYSTEM", "CHANNEL", 
            "PET_BATTLE_INFO", "PING", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"
        }
        for _, group in pairs(lootGroups) do ChatFrame_AddMessageGroup(lootFrame, group) end
    end
    
    FCF_DockUpdate()
    if addonTable.RefreshChatTabVisibility then
        addonTable.RefreshChatTabVisibility()
    end
    print("|cff17ee15[OakUI]|r OakUI Chat layout applied! General is governed by Edit Mode, Loot is dynamically tethered to it.")

    -- Skip the standalone popup if this was triggered by "Install All"
    if not silent then
        StaticPopupDialogs["OAKUI_CHAT_RELOAD"] = {
            text = "|cff17ee15OAK UI|r\n\nChat layout configured successfully!\nA UI Reload is strictly required to permanently lock the new tabs into the server database.",
            button1 = "Reload UI",
            button2 = "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("OAKUI_CHAT_RELOAD")
    end
end

-- ==========================================
-- CHAT TAB VISIBILITY CONTROL
-- ==========================================
local chatTabController = CreateFrame("Frame")
local hookedTabs = {}
local refreshQueued = false
local refreshDelay = 0

local function ShouldHideChatTabs()
    return not (OakUI_DB and OakUI_DB.chatFilters and OakUI_DB.chatFilters.hideTabs == false)
end

local function GetChatTabTargetAlpha(frame, tab)
    if not frame or not tab then
        return 1
    end

    if not ShouldHideChatTabs() then
        return 1
    end

    if frame:IsMouseOver() or tab:IsMouseOver() then
        return 1
    end

    return 0
end

local function ApplyChatTabVisibility(frame, tab)
    if not frame or not tab or not tab:IsShown() then
        return
    end

    local targetAlpha = GetChatTabTargetAlpha(frame, tab)
    if tab:GetAlpha() ~= targetAlpha then
        tab:SetAlpha(targetAlpha)
    end
end

local function RefreshAllChatTabs()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        local tab = _G["ChatFrame"..i.."Tab"]
        ApplyChatTabVisibility(frame, tab)
    end
end

local function QueueChatTabRefresh(delay)
    refreshQueued = true
    refreshDelay = delay or 0
    chatTabController:SetScript("OnUpdate", function(self, elapsed)
        refreshDelay = refreshDelay - elapsed
        if refreshDelay > 0 then
            return
        end

        refreshQueued = false
        self:SetScript("OnUpdate", nil)
        RefreshAllChatTabs()
    end)
end

local function HookChatTab(frame, tab)
    if not frame or not tab or hookedTabs[tab] then
        return
    end

    hookedTabs[tab] = true

    tab:HookScript("OnShow", function()
        QueueChatTabRefresh()
    end)
    tab:HookScript("OnEnter", function()
        ApplyChatTabVisibility(frame, tab)
    end)
    tab:HookScript("OnLeave", function()
        ApplyChatTabVisibility(frame, tab)
    end)
    frame:HookScript("OnEnter", function()
        ApplyChatTabVisibility(frame, tab)
    end)
    frame:HookScript("OnLeave", function()
        ApplyChatTabVisibility(frame, tab)
    end)
end

local function HookAllChatTabs()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        local tab = _G["ChatFrame"..i.."Tab"]
        HookChatTab(frame, tab)
    end
end

addonTable.RefreshChatTabVisibility = function()
    HookAllChatTabs()
    QueueChatTabRefresh()
end

chatTabController:RegisterEvent("PLAYER_LOGIN")
chatTabController:RegisterEvent("UPDATE_CHAT_WINDOWS")
chatTabController:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
chatTabController:SetScript("OnEvent", function()
    HookAllChatTabs()
    QueueChatTabRefresh()
end)

if type(FCFTab_UpdateAlpha) == "function" then
    hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
        if chatFrame then
            local tab = _G[chatFrame:GetName().."Tab"]
            HookChatTab(chatFrame, tab)
            ApplyChatTabVisibility(chatFrame, tab)
        end
    end)
end

if type(FCFDock_UpdateTabs) == "function" then
    hooksecurefunc("FCFDock_UpdateTabs", function()
        addonTable.RefreshChatTabVisibility()
    end)
end
