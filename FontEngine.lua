local addonName, addonTable = ...

local FONT_PATH = "Interface\\AddOns\\OakUI_Installer\\Fonts\\"
local DEFAULT_FONT = "OakUI Friz Quadrata"
local DEFAULT_SIZE = 14
local DEFAULT_OUTLINE = "NONE"

local OAK_FONTS = {
    ["OakUI Arial Narrow"] = FONT_PATH .. "ARIALN.ttf",
    ["OakUI Friz Quadrata"] = FONT_PATH .. "FRIZQT__.ttf",
    ["OakUI Morpheus"] = FONT_PATH .. "MORPHEUS.ttf",
    ["OakUI Skurri"] = FONT_PATH .. "SKURRI.ttf",
}

local SECTIONS = {
    { key = "combat", name = "Combat Font", size = 120, outline = "SHADOW", restart = true },
    { key = "name", name = "Name Font", size = 12, outline = "NONE", restart = true },
    { key = "nameplate", name = "Blizzard Nameplate", size = 9, outline = "OUTLINE", largeSize = 11, largeOutline = "OUTLINE" },
    { key = "cooldown", name = "Blizzard Cooldown", objects = { "SystemFont_Shadow_Large_Outline" }, size = 16, outline = "SHADOW" },
    { key = "worldzone", name = "World Zone Text", objects = { "ZoneTextFont", "WorldMapTextFont" }, size = 25, outline = "OUTLINE" },
    { key = "worldsubzone", name = "World Sub Zone Text", objects = { "SubZoneTextFont" }, size = 24, outline = "OUTLINE" },
    { key = "pvpzone", name = "PVP Zone Text", objects = { "PVPArenaTextString" }, size = 22, outline = "OUTLINE" },
    { key = "pvpsubzone", name = "PVP Sub Zone Text", objects = { "PVPInfoTextString" }, size = 22, outline = "OUTLINE" },
    { key = "objective", name = "Objective Text", objects = { "ObjectiveFont", "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont" }, size = 12, outline = "SHADOW", objectiveRange = true },
    { key = "errortext", name = "Quest Progress / Error Text", objects = { "ErrorFont" }, size = 16, outline = "SHADOW", resizeErrors = true },
    { key = "mailbody", name = "Mail Text", objects = { "MailTextFontNormal" }, size = 15, outline = "NONE" },
    { key = "questtitle", name = "Quest Title", objects = { "QuestTitleFont" }, size = 18, outline = "NONE" },
    { key = "questtext", name = "Quest Text", objects = { "QuestFont" }, size = 13, outline = "NONE" },
    { key = "questsmall", name = "Quest Small", objects = { "QuestFontNormalSmall" }, size = 12, outline = "NONE" },
    { key = "talkingtitle", name = "Talking Head Name", talkingObject = { "TalkingHeadFrame", "NameFrame", "Name" }, size = 22, outline = "OUTLINE" },
    { key = "talkingtext", name = "Talking Head Text", talkingObject = { "TalkingHeadFrame", "TextFrame", "Text" }, size = 16, outline = "SHADOW" },
}

addonTable.FontSections = SECTIONS
addonTable.OakFontFallbacks = OAK_FONTS

local function GetLSM()
    return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
end

local function RegisterOakFonts()
    local LSM = GetLSM()
    if not LSM then return end
    for name, path in pairs(OAK_FONTS) do
        LSM:Register("font", name, path)
    end
end

local function GetFontPath(fontName)
    local LSM = GetLSM()
    if LSM then
        local path = LSM:Fetch("font", fontName, true)
        if path then return path end
    end
    return OAK_FONTS[fontName] or OAK_FONTS[DEFAULT_FONT]
end

local function GetPreferredOakFontName()
    RegisterOakFonts()

    local LSM = GetLSM()
    if LSM and LSM:Fetch("font", "OakUI Font", true) then
        return "OakUI Font"
    end

    if OAK_FONTS["OakUI Font"] then
        return "OakUI Font"
    end

    return DEFAULT_FONT
end

function addonTable.GetFontChoices()
    RegisterOakFonts()

    local fonts = {}
    local LSM = GetLSM()
    local source = LSM and LSM:HashTable("font") or OAK_FONTS
    for name in pairs(source or OAK_FONTS) do
        fonts[#fonts + 1] = name
    end
    table.sort(fonts)
    return fonts
end

local function EnsureFontDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.fonts then OakUI_DB.fonts = {} end

    local db = OakUI_DB.fonts
    db.global = db.global or { font = DEFAULT_FONT, size = DEFAULT_SIZE, outline = DEFAULT_OUTLINE }
    db.sections = db.sections or {}

    for _, section in ipairs(SECTIONS) do
        local current = db.sections[section.key]
        if not current then
            db.sections[section.key] = {
                enable = false,
                font = db.global.font or DEFAULT_FONT,
                size = section.size or DEFAULT_SIZE,
                outline = section.outline or DEFAULT_OUTLINE,
                largeFont = db.global.font or DEFAULT_FONT,
                largeSize = section.largeSize,
                largeOutline = section.largeOutline,
            }
        else
            if current.enable == nil then current.enable = false end
            current.font = current.font or db.global.font or DEFAULT_FONT
            current.size = current.size or section.size or DEFAULT_SIZE
            current.outline = current.outline or section.outline or DEFAULT_OUTLINE
            current.largeFont = current.largeFont or db.global.font or DEFAULT_FONT
            current.largeSize = current.largeSize or section.largeSize
            current.largeOutline = current.largeOutline or section.largeOutline
        end
    end

    return db
end

addonTable.EnsureFontDB = EnsureFontDB

local function NormalizeOutline(outline)
    if not outline or outline == "NONE" then return "" end
    if outline == "SHADOW" then return "" end
    return outline
end

local function SetFont(obj, font, size, outline)
    if not obj or not obj.SetFont then return end
    obj:SetFont(font, size, NormalizeOutline(outline))
    if outline == "SHADOW" then
        obj:SetShadowColor(0, 0, 0, 1)
        obj:SetShadowOffset(1, -1)
    elseif obj.SetShadowColor then
        obj:SetShadowColor(0, 0, 0, 0)
        obj:SetShadowOffset(0, 0)
    end
end

local function GetNestedObject(path)
    local obj = _G[path[1]]
    for i = 2, #path do
        obj = obj and obj[path[i]]
    end
    return obj
end

local function ApplyObjectList(objects, fontPath, size, outline)
    for _, objectName in ipairs(objects or {}) do
        SetFont(_G[objectName], fontPath, size, outline)
    end
end

local function ApplySection(section, settings, fallback)
    if not settings and not fallback then return end
    if settings and not settings.enable and not fallback then return end

    local active = (settings and settings.enable) and settings or fallback
    if not active then return end

    local fontPath = GetFontPath(active.font)

    if section.key == "combat" then
        if not (settings and settings.enable) then return end
        _G.DAMAGE_TEXT_FONT = fontPath
        SetFont(_G.CombatTextFont, fontPath, active.size or section.size, active.outline or section.outline)
        return
    end

    if section.key == "name" then
        if not (settings and settings.enable) then return end
        _G.UNIT_NAME_FONT = fontPath
        return
    end

    if section.key == "nameplate" then
        local largePath = GetFontPath(active.largeFont or active.font)
        ApplyObjectList({ "SystemFont_NamePlate", "SystemFont_NamePlateFixed", "SystemFont_NamePlateCastBar", "SystemFont_NamePlate_Outlined" }, fontPath, active.size or section.size, active.outline or section.outline)
        ApplyObjectList({ "SystemFont_LargeNamePlate", "SystemFont_LargeNamePlateFixed" }, largePath, active.largeSize or section.largeSize or active.size or section.size, active.largeOutline or section.largeOutline or active.outline or section.outline)
        return
    end

    ApplyObjectList(section.objects, fontPath, active.size or section.size, active.outline or section.outline)

    if section.objectiveRange then
        for i = 12, 22 do
            SetFont(_G["ObjectiveTrackerFont" .. i], fontPath, active.size or section.size, active.outline or section.outline)
        end
    end

    if section.talkingObject then
        SetFont(GetNestedObject(section.talkingObject), fontPath, active.size or section.size, active.outline or section.outline)
    end

    if section.resizeErrors and _G.UIErrorsFrame then
        local size = active.size or section.size
        local diff = (size - 16) / 16
        if diff > 0 then
            _G.UIErrorsFrame:SetSize(512 * (diff + 1), 60 * ((diff * 1.75) + 1))
        else
            _G.UIErrorsFrame:SetSize(512, 60)
        end
    end
end

function addonTable.ApplyOakFonts()
    RegisterOakFonts()
    local db = EnsureFontDB()
    local global = db.global or {}
    local globalPath = GetFontPath(global.font)

    if db.replaceBlizzardFonts then
        _G.STANDARD_TEXT_FONT = globalPath
        for _, obj in ipairs({ _G.GameFontNormal, _G.GameFontHighlight, _G.GameFontNormalSmall, _G.GameFontHighlightSmall, _G.GameFontNormalLarge, _G.GameFontHighlightLarge }) do
            SetFont(obj, globalPath, global.size or DEFAULT_SIZE, global.outline or DEFAULT_OUTLINE)
        end
    end

    for _, section in ipairs(SECTIONS) do
        local fallback
        if db.replaceBlizzardFonts and section.key ~= "combat" and section.key ~= "name" then
            fallback = {
                font = global.font,
                size = section.size or global.size or DEFAULT_SIZE,
                outline = section.outline or global.outline or DEFAULT_OUTLINE,
                largeFont = global.font,
                largeSize = section.largeSize,
                largeOutline = section.largeOutline,
            }
        end
        ApplySection(section, db.sections[section.key], fallback)
    end
end

function addonTable.ApplyFontToAll(fontName)
    local db = EnsureFontDB()
    db.global.font = fontName or db.global.font or DEFAULT_FONT
    db.replaceBlizzardFonts = true
    for _, section in ipairs(SECTIONS) do
        local settings = db.sections[section.key]
        settings.enable = true
        settings.font = db.global.font
        if section.key == "nameplate" then
            settings.largeFont = db.global.font
        end
    end
end

function addonTable.ApplyOakFontPreset()
    local fontName = GetPreferredOakFontName()
    addonTable.ApplyFontToAll(fontName)
    addonTable.ApplyOakFonts()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == addonName then
        RegisterOakFonts()
        EnsureFontDB()
        addonTable.ApplyOakFonts()
    elseif event == "PLAYER_LOGIN" then
        addonTable.ApplyOakFonts()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
