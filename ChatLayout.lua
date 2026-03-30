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
-- BRUTE FORCE GHOST TABS (Globally Executed)
-- ==========================================
local ghostFrame = CreateFrame("Frame")
local ghostTimer = 0
ghostFrame:SetScript("OnUpdate", function(self, elapsed)
    ghostTimer = ghostTimer + elapsed
    if ghostTimer > 0.1 then 
        ghostTimer = 0
        -- Read setting from UI toggle
        local shouldHide = OakUI_DB and OakUI_DB.chatFilters and OakUI_DB.chatFilters.hideTabs
        
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame"..i]
            local tab = _G["ChatFrame"..i.."Tab"]
            if frame and tab and tab:IsShown() then
                if shouldHide then
                    -- Force 0 unless hovered
                    if frame:IsMouseOver() or tab:IsMouseOver() then
                        tab:SetAlpha(1)
                    else
                        tab:SetAlpha(0)
                    end
                else
                    -- If user turned toggle OFF, make sure tabs recover to 100%
                    if tab:GetAlpha() < 1 then
                        tab:SetAlpha(1)
                    end
                end
            end
        end
    end
end)