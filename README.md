# KeyGlass

KeyGlass is a Swift-native macOS menu bar utility that reimplements the practical keyboard-visualization workflow of KeyCastr.

## Install

### Homebrew

After the first signed `v*` release is published:

```bash
brew install --cask mkusaka/tap/keyglass
```

### Manual Download

Download the latest `.zip` from [GitHub Releases](https://github.com/mkusaka/KeyGlass/releases), extract it, and move `KeyGlass.app` to `/Applications`.

Release automation signs the app with a Developer ID certificate and notarizes it with Apple before publishing the GitHub Release asset and updating the Homebrew cask.

## Current Features

- Menu bar utility mode with `LSUIElement`
- Capture enable and disable controls
- Input Monitoring permission checks and requests
- Session event taps for keyboard input and mouse clicks
- Transparent stacked overlay with per-entry fade-out behavior
- Rapid plain-key coalescing into a single visible history entry
- Display modes for modifier-only, modified keys, and all keys
- Layout-aware keyboard translation via macOS keyboard layout APIs
- Special key coverage for arrows, return, delete, function keys, and JIS-related keys
- Persistent display settings for position, size, opacity, and timing
- Persistent history settings for merge window, stack size, and stack direction
- Start-at-login support via macOS login items
- Optional mouse click visualization
- Drag-to-reposition behavior that pauses automatic fade while the overlay is being moved
- Settings window with built-in preview actions
- Sparkle-powered in-app update checks

## Architecture

- `AppCoordinator`
- `SettingsStore`
- `SystemInputPermissionManager`
- `SystemEventTapService`
- `SystemLaunchAtLoginManager`
- `KeystrokeFormatter`
- `OverlayWindowController`
- `SettingsWindowController`

## Requirements

- macOS 13+
- Xcode 16+

## Tooling

This repository uses `mise` to pin the CLI tools used for linting and formatting.

`Sparkle` is declared in `Dependencies/KeyGlassSparkle/Package.swift` so Renovate can track it with the built-in Swift manager.

```bash
brew install mise
mise trust
mise install
```

## Release Automation

The release workflow signs the app with a locally exported `Developer ID Application` certificate, notarizes it with `notarytool`, uploads `KeyGlass.zip` to GitHub Releases, and dispatches the updated SHA256 to `mkusaka/homebrew-tap`.

Signed releases require these GitHub repository secrets:

- `APPLE_TEAM_ID`
- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_APP_STORE_CONNECT_API_KEY_BASE64`
- `APPLE_APP_STORE_CONNECT_KEY_ID`
- `APPLE_APP_STORE_CONNECT_ISSUER_ID`
- `HOMEBREW_TAP_TOKEN`
- `SPARKLE_ED_PRIVATE_KEY`

KeyGlass currently shares the same Sparkle public key as `keypunch`, so `SPARKLE_ED_PRIVATE_KEY` must match that existing private key.

Manual `workflow_dispatch` runs validate archive, export, signing, notarization, and stapling without creating a GitHub Release, updating the Homebrew tap, or publishing the Sparkle appcast. Tag pushes matching `v*` also publish the release asset, update the tap cask, and deploy `appcast.xml` to the `gh-pages` branch. The first successful signed tag release is what makes `brew install --cask mkusaka/tap/keyglass` work end-to-end.

### How To Cut A Release

1. Merge the release target changes into `main` and confirm the `Test` workflow is green.
2. Create and push a semantic version tag.

```bash
VERSION=0.0.8
git tag "v${VERSION}"
git push origin "v${VERSION}"
```

3. Watch the `Release` workflow triggered by the tag push.

```bash
gh run list --workflow Release --limit 5
gh run watch
```

4. Verify that the workflow produced all downstream artifacts.

```bash
gh release view "v${VERSION}"
curl -fsSL https://mkusaka.github.io/KeyGlass/appcast.xml | rg "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"
```

Expected results:

- a signed `KeyGlass.zip` attached to the GitHub Release
- a cask update dispatch to `mkusaka/homebrew-tap`
- an updated `appcast.xml` on the `gh-pages` branch

The workflow derives the release version from the tag name, so repository files do not need a manual version bump just for release publication.

### How To Run A Validation Build

Use `workflow_dispatch` on the `Release` workflow when you want to validate signing, notarization, and export without publishing a GitHub Release or updating Homebrew / Sparkle delivery.

Dispatch it with a version input, for example:

```bash
gh workflow run Release --field version=0.0.8
gh run list --workflow Release --limit 5
gh run watch
```

The workflow will:

- set `CFBundleShortVersionString` from that version
- derive `CFBundleVersion` as `major * 10000 + minor * 100 + patch` (for `0.0.8`, build version is `8`)
- build, sign, notarize, and export the app
- skip GitHub Release creation, Homebrew dispatch, and `gh-pages` appcast deployment

## Development

Build:

```bash
xcodebuild -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' build
```

Test:

```bash
xcodebuild test -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' -skip-testing:KeyGlassUITests
```

Format:

```bash
mise exec -- swiftformat .
```

Lint:

```bash
mise exec -- swiftformat --lint .
mise exec -- swiftlint lint --quiet
```

Git hooks:

```bash
mise exec -- lefthook install
```

The `pre-commit` hook formats staged Swift files with `swiftformat`, re-stages
any fixes, and then runs `swiftlint` against the staged Swift files.

UI test attempt:

```bash
xcodebuild test KEYGLASS_LSUIELEMENT=NO -scheme KeyGlass -project KeyGlass.xcodeproj -destination 'platform=macOS' -only-testing:KeyGlassUITests
```

## Testing Notes

- Hosted AppKit tests in `KeyGlassTests` cover the current user-visible behavior and settings flow.
- Hosted coverage now includes rapid-input merge, stack trimming, and drag-paused fade behavior.
- The `KeyGlassUITests` target has been expanded for the new history controls and merge behavior, but it still needs a non-agent build (`KEYGLASS_LSUIELEMENT=NO`) and remains unstable in this CLI environment.

## Specifications

- English spec: `SPEC.md`
- Japanese spec: `SPEC.ja.md`
- Phase checklist: `TODO.md`
