# Baseline Repo Create Report — itFactor 1.23.26

Date: 2026-01-31
Xcode: 26.2 (Build 17C52)

## Project/Workspace
- Workspace: none
- Project: `STSiPhone/ITFactoriPhone.xcodeproj`

## Scheme discovery
Initial `xcodebuild -list` failed in sandbox due to package resolution + CoreSimulator service issues. Re-ran with escalated permissions and it succeeded.

`xcodebuild -list` output:

```
Information about project "ITFactoriPhone":
    Targets:
        STSiPhone
        STSiPhoneTests
        STSiPhoneUITests
        STSWatch Watch App

    Build Configurations:
        Debug
        Release

    If no build configuration is specified and -scheme is not passed then "Release" is used.

    Schemes:
        STSiPhone
        STSWatch Watch App
```

## Packages
- Resolved via `xcodebuild -list` (package graph resolution). No upgrades performed.
- Packages found:
  - PryntTrimmerView @ 4.0.2
  - TOCropViewController @ 2.8.0

## Minimal changes applied
- **Scheme fix only:** Updated `STSiPhone/ITFactoriPhone.xcodeproj/xcshareddata/xcschemes/STSiPhone.xcscheme` to reference `container:ITFactoriPhone.xcodeproj` (was `container:STSiPhone.xcodeproj`).
  - This was required to make `xcodebuild -showBuildSettings` work.
- Added `.gitignore` (copied from `/Users/kevinbarrett/SelfTapeStudio/.gitignore`).

No build settings, signing, entitlements, CloudKit, or code changes were made.

## Build settings (from `xcodebuild -showBuildSettings`)
```
CURRENT_PROJECT_VERSION = 1
MARKETING_VERSION = 1.0
PRODUCT_BUNDLE_IDENTIFIER = com.rheirhome.STSiPhone
```

## Repro steps
```
cd /Users/kevinbarrett/itFactor_1.23.26_git
PROJECT=$(find . -maxdepth 2 -name "*.xcodeproj" -print -quit)

# List schemes
xcodebuild -project "$PROJECT" -list

# Show build settings
xcodebuild -project "$PROJECT" -scheme "STSiPhone" -showBuildSettings | egrep "PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION|CURRENT_PROJECT_VERSION" | head -n 50
```

## Notes
- Xcode UI was not opened to avoid upgrade prompts.
- If you need to open in Xcode, do **not** accept upgrade prompts.
