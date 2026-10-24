local addonName, addonTable = ...

local hooked = false
local rows = setmetatable({}, { __mode = "k" })

function addonTable.GetOakInterruptCorners()
    local db = _G.OakUI_DB and _G.OakUI_DB.visibility
    return db and db.roundThinEUIInterrupts == true or false
end

local function StyleRow(fs, _, _, surface)
    if surface ~= "mythicTimer" or not addonTable.GetOakInterruptCorners() then return end
    local textFrame = fs:GetParent()
    local bar = textFrame and textFrame:GetParent()
    local row = bar and bar:GetParent()
    -- Only completed kick rows, including EUI's pooled cooldown layers.
    if not row or row.name ~= fs or row.sb ~= bar or row.textFrame ~= textFrame
        or not row.dur or not row.iconFrame or not row.icon or not row.bg or not row.marker then return end
    if row:IsForbidden() or row:IsProtected() then return end

    local E = _G.EllesmereUI
    local opts = rows[row]
    if not opts then
        local border = CreateFrame("Frame", nil, row)
        border:SetAllPoints(row)
        opts = { roots = {}, textures = {}, border = border, style = "solid" }
        rows[row] = opts
    end
    opts.textures[1] = row.bg
    opts.textures[2] = row.icon
    opts.textures[3] = bar:GetStatusBarTexture()
    opts.textures[4] = row.cover
    -- Never traverse or alter the secret-driven parent clip and gate.
    opts.border:SetFrameLevel(bar:GetFrameLevel())
    E.PP.HideBorder(row)
    E.ApplyBorderStyle(opts.border, 1, 0, 0, 0, 1, "solid")
    E.RoundCorners(row, addonTable.GetOakCornerRadius(), opts)
    opts.border:Show()
end

function addonTable.ApplyOakInterruptCornersIfEnabled()
    if not addonTable.GetOakInterruptCorners() or not addonTable.HasOakNativeCorners() then return end
    local E = _G.EllesmereUI
    local ns = E._ModuleNS and E._ModuleNS.EllesmereUIMythicTimer
    if not ns or type(ns.KTB_Refresh) ~= "function" or type(E.ApplyModuleFont) ~= "function"
        or type(E.ApplyBorderStyle) ~= "function" or not E.PP or not E.PP.HideBorder then return end
    if not hooked then
        -- EUI calls this after styling each row, also when pooled rows are reused.
        hooksecurefunc(E, "ApplyModuleFont", StyleRow)
        hooked = true
    end
    ns.KTB_Refresh()
end

function addonTable.SetOakInterruptCorners(state)
    _G.OakUI_DB = _G.OakUI_DB or {}
    _G.OakUI_DB.visibility = _G.OakUI_DB.visibility or {}
    _G.OakUI_DB.visibility.roundThinEUIInterrupts = state == true
    if state then
        addonTable.ApplyOakInterruptCornersIfEnabled()
        return
    end
    local E = _G.EllesmereUI
    local db = _G._EMT_AceDB
    local cfg = db and db.profile and db.profile.kickTracker
    for row, opts in pairs(rows) do
        E.RoundCorners(row, 0)
        opts.border:Hide()
        if row.border and cfg and (cfg.barBorderSize or 0) > 0 then E.PP.ShowBorder(row) end
    end
end
