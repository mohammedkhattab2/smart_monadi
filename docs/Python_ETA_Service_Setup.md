# Python ETA Service Setup

This document explains how to run and connect the optional Python ETA service.

## What It Does

- Exposes `/predict` endpoint that calculates ETA in minutes from:
  - bus coordinates
  - passenger coordinates
  - current speed
- Flutter automation calls this endpoint when `ETA_SERVICE_URL` is provided.
- If unavailable, app falls back to local ETA calculation automatically.

## Service Files

- `eta_service/main.py`
- `eta_service/requirements.txt`

## Local Run

From project root:

```bash
cd eta_service
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8081
```

Health check:

```bash
curl http://localhost:8081/health
```

Predict sample:

```bash
curl -X POST http://localhost:8081/predict \
  -H "Content-Type: application/json" \
  -d "{\"busLat\":30.0444,\"busLng\":31.2357,\"passengerLat\":30.05,\"passengerLng\":31.24,\"speedMetersPerSecond\":8.33}"
```

## Connect Flutter

Run Flutter with the endpoint:

```bash
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081
```

To also enable real driving route polylines in driver map:

```bash
flutter run \
  --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081 \
  --dart-define=DIRECTIONS_API_KEY=YOUR_GOOGLE_DIRECTIONS_API_KEY
```

Notes:
- Android emulator uses `10.0.2.2` for host machine localhost.
- For physical device, replace with machine LAN IP.
- Ensure Google Directions API is enabled for your Google Cloud project.

## Production Suggestion

- Deploy this service to Cloud Run.
- Use HTTPS URL as `ETA_SERVICE_URL`.
- Keep timeout low (already handled client-side) and monitor errors.
