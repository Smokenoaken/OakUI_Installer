# OakUI_Installer

OakUI Installer delivers the OakUI suite through a guided, one-click installer. The same addon detects Retail or WoW Forever and selects the appropriate install path.

## WoW Forever Beta Support

OakUI now supports WoW Forever Beta and Retail in the same addon. Forever installation and Edit Mode import were confirmed in-game on client `1.60.1.70009` (interface `16001`) with EllesmereUI `9.2.8`. Beta client updates may require further compatibility fixes.

- Install the same `OakUI_Installer` folder on either client; Retail keeps its existing behavior.
- Forever excludes DBM, BigWigs, Blizzi Party Tools, wMarker, Mythic+ forces, and Dragon Riding integrations.
- Forever imports OakUI's supported EUI styling and the same OakUI Blizzard Edit Mode layout used on Retail. Layout import is included in fresh installs and is also available separately from the Installer and Raw Imports tabs.
- The current EUI Cooldown Manager, AuraBuff Reminders, and Quickdraw setup is retained rather than replaced with Retail spell configuration. Retail spec assignments and condition overrides are excluded. Select the Tank/DPS or Healer profile manually.
- Use `/oaklayout` or the Installer's **Import Layout** button to import and select the OakUI Edit Mode layout separately.
- Run `/oak`, install the desired profile, accept the reload prompt, and check the layout, visibility toggles, combat, and group changes. BugSack errors are useful for beta follow-up fixes.

## Highlights

- one-click installation flow for the OakUI flagship suite
- built-in chat layout and chat filter tools
- bundled raw import strings as a manual fallback
- custom font setup guidance
- in-game changelog tab
- resizable installer window with persistent module-driven layout

## Requirements

- World of Warcraft Retail or WoW Forever Beta
- A compatible EllesmereUI installation
- Forever interface `16001`; supported Retail interfaces are listed in `OakUI_Installer.toc`

## Installation

1. Download or clone this repo.
2. Place the addon folder here:

```text
World of Warcraft\_retail_\Interface\AddOns\OakUI_Installer
World of Warcraft\_classic_beta_\Interface\AddOns\OakUI_Installer
```

Use the path for your client.

3. Launch WoW.
4. Make sure `OakUI Standalone Installer` is enabled in the AddOns list.

## Usage

Open the OakUI installer in-game and follow the guided tabs to import the OakUI suite, apply chat layout changes, or copy raw profile strings.

## Files

- [OakUI_Installer.toc](OakUI_Installer.toc) loads the addon and declares metadata
- [Profiles.lua](Profiles.lua) stores version info, profile strings, and the in-addon changelog
- [Core.lua](Core.lua) builds the main installer frame and routes between tabs
- [InstallerTab.lua](InstallerTab.lua) powers the primary one-click installation flow
- [RawImports.lua](RawImports.lua) exposes fallback import strings
- [ChatLayout.lua](ChatLayout.lua) and [ChatFilters.lua](ChatFilters.lua) manage chat setup helpers

## Releasing

This repo supports manual zip builds, CurseForge automatic packaging, and Wago publishing from GitHub tags.

For automatic packaging, configure a GitHub webhook that points at your CurseForge project packaging URL. The repo root already includes a [`.pkgmeta`](.pkgmeta) file so CurseForge packages the addon under the correct top-level folder name.

For Wago, the repo includes [`.github/workflows/wago-release.yml`](.github/workflows/wago-release.yml). After you add your `## X-Wago-ID` to [OakUI_Installer.toc](OakUI_Installer.toc) and set a `WAGO_API_TOKEN` GitHub secret, pushed version tags will publish there automatically too.

For the easiest tagged release flow, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\release-addon.ps1 -Version 1.41.3
```

Put one bullet per line in [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md), then run the command. The script rolls those notes into [CHANGELOG.md](CHANGELOG.md), updates the addon version files, updates the in-addon changelog tab, commits the release, creates and pushes the Git tag, and builds a local zip in `dist\`.

## Version

Current repo version: `2.7.2`

## Project Summary

OakUI Installer is the flagship OakUI suite built around the selected base UI framework. It focuses on a lightweight, one-click installation experience for a polished 1440p setup, with profiles and layout tools tuned for Mythic+, raiding, and general play.

The addon is designed to inject curated profiles into the core UI addons it works with, while adapting to role-specific needs like Healer and Tank/DPS layouts. Alongside the installer flow, it includes chat cleanup tools, raw import fallbacks, custom font guidance, and direct access to changelog content inside the addon itself.
