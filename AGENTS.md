# AGENTS.md

## Purpose
- Keep a single operational guide for contributors and agents working on Avenue GPX Viewer Extended.
- Document commands, debugging flow, and safety rules for predictable maintenance.

## Project Scope
- Main macOS app target: `Avenue`
- Preview extension: `GPXQuickLook`
- Thumbnail extension: `Avenue Thumbnails`
- File types currently handled: `gpx`, `rgp`

## Local Build Notes
- Open `Avenue.xcodeproj` in Xcode.
- Preferred validation:
  - Build `Avenue`
  - Build `GPXQuickLook`
  - Build `Avenue Thumbnails`
- If `xcodebuild` fails with CommandLineTools-only environment, switch developer dir to full Xcode before CLI builds.

## Quick Look Reload Checklist
Use this sequence after changing any Quick Look extension code or plist/entitlements:
1. Build and run from Xcode once (to refresh signed extension binaries).
2. Run:
   - `qlmanage -r`
   - `qlmanage -r cache`
   - `killall quicklookd Finder`
3. Verify plugin registration:
   - `pluginkit -m -A -v -i com.changjo.AvenueExtended.GPXQuickLook`
   - `pluginkit -m -A -v -i com.changjo.AvenueExtended.AvenueThumbnails`

## Known Quick Look Constraints
- On newer macOS versions, Apple MapKit base map rendering in Quick Look can be unreliable.
- `GPXQuickLook` currently uses:
  - GPX parsing for `.gpx`
  - CSV-to-GPX conversion for `.rgp`
- `GPXQuickLook/Info.plist` includes `com.changjo.rgp` in `QLSupportedContentTypes` for Space-bar preview.

## Entitlement Requirements
- `GPXQuickLook/GPXQuickLook.entitlements` must include:
  - `com.apple.developer.maps = true`
- Keep entitlement changes minimal unless a reproducible runtime restriction requires them.

## Code Safety Rules
- Do not run destructive git commands (`reset --hard`, `checkout --`) unless explicitly requested.
- Do not revert unrelated user changes in dirty worktrees.
- Keep patches focused on requested behavior and affected targets only.

## Maintenance Notes
- When adding new file types to the app, update:
  - `Avenue/Info.plist` document and UTI declarations
  - `GPXQuickLook/Info.plist` supported content types
  - `Avenue Thumbnails/Info.plist` supported content types
  - parsing logic in preview/thumbnail providers as needed
