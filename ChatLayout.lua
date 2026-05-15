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

local function SyncChatFrameGroups(frame, groupsToAdd, groupsToRemove)
    if not frame then
        return
    end

    if groupsToRemove then
        for _, group in ipairs(groupsToRemove) do
            ChatFrame_RemoveMessageGroup(frame, group)
        end
    end

    if groupsToAdd then
        for _, group in ipairs(groupsToAdd) do
            ChatFrame_AddMessageGroup(frame, group)
        end
    end
end

function addonTable.SetupChatWindows(silent)
    -- 1. Setup General Window (ChatFrame1)
    local cf1 = ChatFrame1
    FCF_SetWindowName(cf1, "General")
    
    FCF_SetChatWindowFontSize(nil, cf1, 14)
    ForceTransparency(cf1, 1)
    
    local generalGroups = { 
        "SAY", "EMOTE", "YELL", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
        "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT",
        "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "IGNORED", "ERRORS", "CHANNEL",
        "BLIZZARD_SERVICE", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER",
        "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER"
    }
    local lootGroups = {
        "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL",
        "LOOT", "CURRENCY", "MONEY", "COMBAT_MISC_INFO", "SYSTEM", "PET_BATTLE_INFO",
        "PING", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"
    }
    -- Avoid wiping Blizzard's temporary whisper routing state from the primary frame.
    SyncChatFrameGroups(cf1, generalGroups, lootGroups)

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
        
        local groupsToRemoveFromLoot = {
            "SAY", "EMOTE", "YELL", "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM",
            "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT",
            "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "IGNORED", "ERRORS",
            "BLIZZARD_SERVICE", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER",
            "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER"
        }
        local lootWindowGroups = {
            "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL",
            "LOOT", "CURRENCY", "MONEY", "COMBAT_MISC_INFO", "SYSTEM", "CHANNEL",
            "PET_BATTLE_INFO", "PING", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"
        }
        SyncChatFrameGroups(lootFrame, lootWindowGroups, groupsToRemoveFromLoot)
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
local refreshQueued = false
local refreshDelay = 0
local pollingForHover = false
local OnChatTabControllerUpdate
local defaultChatTabAlpha = {
    selectedMouseover = CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA or 1,
    selectedNoMouse = CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA or 0.4,
    alertingMouseover = CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA or 1,
    alertingNoMouse = CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA or 1,
    normalMouseover = CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA or 0.6,
    normalNoMouse = CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA or 0.2,
    hideDelay = CHAT_TAB_HIDE_DELAY or 1,
}

local function ShouldHideChatTabs()
    return false
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

local function ApplyChatTabAlphaGlobals()
    if ShouldHideChatTabs() then
        CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = 1
        CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = 0
        CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = 1
        CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = 0
        CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = 1
        CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = 0
        CHAT_TAB_HIDE_DELAY = 0
    else
        CHAT_FRAME_TAB_SELECTED_MOUSEOVER_ALPHA = defaultChatTabAlpha.selectedMouseover
        CHAT_FRAME_TAB_SELECTED_NOMOUSE_ALPHA = defaultChatTabAlpha.selectedNoMouse
        CHAT_FRAME_TAB_ALERTING_MOUSEOVER_ALPHA = defaultChatTabAlpha.alertingMouseover
        CHAT_FRAME_TAB_ALERTING_NOMOUSE_ALPHA = defaultChatTabAlpha.alertingNoMouse
        CHAT_FRAME_TAB_NORMAL_MOUSEOVER_ALPHA = defaultChatTabAlpha.normalMouseover
        CHAT_FRAME_TAB_NORMAL_NOMOUSE_ALPHA = defaultChatTabAlpha.normalNoMouse
        CHAT_TAB_HIDE_DELAY = defaultChatTabAlpha.hideDelay
    end
end

local function ApplyChatTabVisibility(frame, tab)
    if not frame or not tab then
        return
    end

    if ShouldHideChatTabs() then
        tab.noMouseAlpha = 0
        tab.mouseOverAlpha = 1
    else
        tab.noMouseAlpha = nil
        tab.mouseOverAlpha = nil
    end

    if not tab:IsShown() then
        return
    end

    local targetAlpha = GetChatTabTargetAlpha(frame, tab)
    if tab:GetAlpha() ~= targetAlpha then
        tab:SetAlpha(targetAlpha)
    end
end

local function UpdateHoverPolling()
    local shouldPoll = false

    if ShouldHideChatTabs() then
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame"..i]
            local tab = _G["ChatFrame"..i.."Tab"]
            if frame and tab and tab:IsShown() and (frame:IsMouseOver() or tab:IsMouseOver()) then
                shouldPoll = true
                break
            end
        end
    end

    pollingForHover = shouldPoll
    chatTabController:SetScript("OnUpdate", (refreshQueued or pollingForHover) and OnChatTabControllerUpdate or nil)
end

local function RefreshAllChatTabs()
    ApplyChatTabAlphaGlobals()

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        local tab = _G["ChatFrame"..i.."Tab"]
        if frame and type(FCFTab_UpdateAlpha) == "function" then
            FCFTab_UpdateAlpha(frame)
        end
        ApplyChatTabVisibility(frame, tab)
    end

    UpdateHoverPolling()
end

local function QueueChatTabRefresh(delay)
    refreshQueued = true
    refreshDelay = delay or 0
    chatTabController:SetScript("OnUpdate", OnChatTabControllerUpdate)
end

OnChatTabControllerUpdate = function(self, elapsed)
    if refreshQueued then
        refreshDelay = refreshDelay - elapsed
        if refreshDelay <= 0 then
            refreshQueued = false
            RefreshAllChatTabs()
        end
    end

    if pollingForHover then
        RefreshAllChatTabs()
    elseif not refreshQueued then
        self:SetScript("OnUpdate", nil)
    end
end

addonTable.RefreshChatTabVisibility = function()
    QueueChatTabRefresh()
end

chatTabController:RegisterEvent("PLAYER_LOGIN")
chatTabController:RegisterEvent("UPDATE_CHAT_WINDOWS")
chatTabController:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
chatTabController:RegisterEvent("PLAYER_REGEN_ENABLED")
chatTabController:SetScript("OnEvent", function()
    QueueChatTabRefresh()
end)

if type(FCFTab_UpdateAlpha) == "function" then
    hooksecurefunc("FCFTab_UpdateAlpha", function(chatFrame)
        if chatFrame then
            local tab = _G[chatFrame:GetName().."Tab"]
            ApplyChatTabVisibility(chatFrame, tab)
            UpdateHoverPolling()
        end
    end)
end
