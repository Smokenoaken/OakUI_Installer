## v2.6.5-EllesmereEdition

- Updated the Ellesmere healer install flow so class resources, power bars, cooldown anchors, and healer-specific profile data settle correctly after import.
- Improved fresh-install popup handling so OakUI setup stays front and center while suppressing retired Ellesmere/QUI onboarding prompts.
- Refreshed bundled profile payloads, raw import support, and the supporter list for the current OakUI setup.

## v2.6.4-EllesmereEdition

- Added a dedicated docked Trade chat tab to the OakUI chat layout
- Refreshed the baked Ellesmere profile snapshot and profile strings

## v2.6.3-EllesmereEdition

- Refreshed the baked Ellesmere and Blizzi profile payloads from the latest OakUI setup.
- Added a Hide Error Messages option that suppresses most red UI error text while keeping important warnings visible.

## v2.6.2-EllesmereEdition

- Updated TOC interface compatibility for World of Warcraft 12.0.7.

## v2.6.0-EllesmereEdition

- Added OakUI Round Thin border styling with rounded masks for Ellesmere frames, cast bars, tracking bars, boss mod bars, Blizzi interrupt bars, and damage meters.
- Refreshed the baked Ellesmere Tank/DPS and Healer profiles, including the updated Tank/DPS settings while preserving the Healer party-frame layout.
- Grouped all rounded-border options into a tighter Rounded Borders section on the Ellesmere Tweaks page.
- Updated the minimap button to use the bundled PNG logo.

## v2.5.2-EllesmereEdition

- Fixed Trinket/Pot bar display.
- Fixed Tracked Bars display.

## v2.5.1-EllesmereEdition

- Removed the retired Compact Layout section from Ellesmere Tweaks.
- Removed the Compact Utility CDs option and runtime CDM utility anchor mover now that EllesmereUI handles this natively.
- Stopped OakUI from refreshing or applying the old Utility CD compact positioning on cooldown, spec, or shapeshift events.

## v2.5-EllesmereEdition

- Added a dedicated Ellesmere Import tab with QUI-style selective section imports.
- Baked OakUI Tank/DPS and OakUI Healer Ellesmere settings directly from SavedVariables.
- Normalized the Healer baked profile from Tank/DPS with only party-frame healer differences overlaid.
- Added role-aware Ellesmere installs for Quick Install, Install All, and selective imports.
- Removed Danders Frames profile support and Ayije CDM profile support from the OakUI installer.
- Refreshed Ellesmere optional dependencies and bundled module coverage for the Ellesmere Edition installer.

## v2.0.9-EllesmereEdition

- Discovered a stutter-causing issue in BossMods profiles and updated them to avoid encounter stutters

## v2.0.8-EllesmereEdition

- Added optional DBM profile injection and raw import support
- Added optional Blizzi Party Tools profile injection and raw import support
- Included installed optional boss/tool profiles in Quick Install and Install All

## v2.0.6-EllesmereEdition

- Allowed Ellesmere player/pet visibility changes made in Ellesmere's own settings to override OakUI's saved tweak state
- Changed OakUI's Hide Player/Pet Ellesmere tweak to switch Visibility Options directly between None and Hide without Target without requiring a reload prompt
- Synced OakUI's Hide Action Bars, Hide CDM, and Hide Chat Background Ellesmere tweaks through Ellesmere's native settings
- Restored the reload prompt for OakUI's Hide Action Bars and Hide Chat Background Ellesmere tweaks because those Ellesmere settings require reload to fully match in-game state
- Included Ellesmere Resource Bars in OakUI's Hide CDM toggle so resource display follows the same None and Hide without Target visibility options
- Removed the Compact Resource Ellesmere tweak now that EllesmereUI handles compact resource placement natively
- Registered the bundled Electrofied font variants with LibSharedMedia
- Documented that the tooltip can be repositioned in /editmode
- Moved the tooltip location to the top left of the damage meters in the embedded Edit Mode layout

## v2.0.5-EllesmereEdition

- Fixed a FontEngine error when applying OakUI font settings to Blizzard Timeline frames

## v2.0.4-EllesmereEdition

- Optimized OakUI Chat Layout Implementation When Installing
- Disabled EllesmereUI Nameplates on reload when Platynator is enabled
- Added supplemental Ellesmere tracked buff bar and chat settings after profile import
- Imported the Blizzard Edit Mode layout automatically as an OakUI account layout
- Updated the embedded OakUI Edit Mode layout for objective tracker and timeline placement
- Applied OakUI font settings to the Blizzard Encounter Timeline
- Synced the OakUI Loot chat tab alpha with EllesmereUI chat fading without changing tab text styling
- Enabled Blizzard Timeline CVars when importing the BigWigs profile
- Updated the Patreon and Ko-fi supporter list

## v2.0.3-EllesmereEdition

- Disabled the Ellesmere Tooltip Anchor option to avoid tainting Blizzard and third-party tooltip processing while a safer anchor integration is evaluated

## v2.0.2-EllesmereEdition

- Fixed the Ellesmere Tooltip Anchor so Oak sets the default tooltip anchor without re-rendering or repeatedly repositioning EUI/WoW tooltips

## v2.0.1-EllesmereEdition

- Added an Ellesmere Tweaks toggle for a movable Tooltip Anchor in Ellesmere Unlock Mode
- Kept the Extra Action Button visible when active while action bars are mouseover-hidden
- Kept the LFG/LFR queue eye independent from action bar mouseover hiding
- Updated the Ellesmere profile with a Dragonriding bar
- Changed the Ellesmere cast bar color to a gradient class color
- Updated the Ellesmere stance bar to anchor to the top action bar and grow right
- Added Cody Buxton to the supporter list

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
