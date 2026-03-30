# Releasing OakUI_Installer

This repo includes a root [`.pkgmeta`](.pkgmeta) so CurseForge can package the addon automatically from GitHub.
It also uses [CHANGELOG.md](CHANGELOG.md) as the manual CurseForge changelog source.
Upcoming notes can live in [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md), which the release script consumes automatically.

## One-Time CurseForge Setup

1. Generate a CurseForge API token:
   - Open https://www.curseforge.com/account/api-tokens
   - Create a token for webhook packaging
2. Add a GitHub webhook on [Smokenoaken/OakUI_Installer](https://github.com/Smokenoaken/OakUI_Installer):
   - GitHub repo Settings -> Webhooks -> Add webhook
   - Payload URL:
     `https://www.curseforge.com/api/projects/1462676/package?token=YOUR_TOKEN_HERE`
   - Leave the other settings at their defaults
3. In CurseForge packaging settings, choose whether you want:
   - all commits packaged as alpha, or
   - tagged pushes only

## One-Time Wago Setup

This repo includes [`.github/workflows/wago-release.yml`](.github/workflows/wago-release.yml), which watches for pushed tags like `v1.41.3` and publishes to Wago when the remaining Wago-specific values are configured.

You still need to do these two steps once:

1. Create or open your addon project on Wago and copy its 8-character project ID from the Wago developer dashboard.
2. Add that ID to `OakUI_Installer.toc` as:

   ```text
   ## X-Wago-ID: YOURWAGO
   ```

3. Create a Wago API token and save it as a GitHub repository secret named `WAGO_API_TOKEN`.

## Recommended Release Flow

Use the one-command helper:

```powershell
.\release-addon.ps1 -Version 1.41.3
```

What it does:

- reads bullet points from `NEXT_CHANGELOG.md` by default, or from `-Notes` if you pass them directly
- prepends a new release section into `CHANGELOG.md`
- updates the version in `OakUI_Installer.toc`
- updates `P.VERSION` in `Profiles.lua`
- prepends a new in-addon changelog entry into `Profiles.lua`
- updates the version line in `README.md`
- creates a release commit
- creates and pushes a tag such as `v1.41.3`
- pushes `main`
- builds a local zip in `dist\`

Recommended release steps:

1. Finish your code changes
2. Add one bullet per line to [NEXT_CHANGELOG.md](NEXT_CHANGELOG.md)
3. Test in-game
4. Run `.\release-addon.ps1 -Version 1.41.3`
5. Let CurseForge package the pushed tag as a Release using `CHANGELOG.md`
6. Let the Wago GitHub Action publish that same tag to Wago, if `## X-Wago-ID` and `WAGO_API_TOKEN` are configured
7. Optionally create a GitHub Release page for the same tag

Optional one-liner if you want to skip editing `NEXT_CHANGELOG.md`:

```powershell
.\release-addon.ps1 -Version 1.41.3 -Notes "Refined installer flow","Updated profile imports"
```

## Local Zip Fallback

If you ever want to build a zip manually instead of using automatic packaging:

```powershell
.\package-release.ps1
```

That creates `dist\OakUI_Installer-v<version>.zip` with the correct top-level addon folder.
