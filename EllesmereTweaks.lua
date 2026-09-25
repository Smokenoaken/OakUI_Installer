local addonName, addonTable = ...

local function IsEllesmereProvider()
    return addonTable.Profiles and addonTable.Profiles.BASE_UI_PROVIDER == "Ellesmere"
end

local function EnsureVisibilityDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.visibility then OakUI_DB.visibility = {} end
    return OakUI_DB.visibility
end

local function GetEllesmereAddonProfile(addonKey)
    if type(_G.EllesmereUIDB) ~= "table" then return nil end
    local profileKey = _G.EllesmereUIDB.activeProfile
    local profiles = _G.EllesmereUIDB.profiles
    local profile = profileKey and profiles and profiles[profileKey]
    if type(profile) ~= "table" then return nil end
    local addons = profile.addons
    return type(addons) == "table" and addons[addonKey] or nil
end

local function GetEllesmereChatConfig()
    local chat = GetEllesmereAddonProfile("EllesmereUIChat")
    return chat and chat.chat
end

local function GetEllesmereChatProfileKey()
    local profileDB = _G.EllesmereUIDB
    return type(profileDB) == "table" and profileDB.activeProfile or "__default"
end

local originalResetIdleTimer
local chatFadeApplied
local CHAT_LINE_FADE_DEFAULT_DELAY = 15

local function GetEllesmereChatModule()
    local EUI = _G.EllesmereUI
    if not EUI then return nil end

    -- EllesmereUI 12.1 modules expose their namespace through _ModuleNS;
    -- EllesmereUIChat is not a Lite NewAddon, so Lite.GetAddon() returns nil.
    local module = EUI._ModuleNS and EUI._ModuleNS.EllesmereUIChat
    if module then return module end

    -- Keep compatibility with older EUI builds that registered chat through
    -- the Lite addon registry.
    if EUI.Lite and EUI.Lite.GetAddon then
        return EUI.Lite.GetAddon("EllesmereUIChat", true)
    end
    return nil
end

local function ChatLineFadeEnabled()
    local db = EnsureVisibilityDB()
    return IsEllesmereProvider() and db.chatLineFade == true and db.disableChatFade ~= true
end

local function ChatFadeDisabled()
    return IsEllesmereProvider() and EnsureVisibilityDB().disableChatFade == true
end

local function GetChatLineFadeDelay()
    local cfg = GetEllesmereChatConfig()
    local delay = tonumber(cfg and cfg.idleFadeDelay) or CHAT_LINE_FADE_DEFAULT_DELAY
    return math.max(1, math.min(120, delay))
end

function addonTable.GetOakChatLineFadeDelay()
    return GetChatLineFadeDelay()
end

function addonTable.SetOakChatLineFadeDelay(value)
    local delay = tonumber(value) or CHAT_LINE_FADE_DEFAULT_DELAY
    delay = math.max(1, math.min(120, math.floor(delay + 0.5)))
    local cfg = GetEllesmereChatConfig()
    if type(cfg) ~= "table" then return end
    cfg.idleFadeDelay = delay
    if addonTable.RefreshEllesmereChatLineFade then
        addonTable.RefreshEllesmereChatLineFade()
    end
end

local function ApplyChatLineFadeToTarget(target)
    if not target or (target.IsForbidden and target:IsForbidden()) then return end

    if ChatFadeDisabled() then
        target:SetAlpha(1)
        target:SetFading(false)
    elseif ChatLineFadeEnabled() then
        target:SetAlpha(1)
        target:SetFading(true)
        target:SetTimeVisible(GetChatLineFadeDelay())
        if target.SetFadeDuration then
            target:SetFadeDuration(0.35)
        end
    else
        target:SetFading(false)
    end
end

local function ApplyChatLineFadeScrollState(visibleFrame)
    if not visibleFrame or not ChatLineFadeEnabled() or not visibleFrame.GetScrollOffset then return end

    local offset = visibleFrame:GetScrollOffset() or 0
    local shouldFade = offset <= 0
    if visibleFrame.oakChatLineFadeScrollState == shouldFade then return end
    visibleFrame.oakChatLineFadeScrollState = shouldFade

    if shouldFade then
        visibleFrame:SetFading(true)
        visibleFrame:SetTimeVisible(GetChatLineFadeDelay())
        if visibleFrame.SetFadeDuration then
            visibleFrame:SetFadeDuration(0.35)
        end
    else
        -- Native chat reveals faded history while the user is scrolled back.
        -- EUI's visible message frame needs the same state transition because
        -- it owns a separate ScrollingMessageFrame from Blizzard's data plane.
        visibleFrame:SetAlpha(1)
        visibleFrame:SetFading(false)
    end
end

local function HookChatLineFadeScrollState(visibleFrame)
    if not visibleFrame or visibleFrame.oakChatLineFadeScrollHooked
        or not visibleFrame.AddOnDisplayRefreshedCallback then
        return
    end

    visibleFrame.oakChatLineFadeScrollHooked = true
    visibleFrame:AddOnDisplayRefreshedCallback(function()
        ApplyChatLineFadeScrollState(visibleFrame)
    end)
end

local function ApplyChatLineFadeToFrame(chatFrame, chatModule)
    if not chatFrame then return end

    -- EllesmereUI 12.1 renders visible chat text through its own
    -- ScrollingMessageFrame. The Blizzard ChatFrame remains the data plane
    -- (and is still used for combat-log passthrough), so keep both paths in
    -- sync without hooking message delivery.
    ApplyChatLineFadeToTarget(chatFrame)

    local chatWindows = chatModule and chatModule._chatWins
    local chatWindow = type(chatWindows) == "table" and chatWindows[chatFrame]
    local visibleFrame = chatWindow and chatWindow.smf
    if visibleFrame and visibleFrame ~= chatFrame then
        visibleFrame.oakChatLineFadeScrollState = nil
        ApplyChatLineFadeToTarget(visibleFrame)
        HookChatLineFadeScrollState(visibleFrame)
        ApplyChatLineFadeScrollState(visibleFrame)
    end

    -- Do not hook ChatFrame:AddMessage or other chat-frame methods here.
    -- Retail chat history carries protected tokens for whispers/monster speech,
    -- and addon hooks in that delivery path can taint Blizzard's HistoryKeeper.
end

local function ApplyEllesmereIdleFadePreference()
    local db = EnsureVisibilityDB()
    local cfg = GetEllesmereChatConfig()
    if type(cfg) ~= "table" then return false end

    if ChatLineFadeEnabled() then
        -- A user can switch directly from Disable Chat Fade to Chat Line
        -- Fade. Restore that older suppression before saving the line-fade
        -- baseline, otherwise the two saved states would overlap.
        if db.chatFadeDisabledApplied then
            if cfg.idleFadeStrength == 0 then
                cfg.idleFadeStrength = db.chatIdleFadeStrengthBeforeDisable or 100
            end
            db.chatIdleFadeStrengthBeforeDisable = nil
            db.chatFadeDisabledApplied = nil
        end
        db.chatLineFadeSuppressionProfiles = db.chatLineFadeSuppressionProfiles or {}
        local profileKey = GetEllesmereChatProfileKey()
        if type(db.chatLineFadeSuppressionProfiles[profileKey]) ~= "table" then
            local enabledBefore = cfg.idleFadeEnabled
            local strengthBefore = cfg.idleFadeStrength

            -- Migrate the pre-profile-specific baseline once, if one exists.
            if db.chatLineFadeSuppressionApplied then
                enabledBefore = db.chatLineFadeIdleFadeEnabledBefore
                strengthBefore = db.chatLineFadeIdleFadeStrengthBefore
                db.chatLineFadeSuppressionApplied = nil
                db.chatLineFadeIdleFadeEnabledBefore = nil
                db.chatLineFadeIdleFadeStrengthBefore = nil
            end

            db.chatLineFadeSuppressionProfiles[profileKey] = {
                idleFadeEnabled = enabledBefore,
                idleFadeStrength = strengthBefore,
            }
        end
        -- Blizzard owns the per-line fade. Disable EUI's independent
        -- full-window timer so the two fade controllers cannot fight.
        cfg.idleFadeEnabled = false
        cfg.idleFadeStrength = 0
        return true
    end

    local lineFadeRestored = false
    local suppressionProfiles = db.chatLineFadeSuppressionProfiles
    local profileKey = GetEllesmereChatProfileKey()
    local baseline = type(suppressionProfiles) == "table" and suppressionProfiles[profileKey]
    if type(baseline) == "table" then
        cfg.idleFadeEnabled = baseline.idleFadeEnabled
        cfg.idleFadeStrength = baseline.idleFadeStrength
        suppressionProfiles[profileKey] = nil
        lineFadeRestored = true
        if next(suppressionProfiles) == nil then
            db.chatLineFadeSuppressionProfiles = nil
        end
    end

    if ChatFadeDisabled() then
        if not db.chatFadeDisabledApplied and cfg.idleFadeStrength ~= 0 then
            db.chatIdleFadeStrengthBeforeDisable = cfg.idleFadeStrength
        end
        cfg.idleFadeStrength = 0
        db.chatFadeDisabledApplied = true
        return true
    end

    if db.chatFadeDisabledApplied then
        if cfg.idleFadeStrength == 0 then
            cfg.idleFadeStrength = db.chatIdleFadeStrengthBeforeDisable or 100
        end
        db.chatFadeDisabledApplied = nil
        return true
    end

    return lineFadeRestored
end

local function ApplyChatLineFade()
    local chatModule = GetEllesmereChatModule()
    local ECHAT = chatModule and chatModule.ECHAT
    if ECHAT and type(ECHAT.ResetIdleTimer) == "function" and not originalResetIdleTimer then
        originalResetIdleTimer = ECHAT.ResetIdleTimer
    end

    local idleFadeChanged = ApplyEllesmereIdleFadePreference()
    local enabled = ChatLineFadeEnabled()
    local fadeDisabled = ChatFadeDisabled()

    -- Run EUI's original reset once while idle fading is disabled. This
    -- cancels any already-running EUI idle timer and clears its active state.
    if ECHAT and originalResetIdleTimer and enabled and idleFadeChanged then
        pcall(originalResetIdleTimer)
    end

    for i = 1, NUM_CHAT_WINDOWS or 20 do
        ApplyChatLineFadeToFrame(_G["ChatFrame" .. i], chatModule)
    end

    if ECHAT and originalResetIdleTimer then
        if enabled then
            ECHAT.ResetIdleTimer = function()
                local cfg = GetEllesmereChatConfig()
                if type(cfg) == "table" and (cfg.idleFadeEnabled ~= false or cfg.idleFadeStrength ~= 0) then
                    cfg.idleFadeEnabled = false
                    cfg.idleFadeStrength = 0
                    -- EUI may have enabled its timer from an options refresh;
                    -- cancel that timer before keeping the chat fully opaque.
                    pcall(originalResetIdleTimer)
                end
                if ECHAT.SetIdleFadeAlpha then
                    ECHAT.SetIdleFadeAlpha(1)
                end
                for i = 1, NUM_CHAT_WINDOWS or 20 do
                    local cf = _G["ChatFrame" .. i]
                    if cf then cf:SetAlpha(1) end
                end
            end
            if ECHAT.SetIdleFadeAlpha then
                ECHAT.SetIdleFadeAlpha(1)
            end
        elseif ECHAT.ResetIdleTimer ~= originalResetIdleTimer then
            ECHAT.ResetIdleTimer = originalResetIdleTimer
        end

        if fadeDisabled then
            if ECHAT.SetIdleFadeAlpha then
                pcall(ECHAT.SetIdleFadeAlpha, 1)
            end
            for i = 1, NUM_CHAT_WINDOWS or 20 do
                local cf = _G["ChatFrame" .. i]
                if cf then cf:SetAlpha(1) end
            end
        end

        if idleFadeChanged then
            if ECHAT.RefreshVisibility then
                pcall(ECHAT.RefreshVisibility)
            end
            if ECHAT.ResetIdleTimer then
                pcall(ECHAT.ResetIdleTimer)
            end
        end
    end
end

function addonTable.RefreshEllesmereChatLineFade()
    local db = EnsureVisibilityDB()
    if not ChatLineFadeEnabled() and not ChatFadeDisabled() and not db.chatFadeDisabledApplied and not chatFadeApplied then return end
    ApplyChatLineFade()
    chatFadeApplied = ChatLineFadeEnabled() or ChatFadeDisabled() or EnsureVisibilityDB().chatFadeDisabledApplied == true
end

function addonTable.RefreshEllesmereResourceAnchor(force)
    if InCombatLockdown and InCombatLockdown() then return end

    local db = EnsureVisibilityDB()
    db.compactClassResource = false
end

local TOOLTIP_ANCHOR_KEY = "OakUI_Tooltip"
local tooltipAnchorFrame
local tooltipAnchorRegistered

local function TooltipAnchorEnabled()
    -- Disabled pending a safer integration path. Hooking Blizzard's tooltip
    -- anchor pipeline can taint secure tooltip data processing.
    return false
end

local function EnsureTooltipAnchorFrame()
    if tooltipAnchorFrame then return tooltipAnchorFrame end

    tooltipAnchorFrame = CreateFrame("Frame", "OakUI_EllesmereTooltipAnchor", UIParent)
    tooltipAnchorFrame:SetSize(180, 42)
    tooltipAnchorFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 170)
    tooltipAnchorFrame:SetFrameStrata("TOOLTIP")
    tooltipAnchorFrame:SetAlpha(0)
    tooltipAnchorFrame:EnableMouse(false)
    tooltipAnchorFrame:Hide()
    return tooltipAnchorFrame
end

local function GetTooltipAnchorPosition()
    local db = EnsureVisibilityDB()
    if type(db.tooltipAnchorPosition) == "table" and db.tooltipAnchorPosition.point then
        return db.tooltipAnchorPosition
    end
    return { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 170 }
end

local function ApplyTooltipAnchorPosition(force)
    if not force and _G.EllesmereUI and _G.EllesmereUI._unlockActive then return end
    local frame = EnsureTooltipAnchorFrame()
    local pos = GetTooltipAnchorPosition()
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "BOTTOMRIGHT", UIParent, pos.relPoint or pos.point or "BOTTOMRIGHT", pos.x or -24, pos.y or 170)
end

local function RegisterTooltipUnlockElement()
    if not TooltipAnchorEnabled() or tooltipAnchorRegistered then return end
    if not _G.EllesmereUI or not _G.EllesmereUI.RegisterUnlockElements or not _G.EllesmereUI.MakeUnlockElement then return end

    local MK = _G.EllesmereUI.MakeUnlockElement
    local elements = {
        MK({
            key = TOOLTIP_ANCHOR_KEY,
            label = "Tooltip Anchor",
            group = "OakUI",
            order = 900,
            noResize = true,
            noAnchorTarget = true,
            getFrame = EnsureTooltipAnchorFrame,
            getSize = function()
                return 180, 42
            end,
            savePos = function(_, point, relPoint, x, y)
                EnsureVisibilityDB().tooltipAnchorPosition = {
                    point = point or "BOTTOMRIGHT",
                    relPoint = relPoint or point or "BOTTOMRIGHT",
                    x = x or -24,
                    y = y or 170,
                }
                ApplyTooltipAnchorPosition(true)
            end,
            loadPos = function()
                return GetTooltipAnchorPosition()
            end,
            clearPos = function()
                EnsureVisibilityDB().tooltipAnchorPosition = nil
                ApplyTooltipAnchorPosition(true)
            end,
            applyPos = function()
                ApplyTooltipAnchorPosition(true)
            end,
            isHidden = function()
                return not TooltipAnchorEnabled()
            end,
        }),
    }

    _G.EllesmereUI:RegisterUnlockElements(elements)
    tooltipAnchorRegistered = true
end

local function UnregisterTooltipUnlockElement()
    if not tooltipAnchorRegistered then return end
    if _G.EllesmereUI and _G.EllesmereUI.UnregisterUnlockElement then
        _G.EllesmereUI:UnregisterUnlockElement(TOOLTIP_ANCHOR_KEY)
    end
    tooltipAnchorRegistered = nil
end

function addonTable.RefreshEllesmereTooltipAnchor()
    if not IsEllesmereProvider() then return end
    EnsureVisibilityDB().tooltipAnchor = false
    local anchorFrame = EnsureTooltipAnchorFrame()
    ApplyTooltipAnchorPosition()

    if TooltipAnchorEnabled() then
        anchorFrame:Show()
        RegisterTooltipUnlockElement()
    else
        anchorFrame:Hide()
        UnregisterTooltipUnlockElement()
    end
end

local function RestoreAlwaysVisibleActionBar(settings)
    if type(settings) ~= "table" then return end
    settings.barVisibility = "always"
    settings.mouseoverEnabled = false
    settings.alwaysHidden = false
    settings.combatHideEnabled = false
    settings.combatShowEnabled = false
    settings.mouseoverAlpha = settings._savedBarAlpha or settings.mouseoverAlpha or 1
end

local function GetEllesmereActionBarSettings(key)
    local actionBars = GetEllesmereAddonProfile("EllesmereUIActionBars")
    local bars = actionBars and actionBars.bars
    if type(bars) ~= "table" then return nil end
    if type(bars[key]) == "table" then return bars[key] end
    for _, settings in ipairs(bars) do
        if type(settings) == "table" and settings.key == key then
            return settings
        end
    end
    return nil
end

function addonTable.RefreshEllesmereSpecialActionBarVisibility()
    if not IsEllesmereProvider() then return end

    RestoreAlwaysVisibleActionBar(GetEllesmereActionBarSettings("ExtraActionButton"))
    RestoreAlwaysVisibleActionBar(GetEllesmereActionBarSettings("QueueStatus"))

    for _, frame in ipairs({
        _G.ExtraAbilityContainer,
        _G.ExtraActionBarFrame,
        _G.ZoneAbilityFrame,
        _G.EllesmereEAB_ExtraActionButton,
        _G.QueueStatusButton,
        _G.EllesmereEAB_QueueStatus,
    }) do
        if frame and frame.SetAlpha then
            frame:SetAlpha(1)
        end
    end
end

local frame = CreateFrame("Frame")
local pending = {}
local lastRefresh = {}

local function ScheduleRefresh(key, delay, func, minInterval)
    if pending[key] then return end
    local now = GetTime and GetTime() or 0
    if minInterval and lastRefresh[key] then
        local remaining = minInterval - (now - lastRefresh[key])
        if remaining > 0 then
            delay = math.max(delay or 0, remaining)
        end
    end
    pending[key] = true
    C_Timer.After(delay or 0, function()
        pending[key] = nil
        lastRefresh[key] = GetTime and GetTime() or 0
        func()
    end)
end

local function ScheduleChatLineFadeRefresh()
    local db = EnsureVisibilityDB()
    if not IsEllesmereProvider()
        or (not ChatLineFadeEnabled() and not ChatFadeDisabled() and not db.chatFadeDisabledApplied and not chatFadeApplied)
    then
        return
    end

    -- EUI can finish a chat skin pass after UPDATE_CHAT_WINDOWS, especially
    -- when it creates or rebuilds the Loot window. Reapply only in response
    -- to those lifecycle events; do not poll chat frames every frame.
    ScheduleRefresh("chat", 0.1, addonTable.RefreshEllesmereChatLineFade, 0.1)
    ScheduleRefresh("chatLate", 0.3, addonTable.RefreshEllesmereChatLineFade, 0.1)
end

function addonTable.QueueEllesmereChatLineFadeRefresh()
    ScheduleChatLineFadeRefresh()
end

local function ScheduleLayoutRefresh()
    ScheduleRefresh("tooltip", 0.2, addonTable.RefreshEllesmereTooltipAnchor, 1)
    ScheduleRefresh("specialActionBars", 0.3, addonTable.RefreshEllesmereSpecialActionBarVisibility, 1)
end

local function ScheduleDeprecatedResourceCleanup()
    ScheduleRefresh("tooltipSpec", 0.2, addonTable.RefreshEllesmereTooltipAnchor, 1)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
frame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
frame:RegisterEvent("LFG_UPDATE")
frame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
frame:RegisterEvent("LFG_ROLE_CHECK_UPDATE")
frame:RegisterEvent("LFG_PROPOSAL_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ScheduleLayoutRefresh()
        ScheduleChatLineFadeRefresh()
    elseif event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS" then
        -- EUI turns fading off when it skins a newly created chat frame. The
        -- OakUI Loot window is created after the initial chat pass, so apply
        -- the selected per-line fade settings again after Blizzard/EUI finish
        -- rebuilding the chat windows.
        ScheduleChatLineFadeRefresh()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
        ScheduleDeprecatedResourceCleanup()
    elseif event == "UPDATE_EXTRA_ACTIONBAR" or event == "LFG_UPDATE" or event == "LFG_QUEUE_STATUS_UPDATE" or event == "LFG_ROLE_CHECK_UPDATE" or event == "LFG_PROPOSAL_UPDATE" then
        ScheduleRefresh("specialActionBars", 0, addonTable.RefreshEllesmereSpecialActionBarVisibility, 0.25)
    end
end)
