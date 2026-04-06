# Smart Monadi - Execution Session (خطوة بخطوة)

استخدم هذا الملف كجلسة تنفيذ سريعة للوصول لحالة Ready.

## Step 1: Precheck

```powershell
cd "E:\flutter project\smart_monadi"
./scripts/go_live_precheck.ps1
```

لو تريد تجاوز الاختبارات مؤقتًا:

```powershell
./scripts/go_live_precheck.ps1 -SkipTests
```

## Step 2: تشغيل التطوير بسرعة (Emulator)

```powershell
cd "E:\flutter project\smart_monadi"
./scripts/start_dev_emulator.ps1 -DirectionsApiKey "YOUR_GOOGLE_DIRECTIONS_API_KEY"
```

هذا الأمر سيقوم بـ:

1. فتح نافذة PowerShell وتشغيل ETA service
2. تشغيل Flutter مع ETA + Directions defines

## Step 3: تحقق سريع داخل التطبيق

1. سجل دخول سائق
2. تأكد ظهور الخريطة والمسار
3. سجل دخول راكب
4. حدد الموقع واحفظ
5. راقب ETA + timeline + SMS/Push

## Step 4: إذا ظهر خطأ

- راجع: docs/Run_Commands_Guide_AR.md
- راجع: docs/Go_Live_Checklist_AR.md

## Step 5: قبل الديمو

```powershell
cd "E:\flutter project\smart_monadi"
flutter analyze
flutter test
```
