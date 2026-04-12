# متطلبات العميل لتشغيل مشروع Smart Monadi

هذا الملف مخصص للعميل (مالك المشروع) لتجهيز البيئة وتشغيل المشروع مباشرة بعد Clone.

لو الهدف تشغيل سريع للطلاب بدون تفاصيل الإنتاج، استخدم:
- `docs/Student_Quick_Start_AR.md`

## 1) البرامج المطلوبة (Prerequisites)

- Flutter SDK (مضاف إلى PATH)
- Android Studio + Android SDK
- Java 17
- Python 3.10+
- Node.js 18+
- Firebase CLI
- Git

أوامر تحقق سريعة:

```powershell
flutter --version
python --version
node --version
firebase --version
```

## 2) ما يجب أن يستلمه العميل منك (Secrets/Configs)

لازم تسلّم العميل هذه القيم عبر قناة آمنة (واتساب خاص/مدير كلمات مرور) وليس داخل Git:

- Google Directions API Key (Server key) لاستخدام ETA service
- (للإصدار Release فقط) كلمات مرور التوقيع:
  - STORE_PASSWORD
  - KEY_PASSWORD
- (للإصدار Release فقط) ملف التوقيع إن لزم:
  - android/app/smart_monadi_key.jks
- (للإشعارات والـ SMS في الإنتاج) أسرار Firebase Functions:
  - TWILIO_ACCOUNT_SID
  - TWILIO_AUTH_TOKEN
  - TWILIO_FROM_NUMBER

## 3) بعد Clone مباشرة

من داخل جذر المشروع:

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
```

### 3.1 تجهيز ملفات البيئة المحلية

```powershell
Copy-Item assets\env\.env.example assets\env\.env -Force
Copy-Item eta_service\.env.example eta_service\.env -Force
```

ثم عدّل ملف:

- eta_service/.env

وضع:

```env
GOOGLE_DIRECTIONS_API_KEY=PUT_REAL_SERVER_KEY_HERE
CORS_ORIGINS=*
```

## 4) تشغيل المشروع محليًا (Development)

## 4.1 تشغيل خدمة ETA (Terminal 1)

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_eta_service.ps1
```

يجب أن تعمل الخدمة على المنفذ 8081.

## 4.2 تشغيل تطبيق Flutter (Terminal 2)

### Emulator:

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/run_flutter_emulator.ps1
```

### جهاز حقيقي:

```powershell
cd "D:\flutter project\smart_monadi"
flutter devices
./scripts/run_flutter_device.ps1 -DeviceId <DEVICE_ID>
```

ملاحظة: السكربت يمرر ETA_SERVICE_URL و DIRECTIONS_BACKEND_URL تلقائيًا.

## 5) تشغيل Release على Android (اختياري)

لو العميل يريد نسخة Release:

1. يضع ملف التوقيع jks محليًا في:
   - android/app/smart_monadi_key.jks
2. يضع كلمات المرور محليًا (local.properties أو Environment Variables)

مثال local.properties:

```properties
STORE_PASSWORD=...
KEY_PASSWORD=...
MAPS_API_KEY=...
```

أمر التشغيل Release:

```powershell
flutter run --release -d <DEVICE_ID> --dart-define=ETA_SERVICE_URL=http://<LOCAL_IP>:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://<LOCAL_IP>:8081
```

## 6) تحقق سريع بعد التشغيل

- ETA health:

```powershell
curl http://127.0.0.1:8081/health
```

النتيجة المتوقعة:

```json
{"status":"ok"}
```

- في التطبيق: الخريطة تظهر، تسجيل الدخول يعمل، والـ route/ETA يظهران بدون أخطاء.

## 7) أعطال شائعة وحلها

1. REQUEST_DENIED من Directions
- السبب: مفتاح غير صحيح أو غير مفعل للخدمة.
- الحل: استخدام Server API Key صحيح، وتفعيل Directions API + Routes API + Billing.

2. التطبيق لا يصل إلى ETA على جهاز حقيقي
- السبب: استخدام localhost بدل IP المحلي.
- الحل: التأكد أن الكمبيوتر والموبايل على نفس الشبكة واستخدام Local IP.

3. مشكلة خرائط في Android Release
- تأكد من وجود INTERNET permission في AndroidManifest (موجود بالمشروع).
- تأكد من MAPS_API_KEY الصحيح للبيئة.

4. Firebase Auth / Firestore لا يعملان
- التأكد من صحة إعدادات Firebase وملف google-services.json.

## 8) سياسة الأمان

- لا ترفع أي ملف .env حقيقي إلى Git.
- لا ترفع local.properties إلى Git.
- لا تشارك كلمات المرور أو المفاتيح في الشات العام.

## 9) أوامر مرجعية مفيدة

```powershell
flutter analyze
flutter test
firebase deploy --only firestore:indexes,firestore:rules
```

---

إذا التزم العميل بهذه الخطوات، سيعمل المشروع مباشرة بعد Clone بدون مشاكل متوقعة.
