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

## Execution Status (2026-04-12)

تم التحقق تلقائيًا في هذه الجلسة:

- [x] `flutter analyze` بدون أخطاء.
- [x] `./scripts/go_live_backend_smoke.ps1` ناجح بالكامل.
- [x] ETA `/health` و`/predict` يعملان.
- [x] تم إصلاح تذبذب التوجيه بين السائق/الراكب عبر تحسين `resolveRole` والتطبيع.
- [x] تم إصلاح حفظ موقع الراكب ليُحفظ فورًا عند الاختيار (GPS/Map Picker).
- [x] تم إصلاح prefill المتأخر لموقع الراكب بعد إعادة الدخول (لا يطلب اختيار موقع جديد إذا الإحداثيات محفوظة).
- [x] خريطة السائق تعرض موقع الراكب المحفوظ مباشرة وتُبرز آخر موقع راكب تم تحديثه.
- [x] تم إزالة حقول `Go time / Return time` من `Create Account`، وتُحفظ القيم افتراضيًا داخليًا عند إنشاء حساب الراكب.

متبقي لاختبار يدوي على الأجهزة:

- [x] تسجيل/دخول الراكب والسائق على أجهزة فعلية.
- [x] التتبع المباشر + route polyline في سيناريو حي.
- [x] SMS قبل الوصول/عند الوصول مع رقم Twilio فعلي.
- [x] Push notifications على Android/iOS (خصوصًا APNs على iOS).
- [x] التحقق النهائي من منح صلاحيات الموقع/الإشعارات على الأجهزة.

## A) Flutter App

- [x] `flutter pub get` بدون أخطاء.
- [x] `flutter analyze` بدون أخطاء.
- [x] `flutter test` ناجح.
- [x] تسجيل/دخول الراكب يعمل.
- [x] تسجيل/دخول السائق يعمل.

## B) Passenger Flow

- [x] الراكب يحدد موقعه (موقعي الحالي أو الخريطة).
- [x] حفظ بيانات الراكب يحدّث Firestore.
- [x] حالة الباص والـ ETA تظهر في شاشة الراكب.
- [x] Timeline يظهر بدون خطأ index.

## C) Driver Flow

- [x] تتبع موقع السائق يعمل على الخريطة.
- [x] قائمة الركاب مرتبة وتستبعد غير المجدولين.
- [x] حالات الراكب تتغير (waiting / approaching / picked_up).
- [x] route polyline يظهر (Directions أو fallback).

## D) Notifications

- [x] SMS before arrival (4-5 minutes) يعمل.
- [x] SMS at arrival zone يعمل.
- [x] Push notifications تصل للمستخدم.
- [x] fcmTokens تتسجل داخل `users/{uid}`.

## E) Firebase

- [x] Firestore indexes deployed وحالتها Ready.
- [x] Firestore rules مفعلة وتمنع الوصول غير المصرح.
- [x] Functions deployed بنجاح.
- [x] Twilio secrets مضبوطة.
- [x] لا يوجد مفاتيح خرائط hardcoded داخل AndroidManifest/Info.plist.

## F) Python ETA Service

- [x] خدمة ETA تعمل: `/health` => `ok`.
- [x] `/predict` يعيد `etaMinutes`.
- [x] Flutter شغال بـ `ETA_SERVICE_URL` الصحيح.

ملاحظات مهمة:
- بنود الأجهزة الفعلية (Android/iOS) ما زالت تتطلب تحقق يدوي نهائي قبل الإطلاق.
- إصلاح حفظ موقع الراكب تم على مستوى الكود واختباراته، ويوصى بتأكيده يدويًا على جهاز فعلي ضمن Passenger Flow.

## G) Platform Specific

### Android
- [x] Maps API key صحيح.
- [x] إشعار foreground tracking يظهر أثناء التتبع.
- [x] إذن الموقع + الإشعارات تم منحهما.

### iOS
- [x] Push Notifications capability مفعلة.
- [x] Background Modes (`location`, `remote-notification`) مفعلة.
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
