# Smart Monadi - Go Live Checklist

استخدم هذه القائمة قبل أي Demo أو إطلاق فعلي.

## Execution Status (2026-04-07)

تم التحقق تلقائيًا في هذه الجلسة:

- [x] `flutter pub get` بدون أخطاء.
- [x] `flutter analyze` بدون أخطاء.
- [x] `flutter test` ناجح.
- [x] Firestore indexes deployed وحالتها Ready.
- [x] Firestore rules مفعلة وتمنع الوصول غير المصرح.
- [x] Functions deployed بنجاح.
- [x] خدمة ETA تعمل: `/health` => `ok`.
- [x] `/predict` يعيد `etaMinutes`.
- [x] تم تشغيل التطبيق بنجاح على جهاز Android حقيقي (Release).
- [x] تم حل خطأ `cloud_firestore/permission-denied` المرتبط بتحديث FCM token أثناء تبديل الجلسة.

متبقي لاختبار يدوي على الأجهزة:

- [ ] تسجيل/دخول الراكب والسائق على أجهزة فعلية.
- [ ] التتبع المباشر + route polyline في سيناريو حي.
- [ ] SMS قبل الوصول/عند الوصول مع رقم Twilio فعلي.
- [ ] Push notifications على Android/iOS (خصوصًا APNs على iOS).
- [ ] التحقق النهائي من منح صلاحيات الموقع/الإشعارات على الأجهزة.

## A) Flutter App

- [x] `flutter pub get` بدون أخطاء.
- [x] `flutter analyze` بدون أخطاء.
- [x] `flutter test` ناجح.
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

- [x] Firestore indexes deployed وحالتها Ready.
- [x] Firestore rules مفعلة وتمنع الوصول غير المصرح.
- [x] Functions deployed بنجاح.
- [ ] Twilio secrets مضبوطة.
- [x] لا يوجد مفاتيح خرائط hardcoded داخل AndroidManifest/Info.plist.

## F) Python ETA Service

- [x] خدمة ETA تعمل: `/health` => `ok`.
- [x] `/predict` يعيد `etaMinutes`.
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
./scripts/run_flutter_emulator.ps1
```

### Terminal 2 (Android device)

```powershell
./scripts/run_flutter_device.ps1 -EtaServiceUrl "http://192.168.1.100:8081"
```

### Terminal 3 (Backend smoke)

```powershell
./scripts/go_live_backend_smoke.ps1
```
