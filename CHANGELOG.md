## v2.0.0-EllesmereEdition

- Consolidated Ellesmere smart player visibility and compacted the Ellesmere Tweaks page layout
- Restored the OakUI two-window chat layout installer entry and Chat Cleaning apply button
- Included chat layout in Quick Install and Install All while restoring role/profile prompts for Quick Install
- Updated the installer home screen branding to show OakUI for EllesmereUI with both logos
- Tightened the Ellesmere Tweaks layout to fit the default installer window without horizontal spillover
- Grouped Ellesmere Tweaks options into Visibility, Player Frame, and Compact Layout sections
- Stopped filtering protected player chat events to avoid Blizzard chat history secret-token taint errors
- Refreshed Compact Utility CDs and Compact Resource automatically after spec and form changes
- Simplified the Ellesmere UI profile install, kept Danders role profiles, and removed ElvUI profile imports
- Added detailed mouseover descriptions for every Ellesmere Tweaks option
- Cleaned up Custom Fonts and Supporters tab layouts to stay inside the installer frame
- Updated the supporter list with Mandos retained as the top supporter

## v2.0.0-ellesmere-alpha3.1

- Fixed Ellesmere player frame staying hidden when OakUI show-in-group visibility is enabled

## v2.0.0-ellesmere-alpha3

- Added Ellesmere player frame show toggles for player health below 100% and group membership

## v2.0.0-ellesmere-alpha2

- Fixed Compact Resource overlap after reload for characters that have both a class resource and power bar

## v2.0.0-ellesmere-alpha1

- Moved OakUI installer defaults to EllesmereUI as the active base UI provider.
- Added Ellesmere profile injection and removed ElvUI-only companion profile installs that Ellesmere does not use.
- Added DandersFrames profile injection for DPS/Tank and Healer setups.
- Added Ellesmere Tweaks for player/pet visibility, action bar mouseover behavior, CDM visibility, chat fading, compact Utility CDM, and compact resource positioning.
- Optimized installer runtime work so Ellesmere tweak refreshes are event-driven instead of permanently polling.

## v2.0.0-beta2

- Added LibSharedMedia-aware custom font replacement with broad Blizzard font override support.
- Applied OakUI font replacement automatically during Quick Install and Install All.
- Removed the standalone OakUI chat layout installer step from the ElvUI-backed install flow.
- Added the initial EllesmereUI profile payload for the upcoming backbone migration.

## v2.0.0-beta1

- Migrated OakUI to ElvUI as the base UI with profile and private string injection.
- Added one-click Quick Install with ElvUI installer bypass and per-character first-run tracking.
- Added OakUI action bar fading, visibility controls, chat cleaning updates, and minimap button support.
- Added Ayije CDM, Chonky Character Sheet, MPlusTimer, Platynator, Details, XIV Databar, and BigWigs profile handling.

## v1.5.4

- Refreshed embedded OakUI import strings
- Fixed OakUI chat layout so whisper handling preserves Blizzard's temporary whisper behavior
- Synced the OakUI action bar fading toggle with QUI 3.0 HUD visibility settings
- Added a Top Supporters section and highlighted Mandos

## v1.5.3

- Added WoW 12.0.5 interface compatibility so the installer loads when servers come up

## v1.5.2

- Updated OakUI for the latest QUI overhaul and refreshed installer compatibility
- Fixed QUI visibility prompts so they no longer send users to Edit Mode unnecessarily
- Fixed the Disable Action Bar Fading toggle to refresh QUI's current action bar fade behavior correctly
- Updated FAQ actions so most QUI help buttons open Layout Mode, while party-frame troubleshooting still opens QUI settings
- Improved chat loot filtering so crafted item messages identify the player who received the item
- Refreshed the OakUI logo assets and chat layout polish

## v1.5.1

- Fixed chat tabs so they fully disappear unless hovered
- Refreshed the QUI export profile in `Profiles.lua`

## v1.5.0

- Updated for the newly released QUI 3.0 update (April 3, 2026)

## v1.41.3-alpha2

- Refreshed the OakUI alpha while QUI stabilizes
- Fixed UTF-8 supporter name handling in release files
- Added Discord release announcements

## v1.41.3-alpha1

- Pre-release build for the upcoming QUI stable release
- Holding the full release until QUI moves from beta to release

## v1.41.2

- Tweaked Group Frames and Custom Tracker to remove overlaps in the Tank/DPS profile
- Updated the Platynator profile to make minions more visible
- Updated the Supporters tab
