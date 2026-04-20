# Auto-Update Feature Implementation Plan

## Overview
This document outlines the implementation of an auto-update feature for the Cheaptroller Game Controller app. The app will check GitHub releases for new versions and allow users to download and install updates directly from the app.

## Architecture

### Components
1. **Update Service** - Handles version checking, APK downloading, and installation
2. **Update Dialog** - UI component to notify users of available updates
3. **Settings Integration** - Optional manual check for updates in settings

### Dependencies Required
```yaml
dependencies:
  package_info_plus: ^8.0.3
  open_file: ^3.5.10
  http: ^1.3.0
  path_provider: ^2.1.5
```

## Implementation Steps

### Step 1: Add Dependencies
Add required packages to `pubspec.yaml`:
- `package_info_plus` - Get current app version
- `open_file` - Open APK installer
- `http` - Download APK files
- `path_provider` - Access temporary storage

### Step 2: Create Update Service
Create `lib/Services/update_service.dart` with the following functionality:
- `checkForUpdate()` - Fetch latest release from GitHub API
- `getCurrentVersion()` - Get installed app version
- `downloadAndInstall()` - Download APK and trigger installation

GitHub API endpoint:
```
GET https://api.github.com/repos/blqnk3d/Cheaptroller/releases/latest
```

Response parsing:
- `tag_name` - Version string (e.g., "v1.0.2")
- `assets[].browser_download_url` - APK download URL

### Step 3: Configure Android Permissions
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

For Android 8+ (API 26+), also add:
```xml
<uses-permission android:name="android.permission.REQUEST_DELETE_PACKAGES"/>
```

### Step 4: Create Update Dialog
Create `lib/Elements/update_dialog.dart`:
- Display new version number
- Show release notes (optional)
- "Update Now" and "Later" buttons
- Download progress indicator

### Step 5: Integrate Update Check
**Option A: On App Startup**
Add check in `main.dart` or `startpage.dart`:
```dart
void checkForUpdates() async {
  final updateService = UpdateService();
  final hasUpdate = await updateService.checkForUpdate();
  if (hasUpdate && context.mounted) {
    showUpdateDialog(context);
  }
}
```

**Option B: Manual Check in Settings**
Add update check button in settings page.

### Step 6: Release APK Naming Convention
Ensure release APKs follow consistent naming:
- Format: `app-release-v{version}.apk` (e.g., `app-release-v1.0.2.apk`)
- This makes it easy to parse the download URL

## Workflow

```
App Launch
    │
    ▼
Check GitHub API for latest release
    │
    ├─── Version same/older ──► No action, proceed to app
    │
    └─── Version newer ──► Show update dialog
                                │
                                ├─── "Later" ──► Dismiss, proceed to app
                                │
                                └─── "Update Now"
                                          │
                                          ▼
                                    Download APK
                                          │
                                          ▼
                                    Show progress
                                          │
                                          ▼
                                    Open installer
                                          │
                                          ▼
                                    User installs
```

## Error Handling
- **No internet**: Silently skip update check
- **API error**: Log error, continue without update
- **Download failed**: Show retry dialog
- **Installation cancelled**: Return to app

## Testing
1. Test with version lower than current (should not show dialog)
2. Test with version higher than current (should show dialog)
3. Test download progress display
4. Test installation flow
5. Test offline behavior

## Private Repository Considerations
If the repo is **private**:
- Use GitHub API with authentication header
- Embed token in app (not recommended for production) OR
- Use a proxy server to serve the APK

If the repo is **public**:
- No authentication needed for GitHub API
- Direct download links work

## Future Improvements
- Background update checking with local notifications
- Release notes display
- Auto-update option in settings (install on next restart)
- Differential updates (if APK size becomes large)
