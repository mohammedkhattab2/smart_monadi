# Smart Monadi

Smart Monadi is a smart school/university transportation app built with Flutter.

Core stack:
- Flutter (Android/iOS)
- Firebase (Auth, Firestore, Cloud Functions, FCM)
- Google Maps + Geolocation
- Python ETA service (FastAPI)
- Twilio SMS via Firebase Functions outbox pipeline

Audience-specific guides:
- Students quick run: `docs/Student_Quick_Start_AR.md`
- Project owner handoff: `docs/Client_Setup_Requirements_AR.md`
- Full command reference: `docs/Run_Commands_Guide_AR.md`

## 0) Quick Start (Clone -> Run)

Use this when someone clones the repo and wants to run fast.

```powershell
git clone <REPO_URL>
cd smart_monadi
flutter pub get
Copy-Item assets\env\.env.example assets\env\.env -Force
Copy-Item eta_service\.env.example eta_service\.env -Force
```

Edit `eta_service/.env` and set:
- `GOOGLE_DIRECTIONS_API_KEY=...`

Then run:

Terminal 1:

```powershell
./scripts/run_eta_service.ps1
```

Terminal 2:

```powershell
./scripts/run_flutter_emulator.ps1
```

Or for a real Android device:

```powershell
flutter devices
./scripts/run_flutter_device.ps1 -DeviceId <DEVICE_ID>
```

## 1) Prerequisites

- Flutter SDK installed and available in PATH
- Firebase CLI installed (`firebase --version`)
- Python 3.10+ installed
- Java 17 installed
- Node.js 18+ installed
- Android SDK / Xcode (depending on target platform)

## 2) Environment and Secrets

### Flutter runtime values

Use Dart defines during run/build:
- `ETA_SERVICE_URL`
- `DIRECTIONS_BACKEND_URL`
- `DIRECTIONS_API_KEY`

Example:

```powershell
flutter run --dart-define=ETA_SERVICE_URL=http://192.168.1.100:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://192.168.1.100:8081
```

`DIRECTIONS_API_KEY` is optional in the mobile client and should only be used when needed.
Preferred: keep Google Directions key on backend ETA service and use `DIRECTIONS_BACKEND_URL`.

### Android release signing and maps key

Keystore:
- path: `android/app/smart_monadi_key.jks`
- alias: `smart_monadi`

Provide locally (do not commit secrets):
1. Environment variables
- `STORE_PASSWORD`
- `KEY_PASSWORD`
- `MAPS_API_KEY`
2. Or `android/local.properties`
- `STORE_PASSWORD=...`
- `KEY_PASSWORD=...`
- `MAPS_API_KEY=...`

iOS map key is read from build setting `MAPS_API_KEY` (`ios/Flutter/*.xcconfig` or Xcode Build Settings).

### Firebase Functions secrets (Twilio)

Required in Firebase Functions runtime:
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_FROM_NUMBER`

## 3) First-time Setup

### Install app dependencies

```powershell
flutter pub get
```

### Install functions dependencies

```powershell
cd functions
npm ci
cd ..
```

### Install ETA service dependencies

```powershell
cd eta_service
pip install -r requirements.txt
cd ..
```

## 4) Clone-Ready Handoff (for project owner)

After cloning, create local env files from templates:

```powershell
Copy-Item assets\env\.env.example assets\env\.env -Force
Copy-Item eta_service\.env.example eta_service\.env -Force
```

Then edit `eta_service/.env` and set:
- `GOOGLE_DIRECTIONS_API_KEY=...`

Notes:
- `assets/env/.env`, `eta_service/.env`, and `android/local.properties` are local-only files and are not committed.
- If release signing is needed on another machine, share `android/app/smart_monadi_key.jks` and passwords through a secure channel (not Git).

## 5) Run in Development

### Option A: quick emulator start

```powershell
./scripts/start_dev_emulator.ps1
```

### Option B: manual terminals

Terminal 1 (ETA service):

```powershell
./scripts/run_eta_service.ps1
```

Terminal 2 (Flutter on emulator):

```powershell
./scripts/run_flutter_emulator.ps1
```

Terminal 2 (Flutter on device):

```powershell
./scripts/run_flutter_device.ps1 -EtaServiceUrl "http://192.168.1.100:8081"
```

## 6) Backend Deployment

### Firestore rules and indexes

```powershell
firebase deploy --only firestore:indexes,firestore:rules
```

### Cloud Functions

```powershell
cd functions
npm ci
cd ..
firebase deploy --only functions
```

## 7) Validation Commands

### Local code quality

```powershell
flutter analyze
flutter test
```

### Precheck and backend smoke

```powershell
./scripts/go_live_precheck.ps1
./scripts/go_live_backend_smoke.ps1
```

## 8) Android Release Build

Build and run release:

```powershell
flutter run --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://YOUR_ETA_HOST:8081
```

Build APK:

```powershell
flutter build apk --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://YOUR_ETA_HOST:8081
```

Build AAB for Google Play upload:

```powershell
flutter build appbundle --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://YOUR_ETA_HOST:8081
```

Output file (Play Console upload):
- `build/app/outputs/bundle/release/app-release.aab`

Print SHA-1 for Firebase Android app:

```powershell
keytool -list -v -keystore android/app/smart_monadi_key.jks -alias smart_monadi
```

Release signing quick check:
1. Ensure `android/app/smart_monadi_key.jks` exists locally.
2. Ensure `STORE_PASSWORD` and `KEY_PASSWORD` are available in env or `android/local.properties`.
3. Ensure `MAPS_API_KEY` is available in env or `android/local.properties`.

Suggested pre-upload checks:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://YOUR_ETA_HOST:8081
```

## 9) Known Production Requirements

- Real Twilio credentials must be configured in Functions for SMS to work.
- `ETA_SERVICE_URL` must point to reachable host from device/emulator.
- Google Maps/Directions APIs must be enabled with valid billing/project setup.
- iOS push requires APNs key/certificate configured in Firebase + Apple Developer portal.

## 10) Go-live Checklist

Use the detailed checklist in:
- `docs/Go_Live_Checklist_AR.md`

Use execution flow reference:
- `docs/Execution_Session_AR.md`

## 11) Troubleshooting

If `flutter run -d <DEVICE_ID> ...` exits with code 1:
1. Check device visibility:

```powershell
flutter devices
```

2. Force run on one specific device id:

```powershell
flutter run -d <DEVICE_ID> --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://YOUR_ETA_HOST:8081
```

3. Rebuild from clean state:

```powershell
flutter clean
flutter pub get
```

4. Validate backend is reachable:

```powershell
curl http://127.0.0.1:8081/health
```

5. For device runs, ensure phone and PC are on the same network and use LAN IP (not localhost).
