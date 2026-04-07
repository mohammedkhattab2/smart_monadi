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
flutter run --dart-define=ETA_SERVICE_URL=http://192.168.1.4:8081
```

## 3) تشغيل الجهاز الحقيقي (نسخ سريع)

عدّل الـ IP فقط ثم شغّل:

```powershell
cd "D:\flutter project\smart_monadi"
flutter pub get
flutter run --release --dart-define=ETA_SERVICE_URL=http://192.168.1.4:8081
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
flutter run --release --dart-define="ETA_SERVICE_URL=http://$IP:8081"
```

مهم:
- غيّر `YOUR_LOCAL_IP` إلى IP جهازك الفعلي على نفس الشبكة.
- تشغيل Release يقلل مشاكل Firebase Auth/Recaptcha المرتبطة بوضع Debug.

لو الأمر فشل:
- تأكد أن خدمة ETA شغالة على نفس الـ IP والـ Port `8081`.
- تأكد أن الموبايل والكمبيوتر على نفس شبكة Wi-Fi.

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
