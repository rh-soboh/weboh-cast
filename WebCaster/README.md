# WebCaster — React Native (Expo)

Browse the web, detect videos, and cast them to your TV. Built with Expo SDK 53, React Native, and TypeScript.

## Features

- **In-app browser** with address bar, tabs, history, and bookmarks
- **Ad & tracker blocking** — JS injection + URL-level blocking of 35+ ad networks
- **Video detection** — intercepts `<video>`, XHR, fetch, MediaSource to find video URLs
- **Video player** — expo-av with custom controls, playback speed, subtitles (SRT/VTT), PiP
- **Casting** — DLNA/UPnP (SOAP), Chromecast (via react-native-google-cast), AirPlay
- **Queue & playlists** — reorderable queue, save/load named playlists
- **Dark theme** with orange accent (#FF6D00)

## Quick Start

```bash
cd WebCaster
npm install
npx expo start
```

## Building the IPA (no Mac required)

WebCaster uses **EAS Build** to produce installable `.ipa` and `.apk` files in the cloud.

### 1. Install EAS CLI

```bash
npm install -g eas-cli
```

### 2. Log in to Expo

```bash
eas login
```

### 3. Build for iOS (sideloading)

```bash
cd WebCaster
eas build --platform ios --profile sideload
```

This creates an `.ipa` you can install with **AltStore** or **Sideloadly**.

### 4. Build for Android

```bash
eas build --platform android --profile production
```

This creates an `.apk` you can install directly.

### Free Tier

EAS Build free tier includes 30 builds/month — more than enough for development.

## Project Structure

```
WebCaster/
  App.tsx                    — Entry point + navigation
  src/
    screens/                 — All app screens
    components/              — Reusable UI components
    services/
      adblock/               — Ad blocking engine
      videoDetector/          — Video detection JS + service
      casting/                — DLNA + Chromecast managers
      subtitles/              — SRT/VTT parser
      storage/                — AsyncStorage persistence
    models/types.ts           — TypeScript interfaces
    theme/                    — Colors + navigation theme
    hooks/                    — React hooks
```

## Sideloading the IPA

1. Download the `.ipa` from EAS Build dashboard or GitHub Actions artifacts
2. Install **Sideloadly** (https://sideloadly.io) or **AltStore** (https://altstore.io)
3. Connect your iPhone via USB
4. Drag the `.ipa` into Sideloadly, enter your Apple ID, click Start
5. On your iPhone: Settings → General → VPN & Device Management → Trust the certificate
