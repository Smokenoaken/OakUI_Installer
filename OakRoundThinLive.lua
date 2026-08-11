local addonName, addonTable = ...

local DRAGON_RIDING_UNLOCK_KEY = "EDR_Cluster"
local CHAT_BORDER_PROPERTY = "_oakRoundThinChatBorder"
local DRAGON_RIDING_BORDER_PROPERTY = "_oakRoundThinDragonRidingBorder"
local BAR_BORDER_PROPERTY = "_oakRoundThinDragonBarBorder"
local CHAT_BORDER_FIELDS = {
    "panelBorderTexture", "panelBorderThickness", "panelBorderColorMode",
    "panelBorderColor", "panelBorderOpacity", "panelBorderBehind",
    "panelBorderOffsetX", "panelBorderOffsetY", "panelBorderShiftX", "panelBorderShiftY",
    "innerBorderColor", "innerBorderColorMode", "hideBorders",
    "tabBorderTexture", "tabBorderThickness", "tabBorderColorMode",
    "tabBorderColor", "tabBorderOpacity", "tabBorderOffsetX", "tabBorderOffsetY",
    "tabBorderShiftX", "tabBorderShiftY",
}
local OAK_NIL = "__OAKUI_NIL__"

local function GetVisibilityDB()
    OakUI_DB = OakUI_DB or {}
    OakUI_DB.visibility = OakUI_DB.visibility or {}
    return OakUI_DB.visibility
end

local function GetFrameLevel(frame)
    if not frame or type(frame.GetFrameLevel) ~= "function" then return 0 end
    local ok, level = pcall(frame.GetFrameLevel, frame)
    return ok and tonumber(level) or 0
end

local function EnsureOakRoundThinRenderer()
    if addonTable.RegisterOakMedia then
        addonTable.RegisterOakMedia()
    elseif addonTable.RegisterOakFonts then
        addonTable.RegisterOakFonts()
    end
    if addonTable.RegisterOakRoundThinBorderRenderer then
        addonTable.RegisterOakRoundThinBorderRenderer()
    end
end

local function ResolveUnlockFrame(key)
    local EUI = _G.EllesmereUI
    local registry = EUI and EUI._unlockRegisteredElements
    local element = registry and registry[key]
    if element then
        if type(element.getFrame) == "function" then
            local ok, frame = pcall(element.getFrame, key)
            if ok and frame then return frame end
        end
        if element.frame then return element.frame end
    end
    return _G[key]
end

local function ApplyFrameOverlay(frame, property, enabled)
    if not frame then return false end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if ok and forbidden then return false end
    end

    local borderFrame = frame[property]
    if not enabled then
        if borderFrame then
            if addonTable.HideOakRoundThinBorderFrame then
                pcall(addonTable.HideOakRoundThinBorderFrame, borderFrame)
            end
            if borderFrame.Hide then borderFrame:Hide() end
        end
        return false
    end

    EnsureOakRoundThinRenderer()
    if not addonTable.ApplyOakRoundThinBorderFrame then return false end
    if not borderFrame then
        borderFrame = CreateFrame("Frame", nil, frame)
        frame[property] = borderFrame
    end
    if not borderFrame.ClearAllPoints or not borderFrame.SetAllPoints then return false end

    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(frame)
    if borderFrame.SetFrameLevel then
        borderFrame:SetFrameLevel(GetFrameLevel(frame) + 8)
    end
    if borderFrame.EnableMouse then borderFrame:EnableMouse(false) end

    addonTable.ApplyOakRoundThinBorderFrame(borderFrame, 1, 0, 0, 0, 1)
    return true
end

local function HideFramePPBorder(frame)
    local PP = _G.EllesmereUI and _G.EllesmereUI.PP
    if not frame or not PP or type(PP.GetBorders) ~= "function" then return false end
    local ok, ppContainer = pcall(PP.GetBorders, frame)
    if not ok then return false end
    if not ppContainer then return false end
    if type(PP.HideBorder) == "function" then pcall(PP.HideBorder, frame) end
    if ppContainer._top then ppContainer._top:SetAlpha(0) end
    if ppContainer._bottom then ppContainer._bottom:SetAlpha(0) end
    if ppContainer._left then ppContainer._left:SetAlpha(0) end
    if ppContainer._right then ppContainer._right:SetAlpha(0) end
    return true
end

local function RestoreFramePPBorder(frame)
    if not frame or not frame._oakRoundThinPPBorderHidden then return end
    local PP = _G.EllesmereUI and _G.EllesmereUI.PP
    if PP and type(PP.ShowBorder) == "function" then pcall(PP.ShowBorder, frame) end
    frame._oakRoundThinPPBorderHidden = nil
end

local function ApplyStatusBarOverlay(statusbar, enabled)
    if not statusbar or type(statusbar.GetStatusBarTexture) ~= "function" then return false end
    local borderFrame = statusbar[BAR_BORDER_PROPERTY]
    if not enabled then
        if borderFrame then
            if addonTable.HideOakRoundThinBorderFrame then
                pcall(addonTable.HideOakRoundThinBorderFrame, borderFrame)
            end
            if borderFrame.Hide then borderFrame:Hide() end
        end
        RestoreFramePPBorder(statusbar)
        return false
    end

    EnsureOakRoundThinRenderer()
    if not addonTable.ApplyOakRoundThinBorderFrame then return false end
    if not borderFrame then
        borderFrame = CreateFrame("Frame", nil, statusbar)
        statusbar[BAR_BORDER_PROPERTY] = borderFrame
    end
    if not borderFrame.ClearAllPoints or not borderFrame.SetAllPoints then return false end

    if HideFramePPBorder(statusbar) then
        statusbar._oakRoundThinPPBorderHidden = true
    end
    borderFrame:ClearAllPoints()
    borderFrame:SetAllPoints(statusbar)
    if borderFrame.SetFrameLevel then
        borderFrame:SetFrameLevel(GetFrameLevel(statusbar) + 8)
    end
    if borderFrame.EnableMouse then borderFrame:EnableMouse(false) end

    addonTable.ApplyOakRoundThinBorderFrame(
        borderFrame, 1, 0, 0, 0, 1, 0, 0, 0, 0,
        statusbar.bg
    )
    return true
end

local function GetDragonRidingBars(rootFrame)
    if not rootFrame or type(rootFrame.GetChildren) ~= "function" then return nil end
    local bars = {}
    local ok, children = pcall(function() return { rootFrame:GetChildren() } end)
    if not ok then return bars end

    for _, child in ipairs(children) do
        if child and type(child.pips) == "table" then
            for _, pip in ipairs(child.pips) do
                if pip and type(pip.GetStatusBarTexture) == "function" then
                    bars[#bars + 1] = pip
                end
            end
        elseif child and type(child.GetStatusBarTexture) == "function" then
            bars[#bars + 1] = child
        end
    end
    return bars
end

local function IsDragonRidingEnabled()
    return GetVisibilityDB().roundThinDragonRiding == true
end

local function GetDragonRidingFrame()
    return ResolveUnlockFrame(DRAGON_RIDING_UNLOCK_KEY)
        or _G.EllesmereUIDragonRidingFrame
end

local function RefreshDragonRidingBorder()
    local rootFrame = GetDragonRidingFrame()
    local enabled = IsDragonRidingEnabled()
    ApplyFrameOverlay(rootFrame, DRAGON_RIDING_BORDER_PROPERTY, false)

    local bars = GetDragonRidingBars(rootFrame)
    if not bars then return false end
    for _, bar in ipairs(bars) do
        ApplyStatusBarOverlay(bar, enabled)
    end
    return enabled and #bars > 0 or false
end

local dragonHooks = setmetatable({}, { __mode = "k" })
local dragonGlobalHooks = {}
local UpdateLiveEventRegistration

local function HookDragonFunction(tbl, name)
    if type(tbl) ~= "table" or type(tbl[name]) ~= "function" or type(hooksecurefunc) ~= "function" then
        return
    end

    local hooks = dragonHooks[tbl]
    if not hooks then
        hooks = {}
        dragonHooks[tbl] = hooks
    end
    if hooks[name] then return end

    hooksecurefunc(tbl, name, function()
        if IsDragonRidingEnabled() then RefreshDragonRidingBorder() end
    end)
    hooks[name] = true
end

local function HookDragonGlobal(name)
    if dragonGlobalHooks[name] or type(_G[name]) ~= "function" or type(hooksecurefunc) ~= "function" then
        return
    end

    hooksecurefunc(name, function()
        if IsDragonRidingEnabled() then RefreshDragonRidingBorder() end
    end)
    dragonGlobalHooks[name] = true
end

local function EnsureDragonHooks()
    local EUI = _G.EllesmereUI
    HookDragonFunction(EUI, "RefreshAllAddons")
    HookDragonFunction(EUI, "ReapplyAllUnlockAnchors")
    HookDragonFunction(EUI, "ReapplyAllUnlockAnchorsForced")
    HookDragonFunction(EUI, "ApplyAllWidthHeightMatches")
    HookDragonGlobal("_EDR_Rebuild")
end

function addonTable.SetOakRoundThinDragonRidingBorders(state)
    GetVisibilityDB().roundThinDragonRiding = state == true
    UpdateLiveEventRegistration()
    if state then EnsureDragonHooks() end
    RefreshDragonRidingBorder()
end

function addonTable.GetOakRoundThinDragonRidingBorders()
    return IsDragonRidingEnabled()
end

function addonTable.ApplyOakRoundThinDragonRidingIfEnabled()
    if not IsDragonRidingEnabled() then return false end
    UpdateLiveEventRegistration()
    EnsureDragonHooks()
    RefreshDragonRidingBorder()
    return true
end

local function GetEllesmereChatAddon()
    local EUI = _G.EllesmereUI
    local lite = EUI and EUI.Lite
    if lite and type(lite.GetAddon) == "function" then
        local ok, addon = pcall(lite.GetAddon, "EllesmereUIChat", true)
        if ok then return addon end
    end
end

local function GetStoredEllesmereChatConfig(create)
    local db = _G.EllesmereUIDB
    local profileKey = type(db) == "table" and db.activeProfile
    local profiles = type(db) == "table" and db.profiles
    local profile = profileKey and type(profiles) == "table" and profiles[profileKey]
    if type(profile) ~= "table" then return nil end

    if type(profile.addons) ~= "table" then
        if not create then return nil end
        profile.addons = {}
    end
    local addonProfile = profile.addons.EllesmereUIChat
    if type(addonProfile) ~= "table" then
        if not create then return nil end
        addonProfile = {}
        profile.addons.EllesmereUIChat = addonProfile
    end
    if type(addonProfile.chat) ~= "table" then
        if not create then return nil end
        addonProfile.chat = {}
    end
    return addonProfile.chat
end

local function GetEllesmereLiveChatConfig()
    local ECHAT = GetEllesmereChatAddon()
    if ECHAT and type(ECHAT.DB) == "function" then
        local ok, config = pcall(ECHAT.DB)
        if ok and type(config) == "table" then return config end
    end
end

local function GetChatConfigTargets(create)
    local targets = {}
    local stored = GetStoredEllesmereChatConfig(create)
    if stored then targets[#targets + 1] = { key = "stored", config = stored } end

    local live = GetEllesmereLiveChatConfig()
    if live and live ~= stored then targets[#targets + 1] = { key = "live", config = live } end
    return targets
end

local function CopyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[CopyValue(key, seen)] = CopyValue(item, seen)
    end
    return copy
end

local function SaveChatBorderFields(backup, config)
    if type(backup) ~= "table" or type(config) ~= "table" then return end
    for _, field in ipairs(CHAT_BORDER_FIELDS) do
        local value = config[field]
        backup[field] = value == nil and OAK_NIL or CopyValue(value)
    end
end

local function RestoreChatBorderFields(backup, config)
    if type(backup) ~= "table" or type(config) ~= "table" then return false end
    for _, field in ipairs(CHAT_BORDER_FIELDS) do
        local value = backup[field]
        if value == OAK_NIL then
            config[field] = nil
        elseif value ~= nil then
            config[field] = CopyValue(value)
        end
    end
    return true
end

local function GetChatBorderBackup(create)
    local visibility = GetVisibilityDB()
    local profileKey = type(_G.EllesmereUIDB) == "table" and _G.EllesmereUIDB.activeProfile or "__default"
    visibility.roundThinChatBorderBackups = visibility.roundThinChatBorderBackups or {}
    local backups = visibility.roundThinChatBorderBackups
    local backup = backups[profileKey]
    if not backup and create then
        backup = { targets = {} }
        backups[profileKey] = backup
    end
    return backup, profileKey, backups
end

local function GetOakRoundThinBorderKey()
    EnsureOakRoundThinRenderer()
    local mediaName = addonTable.OAK_ROUND_THIN_BORDER_NAME or "OakUI Round Thin"
    local mediaPath = addonTable.OAK_ROUND_THIN_BORDER_PATH
        or "Interface\\AddOns\\OakUI_Installer\\Media\\Borders\\OakRoundThinBorder.png"
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.Fetch and LSM:Fetch("border", mediaName, true) then
        return "sm:" .. mediaName
    end
    return mediaPath
end

local function ApplyOakChatConfig(config, borderKey)
    if type(config) ~= "table" then return end
    config.panelBorderTexture = borderKey
    config.panelBorderThickness = "thin"
    config.panelBorderColorMode = "custom"
    config.panelBorderColor = { r = 0, g = 0, b = 0 }
    config.panelBorderOpacity = 1
    config.panelBorderBehind = false
    config.panelBorderOffsetX = nil
    config.panelBorderOffsetY = nil
    config.panelBorderShiftX = nil
    config.panelBorderShiftY = nil
    config.innerBorderColorMode = "custom"
    config.innerBorderColor = { r = 0, g = 0, b = 0, a = 1 }
    config.hideBorders = false
    config.tabBorderTexture = borderKey
    config.tabBorderThickness = "thin"
    config.tabBorderColorMode = "custom"
    config.tabBorderColor = { r = 0, g = 0, b = 0 }
    config.tabBorderOpacity = 1
    config.tabBorderOffsetX = nil
    config.tabBorderOffsetY = nil
    config.tabBorderShiftX = nil
    config.tabBorderShiftY = nil
end

local function GetChatBackgroundTexture(background)
    if not background or type(background.GetRegions) ~= "function" then return nil end
    local ok, regions = pcall(function() return { background:GetRegions() } end)
    if not ok then return nil end
    for _, region in ipairs(regions) do
        if region and type(region.AddMaskTexture) == "function" then return region end
    end
end

local function RefreshChatBackgroundMasks(enabled)
    local ECHAT = GetEllesmereChatAddon()
    if not ECHAT or type(ECHAT._chatCFD) ~= "function" then return end

    for index = 1, NUM_CHAT_WINDOWS or 20 do
        local frame = _G["ChatFrame" .. index]
        if frame then
            local ok, data = pcall(ECHAT._chatCFD, frame)
            local background = ok and data and data.bg
            if background then
                if enabled and addonTable.ApplyOakRoundThinMaskOnly then
                    local texture = GetChatBackgroundTexture(background)
                    if texture then
                        pcall(addonTable.ApplyOakRoundThinMaskOnly, background, texture, background)
                    end
                elseif addonTable.RemoveOakRoundThinMaskOnly then
                    pcall(addonTable.RemoveOakRoundThinMaskOnly, background)
                end
            end
        end
    end
end

local function RefreshEllesmereChatBorders()
    local ECHAT = GetEllesmereChatAddon()
    if not ECHAT then return end
    local refreshers = {
        "ApplyBackground", "ApplyExtendedBackground", "ApplyBorders",
        "ApplyTabBorders", "ApplyTabSeparators", "ApplyTabAppearance",
        "RefreshVisibility", "ResetIdleTimer",
    }
    for _, name in ipairs(refreshers) do
        if type(ECHAT[name]) == "function" then pcall(ECHAT[name]) end
    end
end

local function RefreshChatBorders()
    local enabled = GetVisibilityDB().roundThinChatWindows == true

    -- Remove the old standalone Oak overlay if a character is upgrading from
    -- the first implementation. EUI now owns the actual chat border.
    for index = 1, NUM_CHAT_WINDOWS or 20 do
        ApplyFrameOverlay(_G["ChatFrame" .. index], CHAT_BORDER_PROPERTY, false)
    end

    local backup, profileKey, backups = GetChatBorderBackup(enabled)
    local borderKey = enabled and GetOakRoundThinBorderKey()
    for _, target in ipairs(GetChatConfigTargets(enabled)) do
        local targetBackup = backup and backup.targets and backup.targets[target.key]
        if enabled then
            if not targetBackup then
                targetBackup = {}
                backup.targets[target.key] = targetBackup
                SaveChatBorderFields(targetBackup, target.config)
            end
            ApplyOakChatConfig(target.config, borderKey)
        elseif targetBackup then
            RestoreChatBorderFields(targetBackup, target.config)
        end
    end

    RefreshEllesmereChatBorders()
    RefreshChatBackgroundMasks(enabled)

    if not enabled and backups[profileKey] then
        backups[profileKey] = nil
    end
end

function addonTable.SetOakRoundThinChatBorders(state)
    GetVisibilityDB().roundThinChatWindows = state == true
    UpdateLiveEventRegistration()
    RefreshChatBorders()
end

function addonTable.GetOakRoundThinChatBorders()
    return GetVisibilityDB().roundThinChatWindows == true
end

local liveEventFrame

local function IsChatEnabled()
    return GetVisibilityDB().roundThinChatWindows == true
end

function addonTable.ApplyOakRoundThinChatBordersIfEnabled()
    if not IsChatEnabled() then return false end
    UpdateLiveEventRegistration()
    RefreshChatBorders()
    return true
end

local function IsLiveFeatureEnabled()
    return IsDragonRidingEnabled() or IsChatEnabled()
end

local function HandleLiveRoundThinEvent(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon ~= "EllesmereUI"
        and loadedAddon ~= "EllesmereUIBlizzardSkin"
        and loadedAddon ~= "EllesmereUIChat" then
        return
    end
    if IsDragonRidingEnabled() then
        EnsureDragonHooks()
        RefreshDragonRidingBorder()
    end
    if IsChatEnabled() then RefreshChatBorders() end
end

UpdateLiveEventRegistration = function()
    if IsLiveFeatureEnabled() then
        if not liveEventFrame then
            liveEventFrame = CreateFrame("Frame")
            liveEventFrame:SetScript("OnEvent", HandleLiveRoundThinEvent)
        end
        liveEventFrame:RegisterEvent("ADDON_LOADED")
        liveEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        liveEventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
        liveEventFrame:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    elseif liveEventFrame then
        liveEventFrame:UnregisterAllEvents()
    end
end
