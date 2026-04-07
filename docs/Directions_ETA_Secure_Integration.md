# Smart Monadi Secure Directions + ETA Integration

This guide configures Google Directions securely across FastAPI and Flutter without hardcoding secrets in source code.

## 1) Backend (FastAPI)

Files:
- eta_service/main.py
- eta_service/requirements.txt
- eta_service/.env.example

### Environment setup

1. Copy eta_service/.env.example to eta_service/.env.
2. Set your server key:

GOOGLE_DIRECTIONS_API_KEY=YOUR_SERVER_SIDE_GOOGLE_DIRECTIONS_KEY
CORS_ORIGINS=*

3. Install dependencies and run:

python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8081

### Available endpoints

- GET /health
- POST /predict
- GET /directions?from_lat=...&from_lng=...&to_lat=...&to_lng=...

### Error handling behavior

- 503 if GOOGLE_DIRECTIONS_API_KEY is missing
- 504 on Google timeout
- 502 on upstream HTTP/network/invalid response errors

## 2) Flutter Runtime Config (flutter_dotenv)

Files:
- pubspec.yaml
- assets/env/.env
- assets/env/.env.example
- lib/app/config/runtime_env.dart
- lib/main.dart

### Environment values

Use assets/env/.env for local runtime values:

ETA_SERVICE_URL=http://10.0.2.2:8081
DIRECTIONS_API_KEY=
DIRECTIONS_BACKEND_URL=http://10.0.2.2:8081

Notes:
- Keep DIRECTIONS_API_KEY empty when backend proxy (/directions) is used.
- Do not commit real API keys to repository.

### Native map key (Google Maps SDK) without hardcoding

Android:
- `android/app/src/main/AndroidManifest.xml` now reads `com.google.android.geo.API_KEY` from `${MAPS_API_KEY}`.
- Set `MAPS_API_KEY` in one of:
  - environment variable
  - `android/local.properties`
  - `android/gradle.properties`

iOS:
- `ios/Runner/Info.plist` now reads `GMSApiKey` from `$(MAPS_API_KEY)`.
- Set `MAPS_API_KEY` in Xcode Build Settings or inside:
  - `ios/Flutter/Debug.xcconfig`
  - `ios/Flutter/Release.xcconfig`

Security note:
- `apiKey` values in `lib/firebase_options.dart` and `android/app/google-services.json` are Firebase client config identifiers, not backend secrets.

### Build Directions backend URL snippet (Flutter)

final backend = RuntimeEnv.directionsBackendUrl;
final uri = Uri.parse(
  '$backend/directions?from_lat=$fromLat&from_lng=$fromLng&to_lat=$toLat&to_lng=$toLng',
);

### Fetch directions JSON from backend snippet (Flutter)

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchDirections({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  final uri = Uri.parse(
    '${RuntimeEnv.directionsBackendUrl}/directions'
    '?from_lat=$fromLat&from_lng=$fromLng&to_lat=$toLat&to_lng=$toLng',
  );

  final response = await http.get(uri).timeout(const Duration(seconds: 8));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Directions request failed: ${response.statusCode} ${response.body}');
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Unexpected directions payload');
  }
  return decoded;
}

## 3) Google Cloud API Key Security

Use separate keys for mobile app and backend.

### Android app key restrictions

- Application restrictions: Android apps
- Allowed apps:
  - Package name: com.example.smart_monadi
  - SHA-1 fingerprint: release keystore SHA-1
- API restrictions: Restrict key
  - Directions API (Legacy) OR Routes API (if migrated)
  - Maps SDK for Android (if map tiles needed by this key)

### Backend key restrictions

- Application restrictions: IP addresses
  - Add server public IP(s)
- API restrictions: Restrict key
  - Directions API only

## 4) Ready-to-test examples

## 5) SMS reliability and duplicate prevention

- SMS enqueue now uses deterministic `idempotencyKey` values for:
  - approaching (4-5 min)
  - arrival zone
  - manual pickup trigger
- Firestore outbox writes are transaction-based and skip duplicate document IDs, reducing duplicate sends during retries/restarts.

### /predict request

POST http://127.0.0.1:8081/predict
Content-Type: application/json

{
  "busLat": 30.12345,
  "busLng": 31.56789,
  "passengerLat": 30.54321,
  "passengerLng": 31.98765,
  "speedMetersPerSecond": 10
}

### /predict sample response

{
  "etaMinutes": 89,
  "distanceMeters": 52991.37,
  "usedSpeedMetersPerSecond": 10
}

### /directions request

GET http://127.0.0.1:8081/directions?from_lat=30.0444&from_lng=31.2357&to_lat=30.0131&to_lng=31.2089

### /directions sample response shape

{
  "geocoded_waypoints": [...],
  "routes": [
    {
      "summary": "...",
      "legs": [...],
      "overview_polyline": {
        "points": "..."
      }
    }
  ],
  "status": "OK"
}
