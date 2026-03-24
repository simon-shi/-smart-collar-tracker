# Smart Pet Collar – Flutter Mobile App

A cross-platform Flutter application for the Smart Pet Collar product (nRF52840 + nRF9160).  
The app communicates with the collar over BLE and with the cloud backend via REST API / WebSocket.

---

## Table of Contents

1. [Features](#features)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Getting Started](#getting-started)
5. [Environment Configuration](#environment-configuration)
6. [BLE Protocol](#ble-protocol)
7. [Running Tests](#running-tests)
8. [Platform Setup](#platform-setup)
9. [Building for Production](#building-for-production)
10. [Localization](#localization)

---

## Features

| Feature | Description |
|---|---|
| **Real-time GPS Map** | Live pet marker on Google Maps with smooth animation, satellite/terrain modes, map-follow option |
| **Geofence Management** | Create circle or polygon geofences, real-time breach alerts, entry/exit history |
| **Activity Dashboard** | Daily steps, calorie burn, activity rings, weekly/monthly trend charts |
| **Sleep Analysis** | Sleep stage breakdown (deep / light / REM / awake) with visual timeline |
| **Health Reports** | Weekly health reports, anomaly alerts (seizures, excessive scratching, limping) |
| **Find Pet Mode** | BLE RSSI distance estimation, directional compass, trigger LED/buzzer on collar |
| **OTA Firmware Update** | Nordic DFU over BLE for nRF52840 and nRF9160, progress bar |
| **Multi-pet Support** | Add multiple pets with individual collar pairings |
| **Offline Cache** | Hive local database for location and activity data when offline |
| **GDPR / CCPA Compliance** | Consent screen, data export (JSON/CSV), account deletion, "Do Not Sell" option |
| **Authentication** | Email/password, Google OAuth 2.0, Apple Sign-In, biometric unlock |

---

## Tech Stack

| Layer | Package |
|---|---|
| Framework | Flutter 3.x (Dart 3.x) |
| State Management | flutter_riverpod 2.x |
| Navigation | go_router |
| BLE | flutter_blue_plus |
| Maps | google_maps_flutter |
| Charts | fl_chart |
| Local DB | hive / hive_flutter |
| HTTP | dio |
| Push Notifications | firebase_messaging + flutter_local_notifications |
| OTA / DFU | nordic_dfu |
| Secure Storage | flutter_secure_storage |
| Internationalization | flutter_localizations (EN, ZH) |

---

## Project Structure

```
app/
├── lib/
│   ├── main.dart                  # Entry point, ProviderScope, routing
│   ├── app.dart                   # MaterialApp with theme and router
│   ├── config/                    # Environment, API endpoints, BLE UUIDs, theme
│   ├── models/                    # Immutable data models (Equatable)
│   ├── providers/                 # Riverpod providers (state management)
│   ├── services/
│   │   ├── api/                   # Dio HTTP client + per-domain API services
│   │   └── ble/                   # BLE scan/connect, protocol, DFU, parser
│   ├── screens/                   # Feature screens + sub-widgets
│   ├── widgets/                   # Shared widgets and dialogs
│   ├── utils/                     # Constants, extensions, formatters, geo math
│   └── router/                    # GoRouter configuration
├── test/
│   ├── unit/                      # Dart unit tests
│   └── widget/                    # Flutter widget tests
├── android/
└── ios/
```

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0 — [Install Flutter](https://flutter.dev/docs/get-started/install)
- Dart SDK ≥ 3.0.0 (bundled with Flutter)
- Android Studio or Xcode (for running on physical devices / emulators)
- A Google Maps API key (for map features)
- Firebase project (for push notifications)

### Clone & Install

```bash
git clone https://github.com/your-org/smart-collar-tracker.git
cd smart-collar-tracker/app
flutter pub get
```

---

## Environment Configuration

Edit `lib/config/app_config.dart` to switch between environments:

```dart
AppEnvironment.development   // local backend
AppEnvironment.staging       // staging backend
AppEnvironment.production    // production backend
```

Create a `.env` file (not committed) or pass `--dart-define` flags:

```bash
flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_BASE_URL=wss://api.example.com
```

### Google Maps Setup

**Android** – add your API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

**iOS** – add the key in `ios/Runner/AppDelegate.swift`:

```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

---

## BLE Protocol

The collar advertises with the name prefix **`PetCollar-`**.

| GATT Service / Characteristic | UUID | Properties |
|---|---|---|
| Custom Service | `12345678-1234-5678-1234-56789abcdef0` | — |
| Location | `...def1` | Notify |
| Activity | `...def2` | Notify |
| Geofence Alert | `...def3` | Notify |
| Device Control | `...def4` | Write |
| Device Status | `...def5` | Read |
| Offline Sync | `...def6` | Notify |

Full UUIDs are defined in `lib/config/ble_config.dart`.

---

## Running Tests

```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# All tests
flutter test
```

---

## Platform Setup

### Android Permissions

The following permissions are declared in `android/app/src/main/AndroidManifest.xml`:

- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` (API 31+)
- `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- `INTERNET`, `FOREGROUND_SERVICE`

### iOS Permissions

The following keys are declared in `ios/Runner/Info.plist`:

| Key | Purpose |
|---|---|
| `NSBluetoothAlwaysUsageDescription` | BLE collar communication |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | GPS tracking |
| `NSLocationWhenInUseUsageDescription` | Foreground location |
| `NSCameraUsageDescription` | Pet profile photo |
| `NSPhotoLibraryUsageDescription` | Select pet photo |

---

## Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## Localization

Supported locales: **English (en)** and **Chinese Simplified (zh)**.

ARB files live in `lib/l10n/`. Regenerate after editing:

```bash
flutter gen-l10n
```

---

## License

MIT License – see [LICENSE](../LICENSE) for details.
