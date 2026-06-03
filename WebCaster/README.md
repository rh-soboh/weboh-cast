# WebCaster

A full-featured web browser for iOS that detects video content on webpages and lets you cast/stream it to external devices (DLNA TVs, AirPlay, Chromecast).

## Features

- **Built-in Browser** — WKWebView with tabs, address bar, back/forward, bookmarks, history
- **Aggressive Ad Blocking** — WKContentRuleList-based blocking of ads, trackers, popups, WebRTC leaks
- **Video Detection Engine** — JavaScript injection with MutationObserver, XHR/fetch interception, MediaSource hooking
- **Casting** — DLNA/UPnP via custom SSDP, AirPlay (native), Chromecast (stub, add SDK later)
- **Built-in Player** — AVPlayer with custom controls, HLS/MP4 support, PiP, adjustable speed, resume playback
- **Queue & Playlists** — Add detected videos to a queue, save playlists locally
- **Dark Theme** — Orange accent (#FF6D00), dark-first UI

## Requirements

- **macOS** with Xcode 15+ installed
- **iOS 16.0+** device (or simulator)
- **XcodeGen** (to generate the .xcodeproj from project.yml)
- Apple Developer account (free works for sideloading)

## Build Instructions

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate Xcode Project

```bash
cd WebCaster
xcodegen generate
```

This reads `project.yml` and creates `WebCaster.xcodeproj`.

### 3. Open in Xcode

```bash
open WebCaster.xcodeproj
```

### 4. Configure Signing

1. Select the **WebCaster** target
2. Go to **Signing & Capabilities**
3. Select your **Team** (personal or organization)
4. Change **Bundle Identifier** if needed (e.g., `com.yourname.webcaster`)

### 5. Build & Run

- Select your connected iPhone or a simulator
- Press **Cmd+R** to build and run

### 6. Export IPA (for Sideloading)

#### Option A: Archive & Export

1. Select **Any iOS Device (arm64)** as the build target
2. **Product → Archive**
3. Once archived, click **Distribute App**
4. Choose **Development** (or **Ad Hoc** if you have a paid account)
5. Follow the prompts → Export
6. Find the `.ipa` file in the export folder

#### Option B: Build & Extract IPA Manually

```bash
# Build for device
xcodebuild -project WebCaster.xcodeproj \
  -scheme WebCaster \
  -configuration Release \
  -sdk iphoneos \
  -archivePath build/WebCaster.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath build/WebCaster.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/ipa
```

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

## Build from Linux/Windows (No Mac Required)

This repo includes a GitHub Actions workflow that builds the IPA on Apple's macOS runners.

### Setup

1. Push this repo to GitHub
2. Go to **Actions** tab → **Build WebCaster IPA**
3. Click **Run workflow** (or it triggers automatically on push to `main`)
4. When complete, download the **WebCaster-IPA** artifact from the workflow run
5. Sideload the IPA to your iPhone (see below)

That's it — no Mac needed.

## Sideloading

### Using Sideloadly (Windows/Mac/Linux)

1. Download [Sideloadly](https://sideloadly.io/) — available for Windows, macOS, and Linux
2. Connect your iPhone via USB
3. Open Sideloadly, drag in the `.ipa` file
4. Enter your Apple ID
5. Click **Start**
6. On your iPhone: **Settings → General → VPN & Device Management** → Trust the certificate

### Using AltStore

1. Install [AltServer](https://altstore.io/) on your Mac or Windows PC
2. Install AltStore on your iPhone via AltServer
3. In AltStore on iPhone: **My Apps → + → Select the .ipa**
4. The app will be signed and installed

> **Note:** Free Apple accounts require re-signing every 7 days. AltStore can auto-refresh if AltServer is running on the same network.

## Project Structure

```
WebCaster/
├── App/
│   └── WebCasterApp.swift           # App entry point
├── Views/
│   ├── ContentView.swift             # Tab navigation
│   ├── Browser/
│   │   ├── BrowserView.swift         # Main browser with video overlay
│   │   ├── WebView.swift             # WKWebView wrapper (UIViewRepresentable)
│   │   ├── AddressBar.swift          # URL bar with nav controls
│   │   └── TabsView.swift            # Tab management grid
│   ├── VideoDetectionOverlay.swift   # Detected videos list
│   ├── DeviceDiscoveryView.swift     # Cast device selection
│   ├── PlayerView.swift              # Full-screen video player
│   ├── HistoryView.swift             # Browsing history
│   ├── BookmarksView.swift           # Saved bookmarks
│   ├── QueueView.swift               # Video queue & playlists
│   └── SettingsView.swift            # App settings
├── ViewModels/
│   ├── BrowserViewModel.swift        # Browser state management
│   ├── VideoDetectorViewModel.swift  # Video detection state
│   ├── PlayerViewModel.swift         # AVPlayer control
│   └── CastingViewModel.swift        # Device casting state
├── Models/
│   ├── DetectedVideo.swift           # Video data model
│   ├── CastDevice.swift              # Cast device model
│   ├── Bookmark.swift                # Bookmark model
│   ├── HistoryEntry.swift            # History entry model
│   ├── BrowserTab.swift              # Tab model
│   ├── PlaylistItem.swift            # Queue/playlist models
│   └── AppSettings.swift             # App configuration
├── Services/
│   ├── AdBlocker/
│   │   ├── AdBlockService.swift      # WKContentRuleList + JS blocking
│   │   └── blocklist.json            # Ad domain blocklist
│   ├── VideoDetector/
│   │   ├── VideoDetectionService.swift # Video URL extraction
│   │   └── detector.js               # Injected JS detector
│   ├── Casting/
│   │   ├── DLNAService.swift         # SSDP discovery + UPnP SOAP
│   │   └── CastingManager.swift      # Unified casting coordinator
│   └── Storage/
│       └── PersistenceController.swift # JSON-based local storage
├── Extensions/
│   └── Color+Theme.swift             # Theme colors
├── Resources/
│   └── Assets.xcassets               # App icon, accent color
└── Info.plist                        # App configuration
```

## Casting Protocols

| Protocol | Status | How |
|----------|--------|-----|
| **AirPlay** | Native | AVRoutePickerView — works out of the box |
| **DLNA/UPnP** | Full | Custom SSDP discovery + UPnP SOAP (SetAVTransportURI, Play, Pause, Stop, Seek) |
| **Chromecast** | Basic | Bonjour discovery + DIAL REST API. For full media control, add google-cast-sdk |

### Upgrading Chromecast to Full SDK

The built-in `ChromecastService` discovers devices via Bonjour and uses DIAL for basic launch.
For full queue/seek/volume control, add the official SDK:

```ruby
# Podfile
pod 'google-cast-sdk', '~> 4.8'
```

Then initialize `GCKCastContext` in `WebCasterApp.swift` and extend `ChromecastService.swift`
to use `GCKSessionManager` and `GCKRemoteMediaClient`.

## Architecture

- **MVVM** pattern with `@StateObject` / `@ObservedObject`
- **Services** layer for business logic (ad blocking, video detection, casting, subtitles, storage)
- **JSON-based persistence** (no CoreData dependency, iOS 16 compatible)
- **NotificationCenter** for cross-component WebView communication
- **Combine** for reactive bindings
- **Ad blocklist** auto-updates from remote every 24h, with manual refresh in Settings

## License

MIT
