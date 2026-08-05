local addonName, addonTable = ...

local MEDIA_PATH = "Interface\\AddOns\\OakUI_Installer\\Media\\"
local FONT_PATH = "Interface\\AddOns\\OakUI_Installer\\Fonts\\"
local DEFAULT_FONT = "OakUI Font"

local OAK_FONTS = {
    ["OakUI Font"] = MEDIA_PATH .. "OakFont.ttf",
    ["Basic OakUI Font"] = MEDIA_PATH .. "OakFont.ttf",
    ["OakCombatFont"] = MEDIA_PATH .. "OakCombatFont.ttf",
    ["OakUI Arial Narrow"] = FONT_PATH .. "ARIALN.ttf",
    ["Electrofied"] = FONT_PATH .. "electr.ttf",
    ["Electrofied Bold"] = FONT_PATH .. "electrb.ttf",
    ["Electrofied Bold Italic"] = FONT_PATH .. "electrbi.ttf",
    ["Electrofied Italic"] = FONT_PATH .. "electri.ttf",
    ["OakUI Friz Quadrata"] = FONT_PATH .. "FRIZQT__.ttf",
    ["OakUI Morpheus"] = FONT_PATH .. "MORPHEUS.ttf",
    ["OakUI Skurri"] = FONT_PATH .. "SKURRI.ttf",
}

addonTable.OakFontFallbacks = OAK_FONTS

local function GetLSM()
    return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
end

-- Keep Oak's bundled faces available to both LibSharedMedia and EllesmereUI.
-- Registration is idempotent so repeated installer/profile calls stay cheap.
local function RegisterOakFontsWithEllesmere()
    local E = _G.EllesmereUI
    if type(E) ~= "table" or addonTable._oakEllesmereFontOwner == E then return end

    E._smFontPaths = E._smFontPaths or {}
    for name, path in pairs(OAK_FONTS) do
        E._smFontPaths[name] = path
    end

    addonTable._oakEllesmereFontOwner = E
    if type(E.InvalidateFontCache) == "function" then
        E.InvalidateFontCache()
    end
end

local function RegisterOakFonts()
    local LSM = GetLSM()
    if LSM and not addonTable._oakFontsRegisteredWithLSM then
        for name, path in pairs(OAK_FONTS) do
            LSM:Register("font", name, path)
        end
        addonTable._oakFontsRegisteredWithLSM = true
    end

    if addonTable.RegisterOakRoundThinBorderMedia then
        addonTable.RegisterOakRoundThinBorderMedia()
    end
    RegisterOakFontsWithEllesmere()
    if addonTable.RegisterOakRoundThinBorderRenderer then
        addonTable.RegisterOakRoundThinBorderRenderer()
    end
end

addonTable.RegisterOakFonts = RegisterOakFonts
addonTable.RegisterOakMedia = RegisterOakFonts

local function GetFontPath(fontName)
    local LSM = GetLSM()
    if LSM then
        local path = LSM:Fetch("font", fontName, true)
        if path then return path end
    end
    return OAK_FONTS[fontName] or OAK_FONTS[DEFAULT_FONT]
end

-- EllesmereUI profile strings already carry the complete fonts database,
-- including global game text, floating names, and per-module font choices.
-- Do not rewrite those imported values here. Combat text is the exception:
-- EllesmereUI stores it separately in EllesmereUIDB.fctFont and does not
-- include that account-wide value in profileData.fonts.
function addonTable.ApplyOakEllesmereFontPreset(fontName)
    RegisterOakFonts()

    if type(_G.EllesmereUIDB) ~= "table" then return false end
    if type(_G.EllesmereUIDB.fctFont) == "string" and _G.EllesmereUIDB.fctFont ~= "" then
        return false
    end

    -- Keep the old installer API as a compatibility shim, but only seed the
    -- separate combat-text setting when the account has no value yet. This
    -- preserves an imported/user-selected combat font.
    _G.EllesmereUIDB.fctFont = GetFontPath(fontName or DEFAULT_FONT)
    return true
end

-- Kept as the installer-facing API name so existing install flows continue
-- working without restoring the removed OakUI Custom Fonts engine.
function addonTable.ApplyOakFontPreset()
    return addonTable.ApplyOakEllesmereFontPreset(DEFAULT_FONT)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        RegisterOakFonts()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
