local addonName, addonTable = ...

function addonTable.BuildFontsUI(parentFrame)
    local cWrap = addonTable.cWrap

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Custom Fonts|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10) -- Dynamic stretch
    Desc:SetJustifyH("LEFT")
    Desc:SetText("To get the complete OAK UI experience (including the 3D names floating above player heads), you need to copy the fonts folder manually. Addons cannot do this automatically due to Blizzard's security rules.\n\nHere is how to do it in 4 easy steps:")

    local steps = {
        "|cffffffffStep 1:|r Open your WoW AddOns folder and open the |cff9482c9OakUI_Installer|r folder.",
        "|cffffffffStep 2:|r Right-click and |cff00ff00COPY|r the folder named |cffffffffFonts|r that is inside it.",
        "|cffffffffStep 3:|r Go back to your main WoW |cffffffff_retail_|r folder (where your Interface folder is) and |cff00ff00PASTE|r it there.",
        "|cffffffffStep 4:|r Completely restart World of Warcraft."
    }

    local yOffset = -140
    for i, text in ipairs(steps) do
        local stepText = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        stepText:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 20, yOffset)
        stepText:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, yOffset)
        stepText:SetJustifyH("LEFT")
        stepText:SetText(text)
        yOffset = yOffset - 40
    end

    -- Visual Helper Box
    local boxBg = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    boxBg:SetHeight(60)
    boxBg:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 20, yOffset - 10)
    boxBg:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -30, yOffset - 10)
    boxBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    boxBg:SetBackdropColor(0.08, 0.08, 0.1, 1)
    boxBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local Note = boxBg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Note:SetPoint("CENTER", boxBg, "CENTER", 0, 0)
    Note:SetJustifyH("CENTER")
    Note:SetText(cWrap .. "Success Check:|r Your final folder structure should look exactly like this:\n|cffffffffWorld of Warcraft \\ _retail_ \\ Fonts|r")
end