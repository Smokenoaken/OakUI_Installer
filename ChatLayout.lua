local addonName, addonTable = ...

-- ==========================================
-- FEATURE: AUTO-SETUP CHAT WINDOWS
-- ==========================================
local OAK_LOOT_GROUPS = {
    "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL",
    "LOOT", "CURRENCY", "MONEY", "COMBAT_MISC_INFO", "SYSTEM", "PET_BATTLE_INFO",
    "PING", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"
}

local function BaseClearAllPoints(frame)
    if not frame then return end
    local fn = frame.ClearAllPointsBase or frame.ClearAllPoints
    if fn then pcall(fn, frame) end
end

local function BaseSetPoint(frame, ...)
    if not frame then return end
    local fn = frame.SetPointBase or frame.SetPoint
    if fn then pcall(fn, frame, ...) end
end

local function BaseSetSize(frame, width, height)
    if not frame then return end
    local fn = frame.SetSizeBase or frame.SetSize
    if fn then pcall(fn, frame, width, height) end
end

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

local function GetChatFrameID(frame)
    if not frame then
        return nil
    end

    if frame.GetID then
        local id = frame:GetID()
        if type(id) == "number" and id > 0 then
            return id
        end
    end

    if frame.GetName then
        local name = frame:GetName()
        if name then
            return tonumber(name:match("^ChatFrame(%d+)$"))
        end
    end
end

local function FindChatWindowByName(...)
    for i = 1, NUM_CHAT_WINDOWS do
        local name = GetChatWindowInfo(i)
        for j = 1, select("#", ...) do
            if name == select(j, ...) then
                return _G["ChatFrame"..i], i
            end
        end
    end
end

local function AddUniqueChannel(channelNames, channelName)
    if not channelName or channelName == "" then
        return
    end

    for _, existingName in ipairs(channelNames) do
        if existingName == channelName then
            return
        end
    end

    table.insert(channelNames, channelName)
end

local function GetChannelShortcut(channelID)
    if C_ChatInfo and type(C_ChatInfo.GetChannelShortcutForChannelID) == "function" then
        return C_ChatInfo.GetChannelShortcutForChannelID(channelID)
    end
end

local function GetTradeChannelNames()
    local channelNames = {}
    AddUniqueChannel(channelNames, GetChannelShortcut(2) or TRADE or "Trade")
    AddUniqueChannel(channelNames, GetChannelShortcut(42) or GetChannelShortcut(45) or SERVICES or "Services")
    return channelNames
end

local function AddChatChannel(frame, channelName)
    if not frame or not channelName then
        return
    end

    if frame.AddChannel then
        frame:AddChannel(channelName)
    elseif ChatFrame_AddChannel then
        ChatFrame_AddChannel(frame, channelName)
    end
end

local function RemoveChatChannel(frame, channelName)
    if not frame or not channelName then
        return
    end

    if frame.RemoveChannel then
        frame:RemoveChannel(channelName)
    elseif ChatFrame_RemoveChannel then
        ChatFrame_RemoveChannel(frame, channelName)
    end
end

local function RouteChannelsToFrame(targetFrame, channelsToRoute, ...)
    local otherFrameCount = select("#", ...)

    for _, channelName in ipairs(channelsToRoute) do
        AddChatChannel(targetFrame, channelName)

        for i = 1, otherFrameCount do
            RemoveChatChannel(select(i, ...), channelName)
        end
    end
end

function addonTable.SetupChatWindows(silent, quiet, resetFirst)
    -- 1. Setup General Window (ChatFrame1)
    if resetFirst and type(FCF_ResetChatWindows) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            if not quiet then
                print("|cffff0000[OakUI Error]|r Leave combat before applying the OakUI chat layout.")
            end
            return false
        end
        FCF_ResetChatWindows()
    end

    local cf1 = ChatFrame1
    if not cf1 then
        if not quiet then
            print("|cffff0000[OakUI]|r ChatFrame1 is not available yet. Try again after the UI finishes loading.")
        end
        return
    end

    FCF_SetWindowName(cf1, "General")
    
    FCF_SetChatWindowFontSize(nil, cf1, 14)
    ForceTransparency(cf1, 1)
    
    -- Leave protected/player/monster chat routing under Blizzard control.
    -- Touch only OakUI's low-risk loot/system groups during layout import.
    SyncChatFrameGroups(cf1, nil, OAK_LOOT_GROUPS)

    -- 2. Find or Create Loot Window Safely
    local lootWindowName = LOOT or "Loot"
    local lootFrame, lootID = FindChatWindowByName(lootWindowName, "Loot")

    if not lootFrame then
        if type(FCF_OpenNewWindow) == "function" then
            local frame, newID = FCF_OpenNewWindow(lootWindowName)
            lootFrame = frame
            lootID = newID or GetChatFrameID(frame)

            if not lootFrame or not lootID then
                local foundFrame, foundID = FindChatWindowByName(lootWindowName, "Loot")
                lootFrame = foundFrame or lootFrame
                lootID = foundID or lootID
            end
        end
    end

    if lootFrame then
        FCF_SetWindowName(lootFrame, lootWindowName)
    end
    if lootID then
        SetChatWindowName(lootID, lootWindowName)
    end

    if not lootFrame then
        if not quiet then
            print("|cffff0000[OakUI Error]|r Could not create the Loot chat window. Try again after leaving combat and after the UI finishes loading.")
        end
        return false
    end

    FCF_UnDockFrame(lootFrame)
    lootFrame:SetUserPlaced(true)
    BaseClearAllPoints(lootFrame)

    BaseSetPoint(lootFrame, "BOTTOMLEFT", cf1, "TOPLEFT", 0, 32)
    BaseSetSize(lootFrame, cf1:GetWidth(), 180)

    FCF_SavePositionAndDimensions(lootFrame)
    FCF_SetChatWindowFontSize(nil, lootFrame, 14)
    ForceTransparency(lootFrame, lootID)

    SyncChatFrameGroups(lootFrame, OAK_LOOT_GROUPS, nil)

    -- 3. Find or Create Trade Tab Safely
    local tradeWindowName = TRADE or "Trade"
    local tradeFrame, tradeID = FindChatWindowByName(tradeWindowName, "Trade")

    if not tradeFrame then
        if type(FCF_OpenNewWindow) == "function" then
            local frame, newID = FCF_OpenNewWindow(tradeWindowName)
            tradeFrame = frame
            tradeID = newID or GetChatFrameID(frame)

            if not tradeFrame or not tradeID then
                local foundFrame, foundID = FindChatWindowByName(tradeWindowName, "Trade")
                tradeFrame = foundFrame or tradeFrame
                tradeID = foundID or tradeID
            end
        end
    end

    if tradeFrame then
        FCF_SetWindowName(tradeFrame, tradeWindowName)
    end
    if tradeID then
        SetChatWindowName(tradeID, tradeWindowName)
        if type(SetChatWindowShown) == "function" then
            SetChatWindowShown(tradeID, true)
        end
    end

    if tradeFrame then
        if tradeFrame.Show then
            tradeFrame:Show()
        end

        if type(FCF_DockFrame) == "function" then
            FCF_DockFrame(tradeFrame, 3)
        end

        FCF_SetChatWindowFontSize(nil, tradeFrame, 14)
        ForceTransparency(tradeFrame, tradeID)

        SyncChatFrameGroups(tradeFrame, { "CHANNEL" }, OAK_LOOT_GROUPS)
        RouteChannelsToFrame(tradeFrame, GetTradeChannelNames(), cf1, lootFrame)
    elseif not quiet then
        print("|cffff0000[OakUI Error]|r Could not create the Trade chat tab. Try again after leaving combat and after the UI finishes loading.")
    end
    
    FCF_DockUpdate()
    if addonTable.RefreshChatTabVisibility then
        addonTable.RefreshChatTabVisibility()
    end
    if not quiet then
        print("|cff17ee15[OakUI]|r OakUI Chat layout applied! General and Trade are docked below, Loot is dynamically tethered above.")
    end

    -- Skip the standalone popup if this was triggered by "Install All"
    if not silent and not quiet then
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
    return true
end

function addonTable.ScheduleChatWindowsAfterEllesmereProfile(silent)
    local ok, result = pcall(addonTable.SetupChatWindows, silent, false, true)
    if not ok then
        print("|cffff0000[OakUI Error]|r Chat layout failed: " .. tostring(result))
    end
    return ok and result == true
end

-- ==========================================
-- CHAT TAB VISIBILITY CONTROL
-- ==========================================
local lootTabAlphaFrame = CreateFrame("Frame")

local function GetLootChatFrame()
    return FindChatWindowByName(LOOT or "Loot", "Loot")
end

local function GetEllesmereChatAlpha()
    if _G.GeneralDockManager and _G.GeneralDockManager.GetAlpha then
        return _G.GeneralDockManager:GetAlpha()
    end
    if _G.ChatFrame1 and _G.ChatFrame1.GetAlpha then
        return _G.ChatFrame1:GetAlpha()
    end
    return 1
end

local function SyncLootTabAlpha(alpha)
    local lootFrame = GetLootChatFrame()
    if not lootFrame or not lootFrame.GetName then return end

    local tab = _G[lootFrame:GetName() .. "Tab"]
    if not tab or not tab.SetAlpha then return end

    if lootFrame:IsMouseOver() or tab:IsMouseOver() then
        alpha = 1
    else
        alpha = alpha or GetEllesmereChatAlpha()
    end

    if tab:GetAlpha() ~= alpha then
        tab:SetAlpha(alpha, true)
    end
end

addonTable.RefreshChatTabVisibility = function()
    SyncLootTabAlpha()
end

lootTabAlphaFrame:RegisterEvent("PLAYER_LOGIN")
lootTabAlphaFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
lootTabAlphaFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
lootTabAlphaFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
lootTabAlphaFrame:SetScript("OnEvent", addonTable.RefreshChatTabVisibility)
