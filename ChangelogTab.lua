local addonName, addonTable = ...
local P = addonTable.Profiles

function addonTable.BuildChangelogUI(parentFrame)
    local cWrap = addonTable.cWrap
    local SkinScrollbar = addonTable.SkinScrollbar

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Changelog|r")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_ChangelogScroll", parentFrame, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    ScrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -70)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 20)

    -- Dynamically stretch child width when window resizes
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end)
    ScrollChild:SetWidth(ScrollFrame:GetWidth() or 470)

    SkinScrollbar(ScrollFrame)

    local history = P.CHANGELOG or {}
    local yOffset = -10

    for i, entry in ipairs(history) do
        -- Version & Date Header
        local header = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
        header:SetText(cWrap .. (entry.version or "Unknown Version") .. "|r  -  " .. (entry.date or ""))
        
        yOffset = yOffset - 25

        -- Bullet Points
        if entry.notes then
            for _, note in ipairs(entry.notes) do
                local bullet = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                bullet:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, yOffset)
                bullet:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -15, yOffset) -- Allows text wrapping
                bullet:SetJustifyH("LEFT")
                bullet:SetText("• " .. note)
                
                -- Dynamically calculate height so long bullet points don't overlap
                yOffset = yOffset - bullet:GetStringHeight() - 8
            end
        end
        
        -- Divider line between updates (skip on the last one)
        if i < #history then
            local divider = ScrollChild:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.1)
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset - 5)
            divider:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -15, yOffset - 5)
            yOffset = yOffset - 25
        end
    end

    ScrollChild:SetHeight(math.abs(yOffset))
end