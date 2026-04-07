# Smart Monadi - دليل أوامر التشغيل (Windows PowerShell)

هذا الملف يجمع أوامر التشغيل الفعلية للمشروع بالكامل: Flutter + Firebase + Functions + Python ETA.

إذا تريد أسرع تشغيل مباشر، ابدأ من:

- `docs/Quick_Start_60s_AR.md`

ولقائمة التسليم النهائي قبل العرض/الإطلاق:

- `docs/Go_Live_Checklist_AR.md`

ولجلسة تنفيذ عملية خطوة بخطوة:

- `docs/Execution_Session_AR.md`

## 1) المتطلبات الأساسية

- Flutter SDK مثبت
- Android Studio أو VS Code + Android emulator
- Python 3.10+ مثبت
- Firebase CLI مثبت ومسجل دخول
- مشروع Firebase مربوط بالمشروع الحالي

تحقق سريع:

```powershell
flutter --version
python --version
firebase --version
```

## 2) تشغيل المشروع لأول مرة

من جذر المشروع:

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
```

تحليل المشروع:

```powershell
flutter analyze
```

## 3) تشغيل Python ETA Service

من جذر المشروع:

```powershell
cd "D:\flutter project\smart_monadi\eta_service"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8081
```

اختبار صحة الخدمة (في Terminal جديد):

```powershell
curl http://localhost:8081/health -UseBasicParsing
```

اختبار endpoint التنبؤ:

```powershell
curl -Method Post http://localhost:8081/predict -UseBasicParsing -ContentType "application/json" -Body '{"busLat":30.0444,"busLng":31.2357,"passengerLat":30.05,"passengerLng":31.24,"speedMetersPerSecond":8.33}'
```

## 4) تشغيل Flutter مع ETA + Directions

من جذر المشروع:

### 4.1 Android Emulator

الأوامر الآن تعمل بدون تمرير key يدويًا (تم ضبط Defaults في السكربتات):

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_flutter_emulator.ps1
```

أو يدويًا:

```powershell
cd "D:\flutter project\smart_monadi"
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081
```

### 4.2 جهاز Android حقيقي

استبدل IP بعنوان جهاز الكمبيوتر على نفس الشبكة:

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_flutter_device.ps1
```

ملاحظة: `10.0.2.2` يعمل فقط داخل Android emulator.
ملاحظة: `run_flutter_device.ps1` يكتشف LAN IP تلقائيًا ويضبط `ETA_SERVICE_URL`.

## 5) أوامر Firebase (Firestore + Functions)

من جذر المشروع:

### 5.1 نشر الفهارس + القواعد (Indexes + Rules)

```powershell
cd "D:\flutter project\smart_monadi"
firebase deploy --only firestore:indexes,firestore:rules
```

### 5.2 تثبيت dependencies للـ Functions

```powershell
cd "D:\flutter project\smart_monadi\functions"
npm install
```

### 5.3 ضبط أسرار Twilio

```powershell
cd "D:\flutter project\smart_monadi\functions"
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM_NUMBER
```

### 5.4 نشر Cloud Functions

```powershell
cd "D:\flutter project\smart_monadi\functions"
firebase deploy --only functions
```

## 6) تشغيل الاختبارات الأساسية

من جذر المشروع:

```powershell
cd "D:\flutter project\smart_monadi"
flutter test
```

تشغيل اختبارات السائق فقط:

```powershell
flutter test test\features\driver\domain\usecases\driver_automation_usecases_test.dart
flutter test test\features\driver\presentation\viewmodels\driver_live_view_model_test.dart
```

## 6.1 Backend Smoke Check (ETA + Firebase)

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/go_live_backend_smoke.ps1
```

## 7) أوامر مفيدة أثناء التطوير

### 7.1 تنظيف وإعادة تثبيت dependencies

```powershell
cd "D:\flutter project\smart_monadi"
flutter clean
flutter pub get
```

### 7.2 تشغيل التطبيق على جهاز محدد

```powershell
flutter devices
flutter run -d <DEVICE_ID> --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081
```

## 8) أخطاء شائعة وحلها

### 8.1 خطأ: The query requires an index

الحل:

```powershell
cd "D:\flutter project\smart_monadi"
firebase deploy --only firestore:indexes,firestore:rules
```

ثم انتظر حتى يصبح index في Firebase Console حالته `Ready`.

### 8.2 كتبت `--dart-define=...` وحدها وفشلت

السبب: `--dart-define` ليست أمر مستقل.
لازم تكون مع أمر تشغيل مثل:

```powershell
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081
```

### 8.3 الـ ETA service يعمل لكن التطبيق لا يصل له

- تأكد أن الخدمة تعمل على نفس المنفذ 8081.
- على Emulator استخدم `10.0.2.2` بدل `localhost`.
- على جهاز حقيقي استخدم LAN IP الحقيقي.

### 8.4 Push Notifications لا تظهر

- تأكد من تفعيل Cloud Messaging في Firebase.
- Android 13+: تأكد إذن الإشعارات `POST_NOTIFICATIONS`.
- iOS: لازم APNs configured + جهاز حقيقي.

### 8.5 APNs iOS

إعداد APNs Key/Certificate لا يمكن توليده تلقائيًا من داخل Flutter repo.
لازم يتم يدويًا في:

1. Apple Developer Account
2. Firebase Console > Cloud Messaging > iOS app configuration

## 9) ترتيب التشغيل اليومي المقترح

1. شغّل ETA service
2. شغّل Flutter بالأوامر مع `--dart-define`
3. راقب Firestore وFunctions logs عند الاختبار
4. قبل التسليم: `flutter analyze` ثم `flutter test`

## 10) ملخص سريع لأهم أمر تشغيل

```powershell
cd "D:\flutter project\smart_monadi"
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:8081
```
