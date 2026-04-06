# Smart Monadi - Quick Start (60 ثانية)

هذا الملف لأسرع تشغيل ممكن على Windows PowerShell.

## 1) شغّل خدمة ETA (Terminal 1)

الأسرع باستخدام السكربت:

```powershell
./scripts/run_eta_service.ps1
```

أو يدويًا:

```powershell
cd "E:\flutter project\smart_monadi\eta_service"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8081
```

اترك هذا التيرمنال مفتوحًا.

## 2) شغّل التطبيق (Terminal 2)

الأسرع باستخدام السكربت:

```powershell
./scripts/run_flutter_emulator.ps1 -DirectionsApiKey "YOUR_GOOGLE_DIRECTIONS_API_KEY"
```

أو يدويًا:

```powershell
cd "E:\flutter project\smart_monadi"
flutter pub get
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081 --dart-define=DIRECTIONS_API_KEY=YOUR_GOOGLE_DIRECTIONS_API_KEY
```

## 3) لو على جهاز حقيقي بدل Emulator

استبدل `10.0.2.2` بـ IP جهازك على الشبكة المحلية:

```powershell
flutter run --dart-define=ETA_SERVICE_URL=http://192.168.1.100:8081 --dart-define=DIRECTIONS_API_KEY=YOUR_GOOGLE_DIRECTIONS_API_KEY
```

## 4) أهم ملاحظة

`--dart-define` لا يعمل وحده.
لازم دائمًا ييجي مع `flutter run`.

## 5) لو ظهر خطأ فهارس Firestore

```powershell
cd "E:\flutter project\smart_monadi"
firebase deploy --only firestore:indexes
```

ثم انتظر حتى الحالة تصبح `Ready` في Firebase Console.
