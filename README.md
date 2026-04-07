# Smart Monadi

## Production Android Release Setup

### 1) Release keystore
- Keystore path is fixed at `android/app/smart_monadi_key.jks`.
- Release alias is fixed at `smart_monadi`.

### 2) Signing secrets (required)
Do not hardcode passwords in Gradle files.

Use one of these secure options:
1. Environment variables
	- `STORE_PASSWORD`
	- `KEY_PASSWORD`
	- `MAPS_API_KEY`
2. `android/local.properties` (recommended for local machines)
	- `STORE_PASSWORD=...`
	- `KEY_PASSWORD=...`
	- `MAPS_API_KEY=...`
3. `android/gradle.properties` (only if managed securely)

iOS map key is read from build setting `MAPS_API_KEY` (configured in `ios/Flutter/*.xcconfig` or Xcode Build Settings).

### 3) Firebase and package identity
- Android `applicationId` remains `com.example.smart_monadi`.
- `android/app/google-services.json` must be from the same Firebase project and package.
- Add the release SHA-1 of `smart_monadi_key.jks` to Firebase Android app settings.

To print SHA-1:

```powershell
keytool -list -v -keystore android/app/smart_monadi_key.jks -alias smart_monadi
```

### 4) Build and run in release mode

```powershell
flutter pub get
flutter run --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_API_KEY=YOUR_DIRECTIONS_API_KEY
```

Build APK:

```powershell
flutter build apk --release --dart-define=ETA_SERVICE_URL=http://YOUR_ETA_HOST:8081 --dart-define=DIRECTIONS_API_KEY=YOUR_DIRECTIONS_API_KEY
```

### 5) Release validation checklist
- Map tiles load on Android release build.
- No `REQUEST_DENIED` from Google APIs.
- Firebase Auth works.
- Firestore reads/writes work.
- Push notifications work.
- ETA works via `ETA_SERVICE_URL`.
- ETA fallback still works if ETA service is unavailable.

### 6) Firestore security rules

Project includes `firestore.rules` and references it from `firebase.json`.

Deploy indexes + rules:

```powershell
firebase deploy --only firestore:indexes,firestore:rules
```
