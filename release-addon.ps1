param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$CommitMessage,

    [string[]]$Notes,

    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $gitExe = "C:\Program Files\Git\cmd\git.exe"
    & $gitExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' ')"
    }
}

function Read-Utf8Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
    $reader = [System.IO.StreamReader]::new($Path, $utf8, $true)
    try {
        return $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

function Update-FileText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern,

        [Parameter(Mandatory = $true)]
        [string]$Replacement
    )

    $content = Read-Utf8Text -Path $Path
    $updated = [regex]::Replace($content, $Pattern, $Replacement, 1)
    if ($updated -eq $content) {
        throw "Could not update expected pattern in '$Path'."
    }

    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-ReleaseNotes {
    param(
        [string[]]$InlineNotes,
        [string]$NextChangelogPath
    )

    $resolvedNotes = @()

    if ($InlineNotes -and $InlineNotes.Count -gt 0) {
        if ($InlineNotes.Count -eq 1 -and $InlineNotes[0].Contains(",")) {
            $InlineNotes = $InlineNotes[0] -split '\s*,\s*'
        }
        foreach ($note in $InlineNotes) {
            $trimmed = $note.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $resolvedNotes += $trimmed.TrimStart('-', '*', ' ')
            }
        }
        return ,$resolvedNotes
    }

    if (-not (Test-Path -LiteralPath $NextChangelogPath)) {
        return @()
    }

    foreach ($line in ((Read-Utf8Text -Path $NextChangelogPath) -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        $resolvedNotes += $trimmed.TrimStart('-', '*', ' ')
    }

    return ,$resolvedNotes
}

function Update-Changelog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$ChangelogPath,

        [Parameter(Mandatory = $true)]
        [string[]]$ReleaseNotes
    )

    if ($ReleaseNotes.Count -eq 0) {
        throw "No release notes were provided. Add bullets to NEXT_CHANGELOG.md or pass -Notes."
    }

    $sectionLines = @("## v$Version", "")
    foreach ($note in $ReleaseNotes) {
        $sectionLines += "- $note"
    }
    $newSection = ($sectionLines -join [Environment]::NewLine).TrimEnd()

    $existing = ""
    if (Test-Path -LiteralPath $ChangelogPath) {
        $existing = (Read-Utf8Text -Path $ChangelogPath).Trim()
    }

    if ($existing -match "(?m)^## v$([regex]::Escape($Version))$") {
        throw "CHANGELOG.md already contains an entry for v$Version."
    }

    if ([string]::IsNullOrWhiteSpace($existing)) {
        Write-Utf8NoBom -Path $ChangelogPath -Content ($newSection + [Environment]::NewLine)
    } else {
        Write-Utf8NoBom -Path $ChangelogPath -Content ($newSection + [Environment]::NewLine + [Environment]::NewLine + $existing + [Environment]::NewLine)
    }
}

function Escape-LuaString {
    param([string]$Text)
    return $Text.Replace('\', '\\').Replace('"', '\"')
}

function Update-EmbeddedChangelog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfilesPath,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string[]]$ReleaseNotes
    )

    $content = Read-Utf8Text -Path $ProfilesPath
    if ($content -match ('(?m)version = "v' + [regex]::Escape($Version) + '"')) {
        throw "Profiles.lua already contains an embedded changelog entry for v$Version."
    }

    $dateText = (Get-Date).ToString("MMMM d, yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
    $entryLines = @(
        "    {",
        "        version = ""v$Version"",",
        "        date = ""$dateText"",",
        "        notes = {"
    )

    foreach ($note in $ReleaseNotes) {
        $entryLines += "            """ + (Escape-LuaString $note) + ""","
    }

    $entryLines += @(
        "        }",
        "    },"
    )

    $entryText = ($entryLines -join [Environment]::NewLine)
    $updated = [regex]::Replace($content, '(?m)^P\.CHANGELOG = \{\r?\n', "P.CHANGELOG = {`r`n$entryText`r`n", 1)
    if ($updated -eq $content) {
        throw "Could not prepend the embedded changelog entry in Profiles.lua."
    }

    Write-Utf8NoBom -Path $ProfilesPath -Content $updated
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $scriptDir

$normalizedVersion = $Version.Trim()
if ($normalizedVersion.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) {
    $normalizedVersion = $normalizedVersion.Substring(1)
}

if ([string]::IsNullOrWhiteSpace($normalizedVersion)) {
    throw "Version cannot be empty."
}

$tagName = "v$normalizedVersion"
if (-not $CommitMessage) {
    $CommitMessage = "Release $tagName"
}

$tocPath = Join-Path $scriptDir "OakUI_Installer.toc"
$profilesPath = Join-Path $scriptDir "Profiles.lua"
$readmePath = Join-Path $scriptDir "README.md"
$changelogPath = Join-Path $scriptDir "CHANGELOG.md"
$nextChangelogPath = Join-Path $scriptDir "NEXT_CHANGELOG.md"

$releaseNotes = Get-ReleaseNotes -InlineNotes $Notes -NextChangelogPath $nextChangelogPath

$rawStatus = & "C:\Program Files\Git\cmd\git.exe" status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw "Could not read git status."
}

$blockingStatus = @()
foreach ($line in ($rawStatus -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $pathPart = $line.Substring(3).Trim()
    if ($pathPart -eq "NEXT_CHANGELOG.md") { continue }
    $blockingStatus += $line
}

if ($blockingStatus.Count -gt 0) {
    throw "Git working tree is not clean. Commit or stash your changes before running release-addon.ps1."
}

Update-Changelog -Version $normalizedVersion -ChangelogPath $changelogPath -ReleaseNotes $releaseNotes
Update-EmbeddedChangelog -ProfilesPath $profilesPath -Version $normalizedVersion -ReleaseNotes $releaseNotes
Update-FileText -Path $tocPath -Pattern '(?m)^## Version:\s*.+$' -Replacement "## Version: $normalizedVersion"
Update-FileText -Path $profilesPath -Pattern '(?m)^P\.VERSION\s*=\s*".*?"\s*$' -Replacement "P.VERSION = ""$normalizedVersion"""
Update-FileText -Path $readmePath -Pattern '(?m)^Current repo version:\s*`[^`]+`$' -Replacement "Current repo version: ``$normalizedVersion``"
Write-Utf8NoBom -Path $nextChangelogPath -Content "# Add one bullet per line for the next release.`r`n# Example:`r`n# Updated the installer flow for a smoother first-run experience`r`n# Refined a module import profile`r`n"

Invoke-Git -Arguments @("add", "CHANGELOG.md", "NEXT_CHANGELOG.md", "OakUI_Installer.toc", "Profiles.lua", "README.md")
Invoke-Git -Arguments @("commit", "-m", $CommitMessage)
Invoke-Git -Arguments @("tag", "-a", $tagName, "-m", $tagName)
Invoke-Git -Arguments @("push")
Invoke-Git -Arguments @("push", "origin", $tagName)

if (-not $SkipZip) {
    & (Join-Path $scriptDir "package-release.ps1") -Version $normalizedVersion
    if ($LASTEXITCODE -ne 0) {
        throw "package-release.ps1 failed."
    }
}

Write-Host ""
Write-Host "Release complete."
Write-Host "Version: $normalizedVersion"
Write-Host "Tag: $tagName"
Write-Host "If your integrations are configured, this pushed tag will trigger CurseForge and Wago automation."
Write-Host "Changelog sources: CHANGELOG.md and Profiles.lua"
Write-Host "GitHub release page:"
Write-Host "https://github.com/Smokenoaken/OakUI_Installer/releases/new?tag=$tagName"
