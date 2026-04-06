# Smart Monadi - Go Live Checklist

استخدم هذه القائمة قبل أي Demo أو إطلاق فعلي.

## A) Flutter App

- [ ] `flutter pub get` بدون أخطاء.
- [ ] `flutter analyze` بدون أخطاء.
- [ ] `flutter test` ناجح.
- [ ] تسجيل/دخول الراكب يعمل.
- [ ] تسجيل/دخول السائق يعمل.

## B) Passenger Flow

- [ ] الراكب يحدد موقعه (موقعي الحالي أو الخريطة).
- [ ] حفظ بيانات الراكب يحدّث Firestore.
- [ ] حالة الباص والـ ETA تظهر في شاشة الراكب.
- [ ] Timeline يظهر بدون خطأ index.

## C) Driver Flow

- [ ] تتبع موقع السائق يعمل على الخريطة.
- [ ] قائمة الركاب مرتبة وتستبعد غير المجدولين.
- [ ] حالات الراكب تتغير (waiting / approaching / picked_up).
- [ ] route polyline يظهر (Directions أو fallback).

## D) Notifications

- [ ] SMS before arrival (4-5 minutes) يعمل.
- [ ] SMS at arrival zone يعمل.
- [ ] Push notifications تصل للمستخدم.
- [ ] fcmTokens تتسجل داخل `users/{uid}`.

## E) Firebase

- [ ] Firestore indexes deployed وحالتها Ready.
- [ ] Firestore rules مفعلة وتمنع الوصول غير المصرح.
- [ ] Functions deployed بنجاح.
- [ ] Twilio secrets مضبوطة.

## F) Python ETA Service

- [ ] خدمة ETA تعمل: `/health` => `ok`.
- [ ] `/predict` يعيد `etaMinutes`.
- [ ] Flutter شغال بـ `ETA_SERVICE_URL` الصحيح.

## G) Platform Specific

### Android
- [ ] Maps API key صحيح.
- [ ] إشعار foreground tracking يظهر أثناء التتبع.
- [ ] إذن الموقع + الإشعارات تم منحهما.

### iOS
- [ ] Push Notifications capability مفعلة.
- [ ] Background Modes (`location`, `remote-notification`) مفعلة.
- [ ] APNs مربوط مع Firebase.
- [ ] اختبار Push على جهاز حقيقي.

## H) Fast Start Commands

### Terminal 1 (ETA service)

```powershell
./scripts/run_eta_service.ps1
```

### Terminal 2 (Android emulator)

```powershell
./scripts/run_flutter_emulator.ps1 -DirectionsApiKey "YOUR_GOOGLE_DIRECTIONS_API_KEY"
```

### Terminal 2 (Android device)

```powershell
./scripts/run_flutter_device.ps1 -DirectionsApiKey "YOUR_GOOGLE_DIRECTIONS_API_KEY" -EtaServiceUrl "http://192.168.1.100:8081"
```
