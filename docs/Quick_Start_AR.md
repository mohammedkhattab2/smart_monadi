# Smart Monadi - دليل الطالب السريع (5 دقائق)

هذا الدليل مخصص لطلاب مشروع التخرج للتشغيل السريع بعد Clone.

## 1) قبل التشغيل

- Flutter مثبت
- Android Studio/Emulator جاهز
- Python 3.10+ مثبت

## 2) بعد Clone مباشرة

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
Copy-Item assets\env\.env.example assets\env\.env -Force
Copy-Item eta_service\.env.example eta_service\.env -Force
```

افتح `eta_service/.env` وضع:

```env
GOOGLE_DIRECTIONS_API_KEY=PUT_REAL_SERVER_KEY_HERE
```

## 3) التشغيل

Terminal 1:

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_eta_service.ps1
```

Terminal 2 (Emulator):

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_flutter_emulator.ps1
```

أو جهاز حقيقي:

```powershell
cd "D:\flutter project\smart_monadi"
flutter devices
./scripts/run_flutter_device.ps1 -DeviceId <DEVICE_ID>
```

## 4) اختبار سريع

```powershell
curl http://127.0.0.1:8081/health
```

المتوقع:

```json
{"status":"ok"}
```

## 5) مشاكل شائعة

1. `REQUEST_DENIED`
- استخدم Server API Key صحيح.
- فعل `Directions API` و `Routes API` و Billing.

2. التطبيق لا يتصل بالـ ETA على الهاتف
- تأكد أن الهاتف والكمبيوتر على نفس Wi-Fi.
- استخدم IP الشبكة المحلية بدل `localhost`.

3. `flutter run` يفشل

```powershell
flutter clean
flutter pub get
flutter devices
```

ثم أعد التشغيل مع `-d <DEVICE_ID>`.
