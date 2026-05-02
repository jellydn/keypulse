# 🧪 TestFlight Distribution Guide

This guide walks you through distributing KeyPulse via TestFlight, from code signing setup to adding beta testers.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Code Signing Setup](#code-signing-setup)
3. [Building Release Archives](#building-release-archives)
4. [Uploading to App Store Connect](#uploading-to-app-store-connect)
5. [Adding Internal Testers](#adding-internal-testers)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **macOS 13+** development machine
- **Xcode 15+** installed
- **Apple Developer Program** membership ($99/year)
- **App Store Connect** access with Admin or App Manager role

---

## Code Signing Setup

### 1. Configure Your Team ID

Edit `KeyPulse/ExportOptions.plist` and replace `YOUR_TEAM_ID_HERE` with your actual Apple Developer Team ID:

```xml
<key>teamID</key>
<string>ABCD123456</string>
```

**Find your Team ID:**

- Log into [App Store Connect](https://appstoreconnect.apple.com)
- Go to **Users and Access** → **Keys** tab
- Your Team ID is shown at the top

Or via command line:

```bash
# List all team IDs associated with your developer account
security find-identity -v -p codesigning | grep "Apple Development"
```

### 2. Register the App in App Store Connect

If this is the first time uploading:

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **My Apps**
2. Click **+** → **New App**
3. Fill in details:
   - **Platforms**: macOS
   - **Name**: KeyPulse
   - **Primary Language**: English
   - **Bundle ID**: `com.keypulse.app` (must match exactly)
   - **SKU**: keypulse-macos-001
4. Click **Create**

### 3. Verify Entitlements

KeyPulse uses minimal entitlements for security:

```xml
<!-- KeyPulse.entitlements -->
<dict>
    <!-- No microphone access needed (audio output only) -->
    <!-- No network access needed -->
    <!-- Hardened runtime enabled for App Store -->
</dict>
```

**Note**: CGEventTap for keyboard monitoring does NOT require a specific entitlement. Accessibility permission is granted at runtime via user prompt.

---

## Building Release Archives

### Method 1: Using the Build Script (Recommended)

```bash
# From the project root
./scripts/build-release.sh 0.1.0 1
```

**Arguments:**

- `0.1.0` - Version number (matches CFBundleShortVersionString)
- `1` - Build number (increment for each upload)

**Output:**

```
build/
├── KeyPulse-0.1.0-1.xcarchive    # Xcode archive
├── KeyPulse-0.1.0-1/              # Exported .app bundle
├── archive.log                     # Build log
└── export.log                      # Export log
```

### Method 2: Manual xcodebuild

```bash
cd KeyPulse

# Step 1: Create archive
xcodebuild archive \
    -scheme KeyPulse \
    -configuration Release \
    -archivePath ../build/KeyPulse.xcarchive \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="ABCD123456" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_ENTITLEMENTS="KeyPulse.entitlements"

# Step 2: Export for App Store
xcodebuild -exportArchive \
    -archivePath ../build/KeyPulse.xcarchive \
    -exportPath ../build/KeyPulse-export \
    -exportOptionsPlist ExportOptions.plist
```

### Method 3: Using Xcode Organizer

1. Open `KeyPulse/Package.swift` in Xcode
2. Select **Product** → **Archive**
3. Wait for archive to complete (Window → Organizer opens automatically)
4. Select the archive, click **Distribute App**
5. Choose **App Store Connect** → **Upload**
6. Follow prompts for signing and upload

---

## Uploading to App Store Connect

### Method A: Using Transporter (CLI)

**Prerequisites:**

- Install [Transporter](https://apps.apple.com/us/app/transporter/id1450874784) from Mac App Store
- Or use command-line `altool` (included with Xcode)

```bash
# Upload using altool
xcrun altool --upload-package \
    "build/KeyPulse-0.1.0-1/KeyPulse.app" \
    --type macos \
    --asc-public-id "YOUR_ASC_PUBLIC_ID" \
    --apple-id "1234567890" \
    --bundle-version "1" \
    --bundle-short-version-string "0.1.0"
```

**Find your ASC Public ID:**

- App Store Connect → **Users and Access** → **Keys** tab
- Look for "App Store Connect API" section

### Method B: Using notarytool (macOS 12+)

For direct notarization and stapling:

```bash
# Submit for notarization
xcrun notarytool submit \
    "build/KeyPulse-0.1.0-1/KeyPulse.app" \
    --apple-id "your@email.com" \
    --team-id "ABCD123456" \
    --wait

# Staple the notarization ticket
xcrun stapler staple "build/KeyPulse-0.1.0-1/KeyPulse.app"
```

### Method C: Using Xcode Organizer (GUI)

1. Open Xcode → **Window** → **Organizer**
2. Select the **Archives** tab
3. Find your KeyPulse archive
4. Click **Distribute App**
5. Choose **App Store Connect** → **Upload**
6. Select **Upload** (not "Export")
7. Review signing certificate and click **Upload**

### Method D: Using altool (Legacy but Reliable)

```bash
# Store password in keychain first
xcrun altool --store-password-in-keychain-item "AC_PASSWORD" \
    -u "your@email.com" \
    -p $(security find-internet-password -s idmsa.apple.com -w)

# Upload app
xcrun altool --upload-app \
    -f "build/KeyPulse.xcarchive" \
    -t macos \
    -u "your@email.com" \
    -p "@keychain:AC_PASSWORD"
```

---

## Adding Internal Testers

Once uploaded, the build will appear in App Store Connect within 5-15 minutes.

### Step 1: Enable TestFlight for the Build

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **KeyPulse**
2. Click **TestFlight** tab
3. Find your build under **Internal Testing** or **External Testing**
4. If required, provide **Export Compliance** information (KeyPulse does not use encryption)
5. Build status will change from "Processing" → "Testing"

### Step 2: Add Internal Testers

1. In TestFlight tab, click **Internal Testing** → **Internal Testers**
2. Click **+** next to **Testers**
3. Select users from your App Store Connect team
4. Click **Add**

**Note:** Internal testers must have App Store Connect accounts with Admin, App Manager, Developer, or Marketing roles.

### Step 3: Testers Install the App

Testers will receive an email invitation with:

- TestFlight redemption code
- Link to download TestFlight app (if not installed)

**Installation steps for testers:**

1. Install [TestFlight](https://apps.apple.com/us/app/testflight/id899247664) from Mac App Store
2. Click the invitation link or open TestFlight
3. Find KeyPulse in the app list
4. Click **Install**
5. Launch and test!

### Step 4: Collect Feedback

Testers can provide feedback via:

- **In-app screenshot**: Press Cmd+Shift+2 to capture and submit feedback
- **TestFlight app**: Click "Send Feedback" button
- **App Store Connect**: Feedback appears under TestFlight → Feedback

---

## Troubleshooting

### "Invalid Team ID" Error

**Problem**: Export fails with "Team ID not found"

**Solution**:

```bash
# Verify your team ID
security find-identity -v -p codesigning

# Update ExportOptions.plist with correct team ID
/usr/libexec/PlistBuddy -c "Set :teamID ABCD123456" KeyPulse/ExportOptions.plist
```

### "Provisioning Profile Not Found"

**Problem**: No matching provisioning profile for com.keypulse.app

**Solution**:

1. Log into [Developer Portal](https://developer.apple.com/account/resources/profiles/list)
2. Create **Mac App Store** provisioning profile for `com.keypulse.app`
3. Download and double-click to install
4. Or use automatic signing in ExportOptions.plist:
   ```xml
   <key>signingStyle</key>
   <string>automatic</string>
   ```

### "App already exists" Upload Error

**Problem**: Bundle ID already registered by another developer

**Solution**:

- KeyPulse uses `com.keypulse.app` — if you don't own this, change it in:
  - `KeyPulse/Package.swift` → `bundleIdentifier`
  - `KeyPulse/ExportOptions.plist` → provisioning profile key
  - `KeyPulse/Info.plist` → `CFBundleIdentifier`

### "Hardened Runtime" Validation Failure

**Problem**: App rejected for not using hardened runtime

**Solution**:

- Verify `ENABLE_HARDENED_RUNTIME=YES` is set in build command
- Check entitlements file is being used:
  ```bash
  codesign -d --entitlements - build/KeyPulse.app
  ```

### Build Upload Stuck at "Processing"

**Problem**: Build status stays "Processing" for hours

**Solution**:

- Normal processing time: 5-30 minutes
- Check email for any issues from App Store Connect
- Verify the build number is unique (can't re-upload same build number)
- Try downloading the build from TestFlight to verify it processed

### CGEventTap Not Working in TestFlight Build

**Problem**: Keyboard sounds don't work in TestFlight build

**Solution**:

- This is expected behavior! TestFlight apps run in a sandbox that may limit event taps
- The app needs to be granted **Accessibility** permission after first launch
- Guide testers to: System Settings → Privacy & Security → Accessibility → Enable KeyPulse
- This limitation only affects development/distribution builds; App Store version handles this correctly

---

## Verification Commands

```bash
# Verify code signature
codesign -dvv build/KeyPulse.app

# Check entitlements
codesign -d --entitlements - build/KeyPulse.app

# Verify notarization (after upload)
spctl -a -vv build/KeyPulse.app

# Show app information
mdls -name kMDItemVersion -name kMDItemCFBundleIdentifier build/KeyPulse.app
```

---

## Quick Reference

| Task               | Command                                                                           |
| ------------------ | --------------------------------------------------------------------------------- |
| Build release      | `./scripts/build-release.sh 0.1.0 1`                                              |
| Verify signature   | `codesign -dvv build/KeyPulse.app`                                                |
| Upload (altool)    | `xcrun altool --upload-app -f build/KeyPulse.xcarchive -t macos -u email -p pass` |
| Check notarization | `xcrun notarytool history --apple-id email`                                       |

---

## Resources

- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Overview](https://developer.apple.com/testflight/)
- [Distributing Mac Apps](https://developer.apple.com/documentation/xcode/distributing-your-app)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

---

**Last Updated**: 2026-05-04

For issues with this guide, please open a GitHub issue.
