# AsthmaGuard AI — Flutter App

A Flutter port of the AsthmaGuard AI web dashboard with:
- 🔐 Login & Register screens
- 📊 Live AQI gauge (canvas-accurate port)
- 🌬️ 6 air quality sensor cards (PM2.5, PM10, NO2, SO2, CO, O3)
- 💗 Vitals panel (SpO2, Heart Rate)
- 🚨 Emergency modal for hazardous AQI
- ⚠️ Moderate-risk sticky banner
- Auto-refresh every 2 seconds

---

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── services/
│   └── api_service.dart       # Flask API calls
├── theme/
│   └── app_theme.dart         # Colors & text styles
├── screens/
│   ├── login_screen.dart      # Login + Register
│   └── dashboard_screen.dart  # Main dashboard
└── widgets/
    ├── aqi_gauge.dart         # Custom arc gauge painter
    └── sensor_card.dart       # Individual sensor widget
```

---

## Setup

### 1. Configure your Flask server URL

Open `lib/services/api_service.dart` and update:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5000';
```

For Android emulator connecting to local Flask: use `http://10.0.2.2:5000`  
For iOS simulator: use `http://localhost:5000`  
For physical devices: use your machine's local IP, e.g. `http://192.168.1.x:5000`

### 2. Add fonts

**Option A (recommended): Use `google_fonts` package**

Replace font declarations in `pubspec.yaml` and add:
```yaml
dependencies:
  google_fonts: ^6.1.0
```

Then in `app_theme.dart`, import and use:
```dart
import 'package:google_fonts/google_fonts.dart';
// GoogleFonts.orbitron(), GoogleFonts.rajdhani()
```

**Option B: Download fonts manually**

1. Download from Google Fonts: [Orbitron](https://fonts.google.com/specimen/Orbitron) & [Rajdhani](https://fonts.google.com/specimen/Rajdhani)
2. Place `.ttf` files in `assets/fonts/`
3. Create the `assets/fonts/` directory: `mkdir -p assets/fonts`

### 3. Add HTTP permissions

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
For local HTTP (non-HTTPS), also add inside `<application>`:
```xml
android:usesCleartextTraffic="true"
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 4. Install & run

```bash
flutter pub get
flutter run
```

---

## Flask API endpoints expected

| Endpoint | Method | Response |
|----------|--------|----------|
| `/login` | POST `{username, password}` | `{success: bool, message: str}` |
| `/register` | POST `{name, username, password}` | `{success: bool, message: str}` |
| `/get_status` | GET | `{aqi, risk, timestamp, pm25, pm10, no2, so2, co, o3, temp, humidity, spo2, heart_rate}` |
