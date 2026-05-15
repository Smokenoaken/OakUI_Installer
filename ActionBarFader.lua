local addonName, addonTable = ...

local Fader = CreateFrame("Frame")
local bars = {}
local hooked = {}
local mouseInside = false

local function EnsureDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.actionBars then OakUI_DB.actionBars = {} end
    if OakUI_DB.actionBars.hide == nil then OakUI_DB.actionBars.hide = false end
    if not OakUI_DB.actionBars.elvOverrides then OakUI_DB.actionBars.elvOverrides = {} end
    return OakUI_DB.actionBars
end

local function GetElvUI()
    if type(_G.ElvUI) ~= "table" then return nil end
    return _G.ElvUI[1]
end

local function IsElvUIProvider()
    return not addonTable.Profiles or addonTable.Profiles.BASE_UI_PROVIDER ~= "Ellesmere"
end

local function GetActionBarsModule()
    local E = GetElvUI()
    if not E or type(E.GetModule) ~= "function" then return nil, nil end
    return E, E:GetModule("ActionBars", true)
end

local function IsVehicleState()
    return (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (HasOverrideActionBar and HasOverrideActionBar())
        or (HasVehicleActionBar and HasVehicleActionBar())
        or (HasTempShapeshiftActionBar and HasTempShapeshiftActionBar())
end

local function IsFrameShownByState(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function PlayerHasPetBar()
    if PetHasActionBar then return PetHasActionBar() == true end
    return false
end

local function PlayerHasStanceBar()
    if not GetNumShapeshiftForms or GetNumShapeshiftForms() <= 0 then return false end
    if GetShapeshiftFormInfo then
        for i = 1, GetNumShapeshiftForms() do
            local icon, name = GetShapeshiftFormInfo(i)
            if icon or name then return true end
        end
        return false
    end
    return true
end

local function SetFrameAndButtonsHidden(frame, buttonPrefix, buttonCount)
    if not frame then return end

    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
    if frame.SetAlpha then frame:SetAlpha(0) end
    if frame.EnableMouse then frame:EnableMouse(false) end

    if not InCombatLockdown or not InCombatLockdown() then
        if frame.Hide then pcall(frame.Hide, frame) end
        if frame.SetScale then pcall(frame.SetScale, frame, 0.00001) end
    end

    if frame.buttons then
        for _, button in ipairs(frame.buttons) do
            if button then
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(button) end
                if button.SetAlpha then button:SetAlpha(0) end
                if button.EnableMouse then button:EnableMouse(false) end
                if (not InCombatLockdown or not InCombatLockdown()) and button.Hide then pcall(button.Hide, button) end
            end
        end
    end

    if buttonPrefix and buttonCount then
        for i = 1, buttonCount do
            local button = _G[buttonPrefix .. i]
            if button then
                if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(button) end
                if button.SetAlpha then button:SetAlpha(0) end
                if button.EnableMouse then button:EnableMouse(false) end
                if (not InCombatLockdown or not InCombatLockdown()) and button.Hide then pcall(button.Hide, button) end
            end
        end
    end
end

local function ForceHideState(frame, stateName)
    if not frame or InCombatLockdown and InCombatLockdown() then return end
    if UnregisterStateDriver then pcall(UnregisterStateDriver, frame, stateName) end
    if RegisterStateDriver then pcall(RegisterStateDriver, frame, stateName, "hide") end
end

local function ReleaseForcedHideState(frame, stateName)
    if not frame or InCombatLockdown and InCombatLockdown() then return end
    if UnregisterStateDriver then pcall(UnregisterStateDriver, frame, stateName) end
end

local function SuppressInactiveSpecialBars()
    local E = GetElvUI()
    if E and E.db and E.db.actionbar then
        local petDB = E.db.actionbar.barPet
        if petDB and not PlayerHasPetBar() then
            petDB.mouseover = false
            if petDB.inheritGlobalFade ~= nil then petDB.inheritGlobalFade = false end
        end

        local stanceDB = E.db.actionbar.stanceBar
        if stanceDB and not PlayerHasStanceBar() then
            stanceDB.mouseover = false
            if stanceDB.inheritGlobalFade ~= nil then stanceDB.inheritGlobalFade = false end
        end
    end

    if not PlayerHasPetBar() then
        ForceHideState(_G.ElvUI_BarPet, "show")
        SetFrameAndButtonsHidden(_G.ElvUI_BarPet, "PetActionButton", _G.NUM_PET_ACTION_SLOTS or 10)
    else
        ReleaseForcedHideState(_G.ElvUI_BarPet, "show")
    end

    if not PlayerHasStanceBar() then
        ForceHideState(_G.ElvUI_StanceBar, "visibility")
        SetFrameAndButtonsHidden(_G.ElvUI_StanceBar, "ElvUI_StanceBarButton", _G.NUM_STANCE_SLOTS or 10)
    else
        ReleaseForcedHideState(_G.ElvUI_StanceBar, "visibility")
    end
end

local function FadeFrame(frame, target)
    if not frame or not frame.SetAlpha then return end
    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(frame) end
    if UIFrameFade then
        UIFrameFade(frame, {
            mode = target > frame:GetAlpha() and "IN" or "OUT",
            timeToFade = 0.18,
            startAlpha = frame:GetAlpha(),
            endAlpha = target,
        })
    else
        frame:SetAlpha(target)
    end
end

local function FadeBarBlings(frame, alpha)
    local _, AB = GetActionBarsModule()
    if AB and type(AB.FadeBarBlings) == "function" and frame and frame.buttons then
        pcall(AB.FadeBarBlings, AB, frame, alpha)
    end
end

local function HideInactiveSpecialBars()
    SuppressInactiveSpecialBars()
end

local function SetBarsAlpha(target)
    for _, entry in ipairs(bars) do
        local frame = entry.frame
        local alpha = target > 0 and entry.alpha or 0
        if entry.key == "bar1" and IsVehicleState() then
            alpha = entry.alpha
        end
        FadeFrame(frame, alpha)
        FadeBarBlings(frame, alpha)
    end
    HideInactiveSpecialBars()
end

local function AnyBarMouseOver()
    for _, entry in ipairs(bars) do
        local frame = entry.frame
        if IsFrameShownByState(frame) and frame:IsMouseOver() then return true end
    end
    return false
end

local function QueueHideCheck()
    C_Timer.After(0.12, function()
        mouseInside = AnyBarMouseOver()
        if EnsureDB().hide and not mouseInside then
            SetBarsAlpha(0)
        end
    end)
end

local function BarEnter()
    mouseInside = true
    if EnsureDB().hide then SetBarsAlpha(1) end
end

local function BarLeave()
    QueueHideCheck()
end

local function HookBar(entry)
    local frame = entry.frame
    if not frame or hooked[frame] then return end

    frame:HookScript("OnEnter", BarEnter)
    frame:HookScript("OnLeave", BarLeave)
    hooked[frame] = true

    if frame.buttons then
        for _, button in ipairs(frame.buttons) do
            if button and not hooked[button] then
                button:HookScript("OnEnter", BarEnter)
                button:HookScript("OnLeave", BarLeave)
                hooked[button] = true
            end
        end
    end
end

local function AddBar(key, frame, db)
    if not frame or not db or db.enabled == false then return end
    table.insert(bars, {
        key = key,
        frame = frame,
        db = db,
        alpha = db.alpha or 1,
    })
    HookBar(bars[#bars])
end

local function IsActionBarEnabled(key, barDB)
    if not barDB or barDB.enabled == false then return false end
    if key == "barPet" then return PlayerHasPetBar() end
    if key == "stanceBar" then return PlayerHasStanceBar() end
    return true
end

local function SetElvUIMouseoverOverrides(enabled)
    local E = GetElvUI()
    local db = EnsureDB()
    if not E or not E.db or not E.db.actionbar then return end

    local function ApplyOverride(key, barDB)
        if not IsActionBarEnabled(key, barDB) then return end
        db.elvOverrides[key] = db.elvOverrides[key] or {}
        local stored = db.elvOverrides[key]

        if enabled then
            if stored.mouseover == nil then stored.mouseover = barDB.mouseover end
            if stored.inheritGlobalFade == nil then stored.inheritGlobalFade = barDB.inheritGlobalFade end
            barDB.mouseover = false
            if barDB.inheritGlobalFade ~= nil then barDB.inheritGlobalFade = false end
        else
            barDB.mouseover = false
            if barDB.inheritGlobalFade ~= nil then barDB.inheritGlobalFade = false end
            db.elvOverrides[key] = nil
        end
    end

    for i = 1, 10 do
        local key = "bar" .. i
        ApplyOverride(key, E.db.actionbar[key])
    end

    for _, key in ipairs({ "barPet", "stanceBar", "totemBar" }) do
        ApplyOverride(key, E.db.actionbar[key])
    end
end

local function DiscoverBars()
    wipe(bars)

    local E, AB = GetActionBarsModule()
    if not E or not AB or not E.db or not E.db.actionbar then return end

    for i = 1, 10 do
        local key = "bar" .. i
        local frame = (AB.handledBars and AB.handledBars[key]) or _G["ElvUI_Bar" .. i]
        AddBar(key, frame, E.db.actionbar[key])
    end

    if PlayerHasPetBar() then
        AddBar("barPet", _G.ElvUI_BarPet, E.db.actionbar.barPet)
    end
    if PlayerHasStanceBar() then
        AddBar("stanceBar", _G.ElvUI_StanceBar, E.db.actionbar.stanceBar)
    end

    local totemDB = E.db.actionbar.totemBar
    if totemDB then
        AddBar("totemBar", _G.ElvUI_TotemBar, totemDB)
    end
end

local function RefreshElvUIBars()
    local E, AB = GetActionBarsModule()
    if not E or not AB then return end

    for i = 1, 10 do
        if type(AB.PositionAndSizeBar) == "function" then
            pcall(AB.PositionAndSizeBar, AB, "bar" .. i)
        end
    end
    if type(AB.PositionAndSizeBarPet) == "function" then pcall(AB.PositionAndSizeBarPet, AB) end
    if type(AB.PositionAndSizeBarShapeShift) == "function" then pcall(AB.PositionAndSizeBarShapeShift, AB) end
end

function addonTable.RefreshActionBarFader()
    if not IsElvUIProvider() then return end
    SuppressInactiveSpecialBars()
    SetElvUIMouseoverOverrides(EnsureDB().hide)
    DiscoverBars()
    if EnsureDB().hide then
        SetBarsAlpha(mouseInside and 1 or 0)
    else
        SetBarsAlpha(1)
    end
    SuppressInactiveSpecialBars()
end

function addonTable.SetActionBarsHidden(state)
    if not IsElvUIProvider() then return end
    EnsureDB().hide = state == true
    SetElvUIMouseoverOverrides(EnsureDB().hide)
    RefreshElvUIBars()
    addonTable.RefreshActionBarFader()
end

function addonTable.GetActionBarsHidden()
    if not IsElvUIProvider() then return false end
    return EnsureDB().hide == true
end

Fader:RegisterEvent("PLAYER_LOGIN")
Fader:RegisterEvent("PLAYER_ENTERING_WORLD")
Fader:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
Fader:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
Fader:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
Fader:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
Fader:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
Fader:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
Fader:RegisterEvent("PET_BAR_UPDATE")
Fader:RegisterEvent("PET_UI_UPDATE")
Fader:RegisterEvent("SPELLS_CHANGED")
Fader:RegisterEvent("PLAYER_CONTROL_GAINED")
Fader:RegisterEvent("PLAYER_CONTROL_LOST")
Fader:RegisterEvent("UNIT_PET")
Fader:RegisterEvent("UNIT_ENTERED_VEHICLE")
Fader:RegisterEvent("UNIT_EXITED_VEHICLE")
Fader:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    if addonTable.RefreshActionBarFader then addonTable.RefreshActionBarFader() end
    C_Timer.After(0.5, function()
        if addonTable.RefreshActionBarFader then
            addonTable.RefreshActionBarFader()
        end
    end)
    C_Timer.After(1.5, function()
        if addonTable.RefreshActionBarFader then
            addonTable.RefreshActionBarFader()
        end
    end)
end)
