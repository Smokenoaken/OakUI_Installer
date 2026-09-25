local _, addonTable = ...
if not addonTable.IsForever then return end

-- Forever's cooldown Edit Mode preview can request more icons than an
-- extra-icons-only spellbook provider owns. Blizzard then indexes an
-- uninitialized base list. Keep invalid preview indices on the question mark;
-- valid indices still use Blizzard's implementation unchanged.
local function InstallIconBoundsGuard()
    local mixin = IconDataProviderMixin
    if not (mixin and mixin.GetIconByIndex and mixin.GetNumIcons) then return false end
    local getIcon = mixin.GetIconByIndex
    mixin.GetIconByIndex = function(self, index)
        if type(index) == "number" and index > self:GetNumIcons() then
            return getIcon(self, 1)
        end
        return getIcon(self, index)
    end
    return true
end

if not InstallIconBoundsGuard() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self)
        if InstallIconBoundsGuard() then self:UnregisterAllEvents() end
    end)
end
