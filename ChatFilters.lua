local addonName, addonTable = ...

local function GetDB()
    if not OakUI_DB then OakUI_DB = {} end
    if not OakUI_DB.chatFilters then
        OakUI_DB.chatFilters = {
            achievements = true, auctions = true, channels = true, experience = true,
            followers = true, loot = true, names = true, quests = true, collections = true,
            reputation = true, spells = true, status = true, tradeskills = true, money = true,
        }
    end
    return OakUI_DB.chatFilters
end

-- Convert WoW Global Strings to Lua Regex Patterns safely
local function makePattern(msg)
    if not msg then return "DONT_MATCH_ANYTHING_NIL" end
    msg = string.gsub(msg, "%%([%d%$]-)d", "(%%d+)")
    msg = string.gsub(msg, "%%([%d%$]-)s", "(.+)")
    return msg
end

local P = setmetatable({}, { __index = function(t,k)
    rawset(t,k,makePattern(k))
    return rawget(t,k)
end})

local pfx = "|cff888888+|r "

local function IsSecretValue(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, isSecret = pcall(issecretvalue, value)
    return ok and isSecret == true
end

local function HasSecretChatArg(msg, author, ...)
    if IsSecretValue(msg) or IsSecretValue(author) then return true end
    for i = 1, select("#", ...) do
        if IsSecretValue(select(i, ...)) then return true end
    end
    return false
end

local function SanitizeLootPlayerName(player)
    if type(player) ~= "string" or player == "" then
        return nil
    end

    player = player:gsub("^|c%x+%+|r%s*", "")
    player = player:gsub("^%+%s*", "")
    player = player:gsub("%-.+$", "")
    player = player:match("^%s*(.-)%s*$")

    if player == "" then
        return nil
    end

    return player
end

local function MatchLootGlobal(msg, globalName)
    local fmt = _G[globalName]
    if type(fmt) ~= "string" then
        return nil
    end
    return string.match(msg, P[fmt])
end

local function ExtractLootPlayer(msg, author)
    local player = MatchLootGlobal(msg, "LOOT_ITEM_MULTIPLE")
        or MatchLootGlobal(msg, "LOOT_ITEM")
        or MatchLootGlobal(msg, "LOOT_ITEM_PUSHED_MULTIPLE")
        or MatchLootGlobal(msg, "LOOT_ITEM_PUSHED")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED_SELF_MULTIPLE")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED_SELF")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED_BY_MULTIPLE")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED_BY")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED_MULTIPLE")
        or MatchLootGlobal(msg, "LOOT_ITEM_CREATED")

    player = SanitizeLootPlayerName(player)
    if player then
        return player
    end

    return SanitizeLootPlayerName(author)
end

-- ==========================================
-- HELPER: MONEY FORMATTER
-- ==========================================
local function FormatMoneyText(msg)
    if not msg then return nil end
    local g = tonumber(string.match(msg, "(%d+)%s*[Gg]old")) or tonumber(string.match(msg, P[GOLD_AMOUNT])) or 0
    local s = tonumber(string.match(msg, "(%d+)%s*[Ss]ilver")) or tonumber(string.match(msg, P[SILVER_AMOUNT])) or 0
    local c = tonumber(string.match(msg, "(%d+)%s*[Cc]opper")) or tonumber(string.match(msg, P[COPPER_AMOUNT])) or 0
    
    if g > 0 or s > 0 or c > 0 then
        local gIcon = "|TInterface\\AddOns\\OakUI_Installer\\Media\\coins.tga:16:16:-2:0:64:64:0:32:0:32|t"
        local sIcon = "|TInterface\\AddOns\\OakUI_Installer\\Media\\coins.tga:16:16:-2:0:64:64:32:64:0:32|t"
        local cIcon = "|TInterface\\AddOns\\OakUI_Installer\\Media\\coins.tga:16:16:-2:0:64:64:0:32:32:64|t"
        
        local out = ""
        if g > 0 then out = out .. g .. gIcon .. " " end
        if s > 0 then out = out .. s .. sIcon .. " " end
        if c > 0 then out = out .. c .. cIcon end
        
        return out:gsub("%s+$", "")
    end
    return nil
end

-- ==========================================
-- ENGINE: CHAT FILTERS
-- ==========================================
local function FilterChannels(self, event, msg, author, ...)
    if HasSecretChatArg(msg, author, ...) then return false, msg, author, ... end

    local db = GetDB()
    if db.channels then
        msg = string.gsub(msg, "%["..string.match(CHAT_PARTY_LEADER_GET, "%[(.-)%]").."%]", "PL")
        msg = string.gsub(msg, "%["..string.match(CHAT_PARTY_GET, "%[(.-)%]").."%]", "P")
        msg = string.gsub(msg, "%["..string.match(CHAT_RAID_LEADER_GET, "%[(.-)%]").."%]", "RL")
        msg = string.gsub(msg, "%["..string.match(CHAT_RAID_GET, "%[(.-)%]").."%]", "R")
        msg = string.gsub(msg, "%["..string.match(CHAT_INSTANCE_CHAT_LEADER_GET, "%[(.-)%]").."%]", "IL")
        msg = string.gsub(msg, "%["..string.match(CHAT_INSTANCE_CHAT_GET, "%[(.-)%]").."%]", "I")
        msg = string.gsub(msg, "%["..string.match(CHAT_GUILD_GET, "%[(.-)%]").."%]", "G")
        msg = string.gsub(msg, "%["..string.match(CHAT_OFFICER_GET, "%[(.-)%]").."%]", "O")
        msg = string.gsub(msg, "%["..string.match(CHAT_RAID_WARNING_GET, "%[(.-)%]").."%]", "|cffff0000!|r")
        msg = string.gsub(msg, "|Hchannel:(.-):(%d+)|h%[(%d)%. (.-)%]|h", "|Hchannel:%1:%2|h%3.|h")
    end
    if db.names then
        msg = string.gsub(msg, "|Hplayer:(.-)|h%[(.-)%]|h", "|Hplayer:%1|h%2|h")
        msg = string.gsub(msg, "|HBNplayer:(.-)|h%[(.-)%]|h", "|HBNplayer:%1|h%2|h")
    end
    return false, msg, author, ...
end

local function FilterSystem(self, event, msg, author, ...)
    if HasSecretChatArg(msg, author, ...) then return false, msg, author, ... end

    local db = GetDB()
    if db.status then
        if msg == MARKED_AFK then return false, "|cff888888You are now AFK.|r", author, ... end
        if msg == CLEARED_AFK then return false, "|cff888888You are no longer AFK.|r", author, ... end
        if msg == CLEARED_DND then return false, "|cff888888You are no longer DND.|r", author, ... end
    end
    if db.quests then
        local qAccept = string.match(msg, P[ERR_QUEST_ACCEPTED_S])
        if qAccept then return false, pfx .. "|cff00ccffAccepted:|r |cffFFD100" .. qAccept:gsub("[%[/%]]", "") .. "|r", author, ... end
        if not string.match(msg, P[ERR_QUEST_ALREADY_DONE]) then
            local qComplete = string.match(msg, P[ERR_QUEST_COMPLETE_S])
            if qComplete then return false, pfx .. "|cff22ff22Complete:|r |cffFFD100" .. qComplete:gsub("[%[/%]]", "") .. "|r", author, ... end
        end
    end
    if db.experience then
        if string.match(msg, P[ERR_QUEST_REWARD_EXP_I]) then return true end
        local source, xp = string.match(msg, P[COMBATLOG_XPGAIN_FIRSTPERSON])
        if xp and source then return false, pfx .. "|cffb38cff" .. xp .. " XP|r |cff888888(|r|cff00ccff" .. source .. "|r|cff888888)|r", author, ... end
        local xpOnly = string.match(msg, P[COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED])
        if xpOnly then return false, pfx .. "|cffb38cff" .. xpOnly .. " XP|r", author, ... end
        local discSource, discXp = string.match(msg, P[ERR_ZONE_EXPLORED_XP])
        if discXp and discSource then return false, pfx .. "|cffb38cff" .. discXp .. " XP|r |cff888888(|r|cff00ccff" .. discSource .. "|r|cff888888)|r", author, ... end
    end
    if db.money then
        local questMoney = string.match(msg, P[ERR_QUEST_REWARD_MONEY_S])
        if questMoney then
            local coinText = FormatMoneyText(questMoney)
            if coinText then return false, pfx .. coinText, author, ... end
        end
    end
    if db.collections then
        local appearance = string.match(msg, P[ERR_LEARN_TRANSMOG_S])
        if appearance then return false, pfx .. "|cffFF7FFFAppearance:|r " .. appearance, author, ... end
        local mount = string.match(msg, P[ERR_LEARN_MOUNT_S])
        if mount then return false, pfx .. "|cffFFCC00Mount:|r " .. mount, author, ... end
        local toy = string.match(msg, P[ERR_LEARN_TOY_S])
        if toy then return false, pfx .. "|cff00CCFFToy:|r " .. toy, author, ... end
        local pet = string.match(msg, P[BATTLE_PET_NEW_PET]) or string.match(msg, P[ERR_LEARN_COMPANION_S])
        if pet then return false, pfx .. "|cff00FF00Pet:|r " .. pet, author, ... end
        local heirloom = string.match(msg, P[ERR_LEARN_HEIRLOOM_S])
        if heirloom then return false, pfx .. "|cff00CCFFHeirloom:|r " .. heirloom, author, ... end
    end
    if db.achievements and event == "CHAT_MSG_ACHIEVEMENT" then
        local player, ach = string.match(msg, P[ACHIEVEMENT_BROADCAST])
        if player and ach then return false, pfx .. "|cffE268A8Achievement:|r |cffffffff" .. player:gsub("[%[/%]]", "") .. "|r earned " .. ach, author, ... end
    end
    return false, msg, author, ...
end

local function FilterReputation(self, event, msg, author, ...)
    if HasSecretChatArg(msg, author, ...) then return false, msg, author, ... end

    if not GetDB().reputation then return false, msg, author, ... end
    local isWarband = false
    local faction, val = string.match(msg, P[FACTION_STANDING_INCREASED])
    if not faction then faction, val = string.match(msg, "Warband.-reputation.-with (.-) increased by (%d+)"); if faction then isWarband = true end end
    if faction and val then 
        local wbTag = isWarband and "|cff00ccff[Warband]|r " or ""
        return false, pfx .. wbTag .. "|cff22ff22" .. val .. " Rep|r |cff888888(|r|cffE6CC80" .. faction .. "|r|cff888888)|r", author, ... 
    end
    local factionDec, valDec = string.match(msg, P[FACTION_STANDING_DECREASED])
    if not factionDec then factionDec, valDec = string.match(msg, "Warband.-reputation.-with (.-) decreased by (%d+)"); if factionDec then isWarband = true end end
    if factionDec and valDec then 
        local wbTag = isWarband and "|cff00ccff[Warband]|r " or ""
        return false, "|cffff0000-|r " .. wbTag .. "|cffff4444" .. valDec .. " Rep|r |cff888888(|r|cffE6CC80" .. factionDec .. "|r|cff888888)|r", author, ... 
    end
    return false, msg, author, ...
end

-- ==========================================
-- SURGICAL LOOT PARSER
-- ==========================================
local function FilterLoot(self, event, msg, author, ...)
    if HasSecretChatArg(msg, author, ...) then return false, msg, author, ... end

    if not GetDB().loot then return false, msg, author, ... end
    
    if event == "CHAT_MSG_CURRENCY" then
        local count = string.match(msg, "x(%d+)")
        -- Strictly require the |H hyperlink tag so we don't accidentally grab QUI's "+" prefix
        local item = string.match(msg, "(|c.-|H.-|h.-|h|r)")
        if item then
            if count then return false, "|cffaaaaaaLoot:|r " .. item .. " |cff22ff22x" .. count .. "|r", author, ... end
            return false, "|cffaaaaaaLoot:|r " .. item, author, ...
        end
    end
    
    if event == "CHAT_MSG_LOOT" then
        local count = string.match(msg, "x(%d+)")
        local item = string.match(msg, "(|c.-|H.-|h.-|h|r)")
        local player = ExtractLootPlayer(msg, author)
        
        if item then
            local prefix = player and ("|cff888888" .. player .. "|r |cffaaaaaalooted:|r ") or "|cffaaaaaaLoot:|r "
            
            if count then return false, prefix .. item .. " |cff22ff22x" .. count .. "|r", author, ... end
            return false, prefix .. item, author, ...
        end
    end
    
    return false, msg, author, ...
end

local function FilterMoney(self, event, msg, author, ...)
    if HasSecretChatArg(msg, author, ...) then return false, msg, author, ... end

    if not GetDB().money then return false, msg, author, ... end
    local coinText = FormatMoneyText(msg)
    if coinText then return false, pfx .. coinText, author, ... end
    return false, msg, author, ...
end

local engine = CreateFrame("Frame")
engine:RegisterEvent("PLAYER_LOGIN")
engine:SetScript("OnEvent", function()
    -- Player chat events carry protected history tokens in current Retail builds.
    -- Returning modified args from an addon taints Blizzard's HistoryKeeper path.
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterSystem)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_XP_GAIN", FilterSystem)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", FilterReputation)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", FilterLoot)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CURRENCY", FilterLoot)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_MONEY", FilterMoney)
end)
