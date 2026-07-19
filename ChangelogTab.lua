local addonName, addonTable = ...
local P = addonTable.Profiles

function addonTable.BuildChangelogUI(parentFrame)
    local cWrap = addonTable.cWrap
    local SkinScrollbar = addonTable.SkinScrollbar

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -16)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Changelog|r")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_ChangelogScroll", parentFrame, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    ScrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -56)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 20)

    -- Dynamically stretch child width when window resizes
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height) self:GetScrollChild():SetWidth(width) end)
    local initialWidth = math.max(420, parentFrame:GetWidth() - 60)
    ScrollChild:SetWidth(initialWidth)

    SkinScrollbar(ScrollFrame)

    local history = P.CHANGELOG or {}
    local yOffset = -10

    for i, entry in ipairs(history) do
        -- Version & Date Header
        local header = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
        header:SetWidth(initialWidth - 20)
        header:SetText(cWrap .. (entry.version or "Unknown Version") .. "|r  -  " .. (entry.date or ""))
        
        yOffset = yOffset - 22

        -- Bullet Points
        if entry.notes then
            for _, note in ipairs(entry.notes) do
                local bullet = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                bullet:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, yOffset)
                bullet:SetWidth(initialWidth - 45)
                bullet:SetJustifyH("LEFT")
                bullet:SetJustifyV("TOP")
                if bullet.SetWordWrap then bullet:SetWordWrap(true) end
                bullet:SetText("• " .. note)
                
                local measuredHeight = bullet:GetStringHeight() or 12
                local estimatedLines = math.ceil((string.len(note or "") + 2) / 72)
                local height = math.max(measuredHeight, estimatedLines * 12, 12)
                yOffset = yOffset - height - 6
            end
        end
        
        -- Divider line between updates (skip on the last one)
        if i < #history then
            local divider = ScrollChild:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.1)
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset - 5)
            divider:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -15, yOffset - 5)
            yOffset = yOffset - 20
        end
    end

    ScrollChild:SetHeight(math.abs(yOffset))
end
