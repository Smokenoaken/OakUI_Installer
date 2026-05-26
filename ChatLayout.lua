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

local scheduledChatLayoutToken = 0

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
    
    FCF_DockUpdate()
    if addonTable.RefreshChatTabVisibility then
        addonTable.RefreshChatTabVisibility()
    end
    if not quiet then
        print("|cff17ee15[OakUI]|r OakUI Chat layout applied! General is governed by Edit Mode, Loot is dynamically tethered to it.")
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
    local didApply = false
    local ok, result = pcall(addonTable.SetupChatWindows, silent, false, true)
    if ok then
        didApply = result == true
    else
        print("|cffff0000[OakUI Error]|r Chat layout failed: " .. tostring(result))
    end

    if not C_Timer or type(C_Timer.After) ~= "function" then
        return didApply
    end

    scheduledChatLayoutToken = scheduledChatLayoutToken + 1
    local token = scheduledChatLayoutToken
    C_Timer.After(0.8, function()
        if token ~= scheduledChatLayoutToken then return end

        local ok, result = pcall(addonTable.SetupChatWindows, true, didApply, false)
        if not ok then
            print("|cffff0000[OakUI Error]|r Chat layout retry failed: " .. tostring(result))
        elseif result == true and not didApply then
            print("|cff17ee15[OakUI]|r OakUI Chat layout applied after waiting for the UI to settle.")
        end
    end)
    return didApply
end

-- ==========================================
-- CHAT TAB VISIBILITY CONTROL
-- ==========================================
local lootTabAlphaFrame = CreateFrame("Frame")
local lootTabAlphaElapsed = 0
local lootTabAlphaHookedDock = false
local lootTabAlphaHookedChat = false

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

local function HookEllesmereChatAlpha()
    if not lootTabAlphaHookedDock and _G.GeneralDockManager and _G.GeneralDockManager.SetAlpha then
        lootTabAlphaHookedDock = true
        hooksecurefunc(_G.GeneralDockManager, "SetAlpha", function(_, alpha)
            SyncLootTabAlpha(alpha)
        end)
    end
    if not lootTabAlphaHookedChat and _G.ChatFrame1 and _G.ChatFrame1.SetAlpha then
        lootTabAlphaHookedChat = true
        hooksecurefunc(_G.ChatFrame1, "SetAlpha", function(_, alpha)
            SyncLootTabAlpha(alpha)
        end)
    end
end

addonTable.RefreshChatTabVisibility = function()
    HookEllesmereChatAlpha()
    SyncLootTabAlpha()
end

lootTabAlphaFrame:RegisterEvent("PLAYER_LOGIN")
lootTabAlphaFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
lootTabAlphaFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
lootTabAlphaFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
lootTabAlphaFrame:SetScript("OnEvent", addonTable.RefreshChatTabVisibility)
lootTabAlphaFrame:SetScript("OnUpdate", function(_, elapsed)
    lootTabAlphaElapsed = lootTabAlphaElapsed + elapsed
    if lootTabAlphaElapsed < 0.05 then return end
    lootTabAlphaElapsed = 0
    SyncLootTabAlpha()
end)
