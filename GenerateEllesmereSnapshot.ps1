param(
    [string]$SavedVariablesPath = "C:\Blizzard Games\World of Warcraft\_retail_\WTF\Account\JWAALEWYN\SavedVariables\EllesmereUI.lua",
    [string]$OutputPath = ".\EllesmereSnapshot.lua"
)

$ErrorActionPreference = "Stop"

$resolvedInput = Resolve-Path -LiteralPath $SavedVariablesPath
$content = Get-Content -LiteralPath $resolvedInput -Raw
if ($content -notmatch "^\s*EllesmereUIDB\s*=") {
    throw "Input file does not look like an EllesmereUIDB SavedVariables file: $resolvedInput"
}

$snapshot = $content -replace "^\s*EllesmereUIDB\s*=", "P.ELLESMERE_SNAPSHOT ="

# Do not package account or character wealth data in OakUI baked settings.
# Ellesmere's live DB owns these values per user; baked imports must never carry
# Oakensoul/OakUI character gold, warband gold, or DataBars money caches.
function Clear-LuaTableAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $needle = "[`"$Key`"] = {"
    $builder = [System.Text.StringBuilder]::new()
    $index = 0

    while ($index -lt $Text.Length) {
        $start = $Text.IndexOf($needle, $index, [System.StringComparison]::Ordinal)
        if ($start -lt 0) {
            [void]$builder.Append($Text.Substring($index))
            break
        }

        [void]$builder.Append($Text.Substring($index, $start - $index))
        $pos = $start + $needle.Length - 1
        $depth = 0
        $inString = $false
        $escaped = $false

        while ($pos -lt $Text.Length) {
            $ch = $Text[$pos]
            if ($inString) {
                if ($escaped) {
                    $escaped = $false
                } elseif ($ch -eq '\') {
                    $escaped = $true
                } elseif ($ch -eq '"') {
                    $inString = $false
                }
            } else {
                if ($ch -eq '"') {
                    $inString = $true
                } elseif ($ch -eq '{') {
                    $depth++
                } elseif ($ch -eq '}') {
                    $depth--
                    if ($depth -eq 0) {
                        $pos++
                        if ($pos -lt $Text.Length -and $Text[$pos] -eq ',') { $pos++ }
                        break
                    }
                }
            }
            $pos++
        }

        $index = $pos
    }

    return $builder.ToString()
}

function Clear-LuaScalarAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    return [regex]::Replace($Text, "(?m)^\[`"$([regex]::Escape($Key))`"\]\s*=\s*[^,\r\n]+,\r?\n", "")
}

$snapshot = Clear-LuaTableAssignment -Text $snapshot -Key "characterGold"
$snapshot = Clear-LuaTableAssignment -Text $snapshot -Key "warbandGold"
$snapshot = Clear-LuaTableAssignment -Text $snapshot -Key "characters"
$snapshot = Clear-LuaScalarAssignment -Text $snapshot -Key "currentMoney"
$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
$escapedInput = ($resolvedInput.ProviderPath -replace "\\", "\\")

$postProcess = @'

local function OakUI_EllesmereSnapshotCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[OakUI_EllesmereSnapshotCopy(k, seen)] = OakUI_EllesmereSnapshotCopy(v, seen)
    end
    return copy
end

do
    local snapshot = P.ELLESMERE_SNAPSHOT
    if type(snapshot) == "table" then
        snapshot.characterGold = nil
        snapshot.warbandGold = nil
    end

    local function OakUI_EllesmereSnapshotStripWealth(node)
        if type(node) ~= "table" then return end
        node.characterGold = nil
        node.warbandGold = nil
        node.characters = nil
        node.currentMoney = nil
        for _, value in pairs(node) do
            OakUI_EllesmereSnapshotStripWealth(value)
        end
    end

    OakUI_EllesmereSnapshotStripWealth(snapshot and snapshot.profiles)

    local profiles = snapshot and snapshot.profiles
    if type(profiles) == "table" then
        local tank = profiles["OakUI Tank/DPS"] or profiles["OakUI-Tank/DPS"] or profiles.OakUI
            or (snapshot.activeProfile and profiles[snapshot.activeProfile])
        local healerSource = profiles["OakUI Healer"] or profiles["OakUI-Healer"] or profiles["OakUI Heals"]

        if type(tank) == "table" then
            local normalizedHealer = OakUI_EllesmereSnapshotCopy(tank)

            if type(healerSource) == "table" then
                normalizedHealer.addons = normalizedHealer.addons or {}
                local healerRaid = healerSource.addons and healerSource.addons.EllesmereUIRaidFrames
                local targetRaid = normalizedHealer.addons.EllesmereUIRaidFrames or {}

                if type(healerRaid) == "table" then
                    for key, value in pairs(healerRaid) do
                        if type(key) == "string" and key:find("^party") then
                            targetRaid[key] = OakUI_EllesmereSnapshotCopy(value)
                        end
                    end
                    normalizedHealer.addons.EllesmereUIRaidFrames = targetRaid
                end
            end

            profiles["OakUI Healer"] = normalizedHealer
        end

        if type(profiles["OakUI Healer"]) == "table" and type(snapshot.profileOrder) == "table" then
            local found = false
            for _, name in ipairs(snapshot.profileOrder) do
                if name == "OakUI Healer" then found = true break end
            end
            if not found then table.insert(snapshot.profileOrder, "OakUI Healer") end
        end
    end
end
'@

$header = @"
local addonName, addonTable = ...
local P = addonTable.Profiles

-- Generated from EllesmereUI SavedVariables. Do not hand-edit this file.
-- Rebuild with GenerateEllesmereSnapshot.ps1 after updating the source UI.
P.ELLESMERE_SNAPSHOT_META = {
    generatedAt = "$generatedAt",
    source = "$escapedInput",
}

"@

$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($resolvedOutput, ($header + $snapshot + $postProcess), $utf8NoBom)
Write-Host "Wrote $resolvedOutput from $resolvedInput"
