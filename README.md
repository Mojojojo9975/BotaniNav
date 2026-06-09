# BotanicNav

Flutter frontend for the BotanicNav platform — guides botanical garden visitors to plants via outdoor GPS navigation and indoor BLE + camera-based navigation.

---

## Features

### Outdoor Navigation
- Google Maps with a live walking route drawn from the user's current position to the target plant
- Turn-by-turn step instructions displayed in a banner at the top of the map
- Distance and estimated walking time shown in a bottom sheet
- Map auto-centres as the user moves
- Dark botanical theme applied to the map tiles

### Indoor Navigation (Greenhouse)
- Live camera feed as a fullscreen background
- Directional arrow overlaid on the camera, rotating in real time to point toward the target plant
- Hot/cold gauge on the right edge — animates from blue (cold/far) to red (hot/close) as the user approaches
- Human-readable hints from the backend (e.g. "Getting warmer", "Getting colder")
- QR code scanner for anchoring position to a known section marker in the greenhouse

### Plant Catalogue
- Scrollable list of all garden plants, grouped into Outdoor and Greenhouse sections
- Displays common name, scientific name, and section label
- Tap any plant to begin navigation immediately

### Arrival Screen
- Shown automatically when the user reaches the destination
- Displays plant name, scientific name, section, and curator description
- Done button returns to the plant catalogue

### Deep Link Entry
The app is designed to be launched from a partner app via deep link, jumping directly into navigation for a specific plant without going through the catalogue:
```
botanicnav://navigate?plantId=plant_123&apiKey=abc123
```

---

## Technical Requirements

### Flutter & Dart
- Flutter `>=3.29.0`
- Dart SDK `>=3.7.0 <4.0.0`

### Dependencies

| Package | Version | Purpose |
|---|---|---|
| `google_maps_flutter` | `^2.9.0` | Outdoor map and polyline rendering |
| `geolocator` | `^13.0.0` | GPS position stream |
| `flutter_blue_plus` | `^1.35.0` | BLE beacon RSSI scanning (indoor) |
| `sensors_plus` | `^7.0.0` | Magnetometer → compass heading |
| `camera` | `^0.11.0` | Live camera feed |
| `mobile_scanner` | `^6.0.0` | QR code scanning |
| `web_socket_channel` | `^3.0.0` | Real-time navigation state over WebSocket |
| `http` | `^1.4.0` | REST calls to FastAPI backend |
| `go_router` | `^16.0.0` | In-app routing and deep link handling |
| `flutter_riverpod` | `^3.0.0` | State management |
| `riverpod_annotation` | `^3.0.0` | Riverpod code generation annotations |
| `flutter_dotenv` | `^5.2.0` | `.env` file loading |
| `equatable` | `^2.0.7` | Value equality for models |

### Environment Configuration

Copy `.env` to your project root and fill in real values before running:

```
API_BASE_URL=http://your-backend-host:8000
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
BEACON_UUID_GREENHOUSE_A=00000000-0000-0000-0000-000000000001
BEACON_UUID_GREENHOUSE_B=00000000-0000-0000-0000-000000000002
```

The `.env` file is bundled as a Flutter asset at build time via `flutter_dotenv`. Do **not** commit it with real secrets.

### Google Maps API Key

The Maps SDK requires the key in two additional places:

**Android** — `android/app/src/main/AndroidManifest.xml` inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_KEY_HERE"/>
```

**iOS** — `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_KEY_HERE")
```

### Deep Link Registration

**Android** — add to `android/app/src/main/AndroidManifest.xml` inside the `<activity>` block:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="botanicnav" android:host="navigate"/>
</intent-filter>
```

**iOS** — add to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>botanicnav</string>
        </array>
    </dict>
</array>
```

### Required Permissions

**Android** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** (`Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to navigate you to plants in the garden.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to detect your position inside the greenhouse.</string>
<key>NSCameraUsageDescription</key>
<string>Used to display the indoor navigation overlay.</string>
```

### Backend API Contract

All requests require the header `X-API-Key: <key>`.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/v1/plants` | Full plant catalogue |
| `POST` | `/api/v1/navigation/route` | Outdoor walking route (polyline + steps) |
| `WS` | `/api/v1/navigation/ws/{session_id}` | Real-time bearing, distance, hot/cold score |
| `POST` | `/api/v1/scan` | QR section anchor *(pending backend phase 3)* |

### Windows Development

Developer Mode must be enabled for Flutter's symlink support:
```cmd
start ms-settings:developers
```

### Running the App

```cmd
flutter pub get
flutter run
```

To target a specific device:
```cmd
flutter devices
flutter run -d <device_id>
```

For physical devices, set `API_BASE_URL` in `.env` to your machine's local network IP (e.g. `http://192.168.1.x:8000`) rather than `localhost`.

---

## Project Structure

```
lib/
├── main.dart                        # Entry point, loads .env, ProviderScope
├── app.dart                         # MaterialApp.router + theme
├── config/
│   └── env.dart                     # Typed access to .env values
├── models/
│   ├── plant.dart                   # Plant data class + fromJson
│   └── navigation_state.dart        # NavigationState, OutdoorRoute, RouteStep
├── services/
│   ├── api_service.dart             # HTTP wrapper (GET plants, POST route, POST scan)
│   ├── websocket_service.dart       # WS client + MockWebSocketService
│   ├── ble_service.dart             # BLE scanner + MockBleService
│   └── compass_service.dart         # Magnetometer → heading stream
├── providers/
│   ├── plant_provider.dart          # Plant list, apiKey, apiService providers
│   └── navigation_provider.dart     # Route, WS state, compass, BLE, arrow angle
├── router/
│   └── app_router.dart              # go_router config + deep link handling
├── screens/
│   ├── plant_list_screen.dart       # Catalogue grouped by indoor/outdoor
│   ├── outdoor_navigation_screen.dart  # Google Maps + route overlay
│   ├── indoor_navigation_screen.dart   # Camera + arrow + gauge (mock data)
│   └── arrival_screen.dart          # Arrival confirmation + plant details
└── widgets/
    ├── arrow_painter.dart           # CustomPainter rotating directional arrow
    ├── hot_cold_gauge.dart          # Animated temperature gauge (blue → red)
    └── camera_overlay.dart          # Camera + arrow + gauge compositor
```

---

## Pending (Backend Phase 3 / Hardware)

The following features are scaffolded with mock data and will activate once the backend and hardware are ready:

- **BLE trilateration** — real beacon UUIDs must be provisioned and set in `.env`; swap `MockBleService` → `BleService` in `navigation_provider.dart`
- **Indoor WebSocket positioning** — swap `MockWebSocketService` → `WebSocketService` in `navigation_provider.dart`
- **QR scan endpoint** — `POST /api/v1/scan` — remove the `UnimplementedError` in `api_service.dart` and uncomment the real call

All pending items are marked with `// TODO [Backend Phase 3 / Hardware]` throughout the codebase.
