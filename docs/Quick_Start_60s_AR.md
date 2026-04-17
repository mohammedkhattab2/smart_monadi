# Smart Monadi - Quick Start (60 ثانية)

هذا الملف لأسرع تشغيل ممكن على Windows PowerShell.

## 1) شغّل خدمة ETA (Terminal 1)

قبل التشغيل أنشئ ملف البيئة للخدمة:

```powershell
cd "D:\flutter project\smart_monadi\eta_service"
Copy-Item .env.example .env
```

ثم ضع قيمة `GOOGLE_DIRECTIONS_API_KEY` داخل ملف `.env`.

الأسرع باستخدام السكربت:

```powershell
./scripts/run_eta_service.ps1
```

أو يدويًا:

```powershell
cd "D:\flutter project\smart_monadi\eta_service"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8081
```

اترك هذا التيرمنال مفتوحًا.

## 2) شغّل التطبيق (Terminal 2)

تأكد أن ملف Flutter env موجود:

```powershell
cd "D:\flutter project\smart_monadi"
Copy-Item assets\env\.env.example assets\env\.env -Force
```

الأسرع باستخدام السكربت:

```powershell
./scripts/run_flutter_emulator.ps1
```

أو يدويًا (Emulator):

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
flutter devices
flutter run -d <DEVICE_ID> --dart-define=ETA_SERVICE_URL=http://192.168.1.4:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://192.168.1.4:8081
```

### بيانات الدخول الجديدة (مهم)

- تسجيل الدخول أصبح: `رقم الهوية + كلمة السر`.
- التسجيل أصبح: `اسم المستخدم + رقم الهوية + كلمة السر + تأكيد كلمة السر`.
- الأدوار المتاحة في التسجيل: `ولي أمر` أو `سائق`.
- يوجد خيار `حفظ كلمة السر` في شاشة تسجيل الدخول.

## 3) تشغيل الجهاز الحقيقي (نسخ سريع)

عدّل الـ IP فقط ثم شغّل:

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
flutter devices
flutter run -d <DEVICE_ID> --release --dart-define=ETA_SERVICE_URL=http://192.168.1.4:8081 --dart-define=DIRECTIONS_BACKEND_URL=http://192.168.1.4:8081
```

بديل تلقائي (PowerShell) لاكتشاف الـ IP وتشغيل التطبيق مباشرة:

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
$IP = Get-NetIPAddress -AddressFamily IPv4 |
	Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254*' } |
	Select-Object -First 1 -ExpandProperty IPAddress
if (-not $IP) {
	Write-Error "Could not detect local IP. Set YOUR_LOCAL_IP manually."
	exit 1
}
Write-Host "Using local IP: $IP"
flutter devices
flutter run -d <DEVICE_ID> --release --dart-define="ETA_SERVICE_URL=http://$IP:8081" --dart-define="DIRECTIONS_BACKEND_URL=http://$IP:8081"
```

مهم:
- غيّر `YOUR_LOCAL_IP` إلى IP جهازك الفعلي على نفس الشبكة.
- تشغيل Release يقلل مشاكل Firebase Auth/Recaptcha المرتبطة بوضع Debug.
- إذا عندك أكثر من جهاز متصل (Mobile + Windows + Chrome)، لازم تحدد `-d <DEVICE_ID>` لتفادي فشل التشغيل.
- الأفضل في هذا المشروع استخدام `DIRECTIONS_BACKEND_URL` بدل تمرير `DIRECTIONS_API_KEY` في العميل.

لو الأمر فشل:
- تأكد أن خدمة ETA شغالة على نفس الـ IP والـ Port `8081`.
- تأكد أن الموبايل والكمبيوتر على نفس شبكة Wi-Fi.
- لو `/directions` يرجّع `REQUEST_DENIED`: استخدم Server API Key صالح للـ Web Service (مش Android-restricted)، وفعّل `Directions API` + `Routes API` + Billing في Google Cloud.

## 4) أهم ملاحظة

تفاصيل التكامل الآمن (Directions + ETA + CORS + Security Restrictions):

`docs/Directions_ETA_Secure_Integration.md`

`--dart-define` لا يعمل وحده.
لازم دائمًا ييجي مع `flutter run`.

## 5) لو ظهر خطأ فهارس Firestore

```powershell
cd "D:\flutter project\smart_monadi"
firebase deploy --only firestore:indexes
```

ثم انتظر حتى الحالة تصبح `Ready` في Firebase Console.

## 5.1) Migration اختياري للمستخدمين القدامى (passenger -> parent)

لو عندك بيانات قديمة بأدوار `passenger` أو `user` وتريد توحيدها إلى `parent`:

```powershell
cd "D:\flutter project\smart_monadi"
./scripts/migrate_legacy_roles_to_parent.ps1 -DryRun
./scripts/migrate_legacy_roles_to_parent.ps1
```

ملاحظة:
- السكربت يحتاج صلاحية Firebase Admin عبر `GOOGLE_APPLICATION_CREDENTIALS` أو Application Default Credentials.

## 6) اختبار Live-Bind للإشعارات (FCM)

استخدم Data Message في Firebase Console أو من الباكند بنفس البنية التالية.

تحديث رحلة نشطة (لازم يحدث UI بدون تنقل إذا نفس الرحلة):

```json
{
	"type": "trip_update",
	"tripId": "trip_1",
	"status": "driver_arriving",
	"driverId": "drv_11"
}
```

اختبار تعارض رحلة مختلفة (لازم يمنع overwrite ويظهر Active Trip Locked):

```json
{
	"type": "trip_update",
	"tripId": "trip_2",
	"status": "driver_arriving",
	"driverId": "drv_22"
}
```

اختبار إنهاء الرحلة (لازم يمسح active trip state):

```json
{
	"type": "trip_update",
	"tripId": "trip_1",
	"status": "completed",
	"driverId": "drv_11"
}
```

ملاحظات سريعة:
- المفاتيح البديلة مدعومة أيضًا: `trip_id`, `driver_id`, `tripStatus`, `eventType`.
- في وضع live bind، الأفضل إرسال الرسائل كـ data payload لضمان التوجيه الدقيق.
