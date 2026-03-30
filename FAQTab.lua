local addonName, addonTable = ...
local P = addonTable.Profiles

function addonTable.BuildFAQUI(parentFrame)
    local cWrap = addonTable.cWrap
    local MakeFlatButton = addonTable.MakeFlatButton
    local SkinScrollbar = addonTable.SkinScrollbar

    local Title = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Title:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -20)
    Title:SetJustifyH("LEFT")
    Title:SetText(cWrap .. "Frequently Asked Questions|r")

    local Desc = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Desc:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -10)
    Desc:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -15, -10)
    Desc:SetJustifyH("LEFT")
    Desc:SetText("Got a question? Check the answers below to quickly resolve common setup issues.")

    local ScrollFrame = CreateFrame("ScrollFrame", "OakUI_FAQScroll", parentFrame, "UIPanelScrollFrameTemplate")
    local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
    ScrollFrame:SetScrollChild(ScrollChild)
    ScrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -80)
    ScrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -30, 20)

    SkinScrollbar(ScrollFrame)

    local faqs = P.FAQ or {}
    local faqElements = {}

    -- 1. Create all the graphical elements once (hidden by default until positioned)
    for i, entry in ipairs(faqs) do
        local item = {}
        
        item.qText = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        item.qText:SetJustifyH("LEFT")
        item.qText:SetText("Q: " .. (entry.q or "Unknown Question"))
        item.qText:SetTextColor(1, 0.82, 0) -- Classic WoW Gold

        item.aText = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.aText:SetJustifyH("LEFT")
        item.aText:SetText(entry.a or "")
        item.aText:SetTextColor(0.8, 0.8, 0.8)

        if entry.quiTab then
            item.btn = MakeFlatButton(ScrollChild, "Open QUI", 100, 24)
            item.btn.Text:SetTextColor(addonTable.colors.r, addonTable.colors.g, addonTable.colors.b)
            item.btn:SetScript("OnClick", function()
                if _G.QUI_CompartmentClick then
                    _G.QUI_CompartmentClick()
                elseif _G.QUI and _G.QUI.SlashCommandOpen then
                    _G.QUI:SlashCommandOpen("")
                elseif _G.QUI and _G.QUI.GUI then
                    _G.QUI.GUI:Toggle()
                else
                    print("|cffff0000[OakUI]|r The QUI addon is not loaded or enabled!")
                end
            end)

            item.btnHelper = ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            item.btnHelper:SetText("➔ Navigate to the |cffffffff" .. entry.quiTab .. "|r tab.")
            item.btnHelper:SetTextColor(0.6, 0.6, 0.6)
        end

        if i < #faqs then
            item.div = ScrollChild:CreateTexture(nil, "ARTWORK")
            item.div:SetColorTexture(1, 1, 1, 0.1)
            item.div:SetHeight(1)
        end

        table.insert(faqElements, item)
    end

    -- 2. Define the dynamic layout function
    local function UpdateLayout(width)
        local textWidth = (width or 470) - 30
        local yOffset = -10

        for i, item in ipairs(faqElements) do
            -- Force width BEFORE GetStringHeight so WoW calculates word wrap lines correctly
            item.qText:ClearAllPoints()
            item.qText:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset)
            item.qText:SetWidth(textWidth + 10)
            yOffset = yOffset - item.qText:GetStringHeight() - 8

            item.aText:ClearAllPoints()
            item.aText:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, yOffset)
            item.aText:SetWidth(textWidth)
            yOffset = yOffset - item.aText:GetStringHeight() - 15

            if item.btn then
                item.btn:ClearAllPoints()
                item.btn:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 15, yOffset)
                item.btnHelper:ClearAllPoints()
                item.btnHelper:SetPoint("LEFT", item.btn, "RIGHT", 10, 0)
                yOffset = yOffset - 35
            end

            if item.div then
                item.div:ClearAllPoints()
                item.div:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 5, yOffset - 5)
                item.div:SetPoint("TOPRIGHT", ScrollChild, "TOPRIGHT", -15, yOffset - 5)
                yOffset = yOffset - 25
            end
        end

        ScrollChild:SetHeight(math.abs(yOffset))
    end

    -- 3. Hook into window resizing to recalculate everything dynamically
    ScrollFrame:SetScript("OnSizeChanged", function(self, width, height)
        ScrollChild:SetWidth(width)
        UpdateLayout(width)
    end)

    -- Fire it once to set the initial layout properly
    UpdateLayout(ScrollFrame:GetWidth() or 470)
end