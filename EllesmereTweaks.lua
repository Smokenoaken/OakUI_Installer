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

local function UnitIsInjured(unit)
    if not UnitExists(unit) then return false end
    local ok, injured = pcall(function()
        local maxHealth = UnitHealthMax(unit) or 0
        local health = UnitHealth(unit) or maxHealth
        return maxHealth > 0 and health < maxHealth
    end)
    return ok and injured == true
end

local playerHealthBelowMax = false
local playerHealthStableTimer
local lastPlayerHealthEventTime = 0
local HEALTH_STABLE_DURATION = 3

local function SetPlayerHealthChanging()
    local wasBelowMax = playerHealthBelowMax
    playerHealthBelowMax = true
    lastPlayerHealthEventTime = GetTime and GetTime() or 0

    if not wasBelowMax and addonTable.RefreshEllesmereVisibilityTweaks then
        addonTable.RefreshEllesmereVisibilityTweaks()
    end

    if playerHealthStableTimer or not C_Timer or not C_Timer.NewTicker then return end
    playerHealthStableTimer = C_Timer.NewTicker(1, function()
        if InCombatLockdown and InCombatLockdown() then return end
        local now = GetTime and GetTime() or 0
        if now - lastPlayerHealthEventTime < HEALTH_STABLE_DURATION then return end

        playerHealthStableTimer:Cancel()
        playerHealthStableTimer = nil
        playerHealthBelowMax = false
        if addonTable.RefreshEllesmereVisibilityTweaks then
            addonTable.RefreshEllesmereVisibilityTweaks()
        end
    end)
end

local function PlayerHealthBelowMax()
    return playerHealthBelowMax or UnitIsInjured("player")
end

local ellesmereUnitFrameVisibilityHooked
local applyingEllesmereVisibility
local visibilityRefreshPending
local groupVisibilityOverrideActive

local function SetFrameVisible(frame, visible)
    if not frame then return end
    frame.oakVisibilityTweaksManaged = true
    frame:SetAlpha(visible and 1 or 0)
end

local function ReleaseFrameVisibility(frame)
    if not frame or not frame.oakVisibilityTweaksManaged then return end
    frame.oakVisibilityTweaksManaged = nil
    frame:SetAlpha(1)
end

local function SetPetFrameVisible(frame, visible)
    if not frame then return end
    SetFrameVisible(frame, visible)
    frame.dfPetHidden = not visible or nil
    if not InCombatLockdown or not InCombatLockdown() then
        if visible then
            if frame.Show then frame:Show() end
        else
            if frame.Hide then frame:Hide() end
        end
    end
end

local function ReleasePetFrameVisibility(frame)
    if not frame then return end
    local wasManaged = frame.oakVisibilityTweaksManaged
    ReleaseFrameVisibility(frame)
    if not wasManaged then return end

    frame.dfPetHidden = nil
    if not InCombatLockdown or not InCombatLockdown() then
        if frame.Show then frame:Show() end
    end
end

local function GetDandersPlayerPetFrame()
    local DF = _G.DandersFrames
    if DF and DF.petFrames and DF.petFrames.player then
        return DF.petFrames.player
    end
    return _G.DandersFrames_Pet_Pet
end

local function GetEllesmereUnitHideNoTarget(unit)
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    local settings = unitFrames and unitFrames[unit]
    if type(settings) ~= "table" or settings.visHideNoTarget == nil then return nil end
    return settings.visHideNoTarget == true
end

local function SyncPlayerPetVisibilityState()
    local playerHidden = GetEllesmereUnitHideNoTarget("player")
    local petHidden = GetEllesmereUnitHideNoTarget("pet")
    -- While grouped, the EUI values are temporarily cleared by OakUI's
    -- group override. Do not let those temporary values change OakUI's
    -- persistent Hide Unit Frames preference.
    if groupVisibilityOverrideActive then
        return playerHidden, petHidden
    end
    if playerHidden ~= nil or petHidden ~= nil then
        local db = EnsureVisibilityDB()
        local enabled = playerHidden == true and petHidden == true
        local changed = db.playerFrameHidden ~= enabled
        db.playerFrameHidden = enabled
        if changed and addonTable.RefreshVisibilityCheckboxes then
            addonTable.RefreshVisibilityCheckboxes()
        end
    end
    return playerHidden, petHidden
end

local function PlayerPetVisibilityOptionsEnabled()
    if not IsEllesmereProvider() then return false end
    local db = EnsureVisibilityDB()
    return db.smartPlayerPetVisibility == true or db.showPlayerWhenInjured == true or db.showPlayerInParty == true
end

local function PlayerVisibilityOverrideEnabled()
    if not PlayerPetVisibilityOptionsEnabled() then return false end
    local playerHidden = GetEllesmereUnitHideNoTarget("player")
    if playerHidden ~= nil then return playerHidden == true end
    return EnsureVisibilityDB().playerFrameHidden == true
end

local function PetVisibilityOverrideEnabled()
    if not PlayerPetVisibilityOptionsEnabled() then return false end
    local petHidden = GetEllesmereUnitHideNoTarget("pet")
    if petHidden ~= nil then return petHidden == true end
    return EnsureVisibilityDB().playerFrameHidden == true
end

local function PlayerIsInGroup()
    return (type(IsInGroup) == "function" and IsInGroup()) or (type(IsInRaid) == "function" and IsInRaid())
end

-- EUI evaluates these visibility predicates independently of OakUI's
-- show-player-in-group preference. Temporarily clearing them while grouped
-- lets EUI own the visible state directly, avoiding a per-frame alpha repair.
-- The original values are restored when the group ends or the active profile
-- changes. This is deliberately transition-driven; it is not a poller.
local GROUP_VISIBILITY_FIELDS = {
    "visOnlyInstances",
    "visHideHousing",
    "visHideMounted",
    "visHideNoTarget",
    "visHideNoEnemy",
}
local groupVisibilityOverride = {
    active = false,
    profileKey = nil,
    saved = {},
}

local function RestoreGroupVisibilityOverride()
    if not groupVisibilityOverride.active then return false end

    for _, entry in ipairs(groupVisibilityOverride.saved) do
        entry.settings[entry.key] = entry.value
    end

    wipe(groupVisibilityOverride.saved)
    groupVisibilityOverride.active = false
    groupVisibilityOverride.profileKey = nil
    groupVisibilityOverrideActive = false
    return true
end

local function ApplyGroupVisibilityOverride(profileKey)
    local unitFrames = GetEllesmereAddonProfile("EllesmereUIUnitFrames")
    if type(unitFrames) ~= "table" then return false end

    for _, unit in ipairs({ "player", "pet" }) do
        local settings = unitFrames[unit]
        if type(settings) == "table" then
            for _, key in ipairs(GROUP_VISIBILITY_FIELDS) do
                groupVisibilityOverride.saved[#groupVisibilityOverride.saved + 1] = {
                    settings = settings,
                    key = key,
                    value = settings[key],
                }
                settings[key] = false
            end
        end
    end

    groupVisibilityOverride.active = #groupVisibilityOverride.saved > 0
    groupVisibilityOverride.profileKey = groupVisibilityOverride.active and profileKey or nil
    groupVisibilityOverrideActive = groupVisibilityOverride.active
    return groupVisibilityOverride.active
end

local function SyncGroupVisibilityOverride()
    local db = EnsureVisibilityDB()
    local profileKey = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.activeProfile or nil
    local groupRequested = IsEllesmereProvider()
        and db.showPlayerInParty == true
        and PlayerIsInGroup()

    if groupVisibilityOverride.active
        and groupRequested
        and groupVisibilityOverride.profileKey == profileKey
    then
        return false
    end

    local changed = false
    if groupVisibilityOverride.active then
        RestoreGroupVisibilityOverride()
        changed = true
    end

    if groupRequested and db.playerFrameHidden == true then
        ApplyGroupVisibilityOverride(profileKey)
        return true
    end

    return changed
end

local function RefreshEllesmereUnitFrameVisibility()
    local ns = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    if not ns or type(ns.UpdateFrameVisibility) ~= "function" or applyingEllesmereVisibility then
        return false
    end

    applyingEllesmereVisibility = true
    pcall(ns.UpdateFrameVisibility)
    applyingEllesmereVisibility = nil
    return true
end

local function SmartPlayerVisibilityEnabled()
    local db = EnsureVisibilityDB()
    return db.smartPlayerPetVisibility == true or db.showPlayerWhenInjured == true
end

local function GetEllesmerePlayerVisibilityTarget()
    local frame = _G.EllesmereUIUnitFrames_Player
    return frame and (frame._visWrap or frame)
end

local function HookEllesmereUnitFrameVisibility()
    if ellesmereUnitFrameVisibilityHooked then return end
    local ns = type(_G.EllesmereUIUnitFrames) == "table" and _G.EllesmereUIUnitFrames
    if not ns or type(ns.UpdateFrameVisibility) ~= "function" or not hooksecurefunc then return end

    ellesmereUnitFrameVisibilityHooked = true
    hooksecurefunc(ns, "UpdateFrameVisibility", function()
        if applyingEllesmereVisibility then return end
        if visibilityRefreshPending then return end
        visibilityRefreshPending = true
        C_Timer.After(0, function()
            visibilityRefreshPending = nil
            if addonTable.RefreshEllesmereVisibilityTweaks then
                addonTable.RefreshEllesmereVisibilityTweaks(true)
            end
        end)
    end)
end

local function ShouldForcePlayerFrameShown()
    if not PlayerVisibilityOverrideEnabled() then return false end
    local db = EnsureVisibilityDB()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitExists("target") then return true end
    if SmartPlayerVisibilityEnabled() and PlayerHealthBelowMax() then return true end
    if db.showPlayerInParty == true and PlayerIsInGroup() then return true end
    if SmartPlayerVisibilityEnabled() and UnitIsInjured("pet") then return true end
    return false
end

local function ApplyPlayerFrameVisibilityOverride()
    local target = GetEllesmerePlayerVisibilityTarget()
    if not target then return end
    if ShouldForcePlayerFrameShown() then
        target:SetAlpha(1)
    end
end

function addonTable.RefreshEllesmereVisibilityTweaks()
    HookEllesmereUnitFrameVisibility()
    SyncPlayerPetVisibilityState()
    local nativeVisibilityRefreshed = false
    local groupVisibilityChanged = SyncGroupVisibilityOverride()
    if groupVisibilityChanged then
        nativeVisibilityRefreshed = RefreshEllesmereUnitFrameVisibility()
        SyncPlayerPetVisibilityState()
    end
    local playerOverrideEnabled = PlayerVisibilityOverrideEnabled()
    local petOverrideEnabled = PetVisibilityOverrideEnabled()

    if not playerOverrideEnabled and not petOverrideEnabled then
        local playerFrame = _G.EllesmereUIUnitFrames_Player
        ReleaseFrameVisibility(playerFrame and playerFrame._visWrap or playerFrame)
        ReleasePetFrameVisibility(_G.EllesmereUIUnitFrames_Pet)
        ReleasePetFrameVisibility(GetDandersPlayerPetFrame())
        return
    end

    local db = EnsureVisibilityDB()
    local hasTarget = UnitExists("target")
    if InCombatLockdown and InCombatLockdown() then
        if playerOverrideEnabled then
            ApplyPlayerFrameVisibilityOverride()
        else
            local playerFrame = _G.EllesmereUIUnitFrames_Player
            ReleaseFrameVisibility(playerFrame and playerFrame._visWrap or playerFrame)
        end
        if petOverrideEnabled then
            SetPetFrameVisible(_G.EllesmereUIUnitFrames_Pet, UnitExists("pet"))
            SetPetFrameVisible(GetDandersPlayerPetFrame(), UnitExists("pet"))
        else
            ReleasePetFrameVisibility(_G.EllesmereUIUnitFrames_Pet)
            ReleasePetFrameVisibility(GetDandersPlayerPetFrame())
        end
        return
    end

    local smartPlayer = SmartPlayerVisibilityEnabled()
    local showPlayerForInjury = smartPlayer and PlayerHealthBelowMax()
    local showPlayerForParty = db.showPlayerInParty == true and PlayerIsInGroup()
    local showPetForInjury = smartPlayer and UnitIsInjured("pet")
    local shouldShowPlayer = hasTarget or showPlayerForInjury or showPlayerForParty or showPetForInjury
    local shouldShowPet = hasTarget or showPetForInjury or showPlayerForInjury
    local playerFrame = _G.EllesmereUIUnitFrames_Player
    local petFrame = _G.EllesmereUIUnitFrames_Pet
    local dandersPetFrame = GetDandersPlayerPetFrame()

    if not nativeVisibilityRefreshed then
        RefreshEllesmereUnitFrameVisibility()
    end

    if playerOverrideEnabled then
        SetFrameVisible(playerFrame and playerFrame._visWrap or playerFrame, shouldShowPlayer)
    else
        ReleaseFrameVisibility(playerFrame and playerFrame._visWrap or playerFrame)
    end

    if petOverrideEnabled then
        SetPetFrameVisible(petFrame, shouldShowPet and UnitExists("pet"))
        SetPetFrameVisible(dandersPetFrame, shouldShowPet and UnitExists("pet"))
    else
        ReleasePetFrameVisibility(petFrame)
        ReleasePetFrameVisibility(dandersPetFrame)
    end
end

local originalResetIdleTimer
local chatFadeApplied
local CHAT_LINE_FADE_DEFAULT_DELAY = 15

local function GetEllesmereChatAddon()
    if _G.EllesmereUI and _G.EllesmereUI.Lite and _G.EllesmereUI.Lite.GetAddon then
        local addon = _G.EllesmereUI.Lite.GetAddon("EllesmereUIChat", true)
        return addon and addon.ECHAT
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

local function ApplyChatLineFadeToFrame(chatFrame)
    if not chatFrame or chatFrame:IsForbidden() then return end

    if ChatFadeDisabled() then
        chatFrame:SetAlpha(1)
        chatFrame:SetFading(false)
    elseif ChatLineFadeEnabled() then
        chatFrame:SetAlpha(1)
        chatFrame:SetFading(true)
        chatFrame:SetTimeVisible(GetChatLineFadeDelay())
        if chatFrame.SetFadeDuration then
            chatFrame:SetFadeDuration(0.35)
        end
    else
        chatFrame:SetFading(false)
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
    local ECHAT = GetEllesmereChatAddon()
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
        ApplyChatLineFadeToFrame(_G["ChatFrame" .. i])
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
    ScheduleRefresh("visibility", 0, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("visibilityInit", 0.5, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("visibilityLate", 1.5, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
    ScheduleRefresh("tooltip", 0.2, addonTable.RefreshEllesmereTooltipAnchor, 1)
    ScheduleRefresh("specialActionBars", 0.3, addonTable.RefreshEllesmereSpecialActionBarVisibility, 1)
end

-- GROUP_ROSTER_UPDATE can arrive just before the group APIs reflect the final
-- roster. One coalesced settle pass makes the reversible unit-frame override
-- reliable on both join and leave without adding an OnUpdate/polling loop.
local groupVisibilitySettleTimer
local function ScheduleGroupVisibilitySettle()
    if groupVisibilitySettleTimer then
        groupVisibilitySettleTimer:Cancel()
    end
    groupVisibilitySettleTimer = C_Timer.NewTimer(0.2, function()
        groupVisibilitySettleTimer = nil
        if addonTable.RefreshEllesmereVisibilityTweaks then
            addonTable.RefreshEllesmereVisibilityTweaks()
        end
    end)
end

local function ScheduleDeprecatedResourceCleanup()
    ScheduleRefresh("tooltipSpec", 0.2, addonTable.RefreshEllesmereTooltipAnchor, 1)
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("UPDATE_CHAT_WINDOWS")
frame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
frame:RegisterEvent("LFG_UPDATE")
frame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
frame:RegisterEvent("LFG_ROLE_CHECK_UPDATE")
frame:RegisterEvent("LFG_PROPOSAL_UPDATE")
frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGOUT" then
        if groupVisibilitySettleTimer then
            groupVisibilitySettleTimer:Cancel()
            groupVisibilitySettleTimer = nil
        end
        RestoreGroupVisibilityOverride()
        return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if unit ~= "player" and unit ~= "pet" then return end
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        ScheduleLayoutRefresh()
        ScheduleChatLineFadeRefresh()
    elseif event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS" then
        -- EUI turns fading off when it skins a newly created chat frame. The
        -- OakUI Loot window is created after the initial chat pass, so apply
        -- the selected per-line fade settings again after Blizzard/EUI finish
        -- rebuilding the chat windows.
        ScheduleChatLineFadeRefresh()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_PET" or event == "GROUP_ROSTER_UPDATE" then
        if event == "UNIT_HEALTH" and unit == "player" then
            SetPlayerHealthChanging()
        end
        ScheduleRefresh("visibility", 0, addonTable.RefreshEllesmereVisibilityTweaks, 0.1)
        if event == "GROUP_ROSTER_UPDATE" then
            ScheduleGroupVisibilitySettle()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
        ScheduleDeprecatedResourceCleanup()
    elseif event == "UPDATE_EXTRA_ACTIONBAR" or event == "LFG_UPDATE" or event == "LFG_QUEUE_STATUS_UPDATE" or event == "LFG_ROLE_CHECK_UPDATE" or event == "LFG_PROPOSAL_UPDATE" then
        ScheduleRefresh("specialActionBars", 0, addonTable.RefreshEllesmereSpecialActionBarVisibility, 0.25)
    end
end)
