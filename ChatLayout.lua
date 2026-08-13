local addonName, addonTable = ...

-- ==========================================
-- FEATURE: AUTO-SETUP CHAT WINDOWS
-- ==========================================
local OAK_LOOT_GROUPS = {
    "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL",
    "LOOT", "CURRENCY", "MONEY", "COMBAT_MISC_INFO", "SYSTEM", "PET_BATTLE_INFO",
    "PING", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"
}

local OAK_PLAYER_MESSAGE_GROUPS = {
    "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "GUILD_ACHIEVEMENT",
    "ACHIEVEMENT", "BN_WHISPER", "WHISPER", "PARTY", "PARTY_LEADER",
    "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT",
    "INSTANCE_CHAT_LEADER", "VOICE_TEXT",
}

local OAK_GENERAL_PLAYER_GROUPS = {
    "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "PARTY",
    "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
}

local OAK_LOOT_PLAYER_GROUPS = {
    "GUILD_ACHIEVEMENT", "ACHIEVEMENT", "BN_WHISPER",
}

local OAK_TRADE_PLAYER_GROUPS = {
    "WHISPER",
}

local OAK_CHAT_BASE_UI_SCALE = 0.64
local OAK_LOOT_HEIGHT = 180
local OAK_GENERAL_WIDTH = 520
local OAK_GENERAL_HEIGHT = 180
local OAK_EDITBOX_BELOW_FRAME_OFFSET = 8
local OAK_EDITBOX_HEIGHT = 23
local OAK_LOOT_BASE_GAP = OAK_EDITBOX_BELOW_FRAME_OFFSET + OAK_EDITBOX_HEIGHT
local OAK_LOOT_FLUSH_NUDGE = 5
local OAK_LOOT_LEFT_INSET_PP = 1
local OAK_GENERAL_BOTTOM_GAP_PP = 15
local OAK_GENERAL_BOTTOM_GAP_NATIVE = 19

local function ScaleLayoutLength(value)
    if addonTable.ScaleOakLayoutLength then
        return addonTable.ScaleOakLayoutLength(value)
    end
    return value
end

local function GetLayoutScale()
    local preset = addonTable.GetOakLayoutPreset and addonTable.GetOakLayoutPreset()
    local scale = tonumber(preset and preset.scale)
    if (not scale or scale <= 0) and UIParent and UIParent.GetScale then
        local ok, uiScale = pcall(UIParent.GetScale, UIParent)
        scale = ok and tonumber(uiScale)
    end
    if not scale or scale <= 0 then
        scale = OAK_CHAT_BASE_UI_SCALE
    end
    return scale
end

local function ScalePhysicalPixels(value)
    local scale = GetLayoutScale()
    return (tonumber(value) or 0) / scale
end

local function InterpolateByLayoutScale(pixelPerfectValue, nativeValue)
    local scale = GetLayoutScale()
    local range = OAK_CHAT_BASE_UI_SCALE - 0.533
    local t = 0
    if range > 0 then
        t = (scale - 0.533) / range
    end
    if t < 0 then t = 0 elseif t > 1 then t = 1 end

    return pixelPerfectValue + ((nativeValue - pixelPerfectValue) * t)
end

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

local function SaveChatWindowPosition(frame)
    if not frame then return end
    if type(FCF_SavePositionAndDimensions) == "function" then
        pcall(FCF_SavePositionAndDimensions, frame)
    end
end

local function SaveChatWindowPresentation(frame, numID, shown, locked)
    if not frame or not numID then
        return
    end

    if type(SetChatWindowShown) == "function" then
        pcall(SetChatWindowShown, numID, shown and true or false)
    end
    if type(SetChatWindowLocked) == "function" then
        pcall(SetChatWindowLocked, numID, locked and true or false)
    end
    if type(SetChatWindowUninteractable) == "function" then
        pcall(SetChatWindowUninteractable, numID, false)
    end
    if type(FCF_SetLocked) == "function" then
        pcall(FCF_SetLocked, frame, locked and true or false)
    end
end

local function SaveChatWindowFont(frame, numID, size)
    if not frame or not numID then
        return
    end
    if type(SetChatWindowSize) == "function" then
        pcall(SetChatWindowSize, numID, size)
    end
    if type(FCF_SetChatWindowFontSize) == "function" then
        pcall(FCF_SetChatWindowFontSize, nil, frame, size)
    end
end

local function CaptureFrameGeometry(frame)
    if not frame or not frame.GetLeft or not frame.GetBottom or not frame.GetSize then
        return
    end

    local left, bottom = frame:GetLeft(), frame:GetBottom()
    local width, height = frame:GetSize()
    if not left or not bottom or not width or not height then
        return
    end

    return {
        left = left,
        bottom = bottom,
        width = width,
        height = height,
    }
end

local function RestoreFrameGeometry(frame, geometry)
    if not frame or not geometry then
        return
    end

    BaseClearAllPoints(frame)
    BaseSetPoint(frame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", geometry.left, geometry.bottom)
    BaseSetSize(frame, geometry.width, geometry.height)
end

local function GetGeneralChatBottom()
    local bottomGap = InterpolateByLayoutScale(OAK_GENERAL_BOTTOM_GAP_PP, OAK_GENERAL_BOTTOM_GAP_NATIVE)
    return ScalePhysicalPixels(bottomGap) + OAK_EDITBOX_BELOW_FRAME_OFFSET + OAK_EDITBOX_HEIGHT
end

local function BuildGeneralChatGeometry(existing)
    local width = existing and existing.width
    local height = existing and existing.height

    if not width or width < 260 or width > 900 then
        width = ScaleLayoutLength(OAK_GENERAL_WIDTH)
    end
    if not height or height < 100 or height > 420 then
        height = ScaleLayoutLength(OAK_GENERAL_HEIGHT)
    end

    return {
        left = 0,
        bottom = GetGeneralChatBottom(),
        width = width,
        height = height,
    }
end

local function PlaceLootFrameAboveGeneral(lootFrame, generalFrame)
    if not lootFrame or not generalFrame then
        return
    end

    local generalLeft = generalFrame.GetLeft and generalFrame:GetLeft()
    local generalTop = generalFrame.GetTop and generalFrame:GetTop()
    local generalWidth = generalFrame.GetWidth and generalFrame:GetWidth()

    if not generalLeft or not generalTop or not generalWidth then
        return
    end

    -- In 12.1, FCF_UpdateButtonSide treats an exact left edge (leftDist == 0)
    -- as the right-side button layout. Keep the Blizzard frame one physical
    -- pixel inside the edge; EUI's background still provides the visual flush.
    local left = generalLeft + ScalePhysicalPixels(OAK_LOOT_LEFT_INSET_PP)
    local bottom = generalTop + OAK_LOOT_BASE_GAP + OAK_LOOT_FLUSH_NUDGE
    local width = generalWidth
    local height = ScaleLayoutLength(OAK_LOOT_HEIGHT)

    BaseClearAllPoints(lootFrame)
    BaseSetPoint(lootFrame, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    BaseSetSize(lootFrame, width, height)

    return true
end

local function DisableLootMinimizeButton(frame)
    if not frame or not frame.GetName then
        return
    end

    local name = frame:GetName()

    -- Seed the same left-side state that a user gets by unlocking, nudging the
    -- frame left, and locking it again. The small inset above keeps Blizzard's
    -- next button-side recalculation from immediately changing it back.
    if type(FCF_SetButtonSide) == "function" then
        pcall(FCF_SetButtonSide, frame, "left", true)
    end

    local buttonFrame = _G[name .. "ButtonFrame"]
    if buttonFrame then
        -- Blizzard can fade/show the parent independently of its child.
        buttonFrame:SetAlpha(0)
        buttonFrame:EnableMouse(false)
    end

    local minimizeButton = _G[name .. "MinimizeButton"]
    if not minimizeButton then
        return
    end

    -- Loot is intentionally a permanent standalone window. Blizzard's
    -- minimize button calls FCF_MinimizeFrame, which moves that window into
    -- the minimized side-tab layout instead of preserving OakUI's placement.
    minimizeButton:SetAlpha(0)
    minimizeButton:EnableMouse(false)
    minimizeButton:Hide()
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

local function SaveDockedChatWindow(frame, numID, locked)
    if not frame or not numID then
        return
    end

    SaveChatWindowPresentation(frame, numID, true, locked ~= false)
    SaveChatWindowFont(frame, numID, 14)
    ForceTransparency(frame, numID)
end

local function GetNextDockIndex()
    if GENERAL_CHAT_DOCK and type(FCFDock_GetChatFrames) == "function" then
        local ok, frames = pcall(FCFDock_GetChatFrames, GENERAL_CHAT_DOCK)
        if ok and type(frames) == "table" then
            return #frames + 1
        end
    end
    return 3
end

local function DockChatFrame(frame)
    if not frame or type(FCF_DockFrame) ~= "function" then
        return false
    end

    -- Remove stale server-backed dock metadata before assigning the frame to
    -- Blizzard's current dock list. FCF_DockFrame then persists a numeric slot.
    if type(FCF_UnDockFrame) == "function" then
        pcall(FCF_UnDockFrame, frame)
    end

    local ok = pcall(FCF_DockFrame, frame, GetNextDockIndex())
    return ok and frame.isDocked and true or false
end

local function SaveChatDock()
    if type(FCF_SaveDock) == "function" then
        pcall(FCF_SaveDock)
    end
end

local function SelectDockedChatWindow(frame)
    if frame and type(FCF_SelectDockFrame) == "function" then
        pcall(FCF_SelectDockFrame, frame)
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

local function ApplyChatFrameGroups(frame, groupsToAdd)
    SyncChatFrameGroups(frame, groupsToAdd, OAK_PLAYER_MESSAGE_GROUPS)
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
    local generalGeometry = BuildGeneralChatGeometry(CaptureFrameGeometry(ChatFrame1))
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
    RestoreFrameGeometry(cf1, generalGeometry)
    
    SaveChatWindowPresentation(cf1, 1, true, true)
    SaveChatWindowFont(cf1, 1, 14)
    ForceTransparency(cf1, 1)
    SaveChatWindowPosition(cf1)
    
    SyncChatFrameGroups(cf1, nil, OAK_LOOT_GROUPS)
    ApplyChatFrameGroups(cf1, OAK_GENERAL_PLAYER_GROUPS)

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
    if lootFrame.Show then
        lootFrame:Show()
    end

    PlaceLootFrameAboveGeneral(lootFrame, cf1)

    SaveChatWindowPresentation(lootFrame, lootID, true, true)
    SaveChatWindowFont(lootFrame, lootID, 14)
    ForceTransparency(lootFrame, lootID)
    SaveChatWindowPosition(lootFrame)

    SyncChatFrameGroups(lootFrame, OAK_LOOT_GROUPS, nil)
    ApplyChatFrameGroups(lootFrame, OAK_LOOT_PLAYER_GROUPS)

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
    end

    if tradeFrame then
        if tradeFrame.Show then
            tradeFrame:Show()
        end

        if not DockChatFrame(tradeFrame) then
            if not quiet then
                print("|cffff0000[OakUI Error]|r Could not attach the Trade chat tab to General. Try the chat layout again after the UI finishes loading.")
            end
            return false
        end

        SaveDockedChatWindow(tradeFrame, tradeID, true)

        SyncChatFrameGroups(tradeFrame, { "CHANNEL" }, OAK_LOOT_GROUPS)
        ApplyChatFrameGroups(tradeFrame, OAK_TRADE_PLAYER_GROUPS)
        RouteChannelsToFrame(tradeFrame, GetTradeChannelNames(), cf1, lootFrame)
    elseif not quiet then
        print("|cffff0000[OakUI Error]|r Could not create the Trade chat tab. Try again after leaving combat and after the UI finishes loading.")
    end
    
    if type(FCF_DockUpdate) == "function" then
        FCF_DockUpdate()
    end
    SaveChatDock()
    SelectDockedChatWindow(cf1)
    DisableLootMinimizeButton(lootFrame)
    if addonTable.RefreshChatTabVisibility then
        addonTable.RefreshChatTabVisibility()
    end
    if not quiet then
        print("|cff17ee15[OakUI]|r OakUI Chat layout applied! General and Trade are docked below, Loot is placed above General.")
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

function addonTable.ApplyOakChatWindowGeometry(quiet)
    local generalFrame = ChatFrame1
    local lootFrame = FindChatWindowByName(LOOT or "Loot", "Loot")
    if not generalFrame or not lootFrame then
        return false
    end

    local generalGeometry = BuildGeneralChatGeometry(CaptureFrameGeometry(generalFrame))
    RestoreFrameGeometry(generalFrame, generalGeometry)
    PlaceLootFrameAboveGeneral(lootFrame, generalFrame)

    SaveChatWindowPosition(generalFrame)
    SaveChatWindowPosition(lootFrame)
    DisableLootMinimizeButton(lootFrame)

    if not quiet then
        print("|cff17ee15[OakUI]|r OakUI Chat window placement applied.")
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

function addonTable.QueueOakChatLayoutAfterReload()
    local applied = addonTable.ScheduleChatWindowsAfterEllesmereProfile
        and addonTable.ScheduleChatWindowsAfterEllesmereProfile(true)

    if not applied then
        return false
    end

    if addonTable.MarkOakChatGeometryAfterReload then
        addonTable.MarkOakChatGeometryAfterReload()
    elseif addonTable.MarkOakChatLayoutAfterReload then
        addonTable.MarkOakChatLayoutAfterReload()
    end

    StaticPopupDialogs["OAKUI_CHAT_RELOAD"] = {
        text = "|cff17ee15OAK UI|r\n\nOakUI will apply the chat layout after your next reload, once Blizzard has finished rebuilding chat windows.",
        button1 = "Reload UI",
        button2 = "Later",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("OAKUI_CHAT_RELOAD")
    return true
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
