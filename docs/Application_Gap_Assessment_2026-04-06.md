# Smart Monadi - Gap Assessment (2026-04-06)

## الهدف من هذا التقرير
مراجعة ما تم تنفيذه في التطبيق مقارنة بوثيقة البنية، وتحديد النواقص الفعلية المتبقية للوصول إلى نسخة مكتملة وظيفيًا وتشغيليًا.

---

## 1) ما تم تنفيذه فعليًا

### 1.1 بنية التطبيق والواجهات
- يوجد فصل واضح بين دور الراكب والسائق عبر المصادقة وتحديد الدور.
- تم تنفيذ شاشات:
  - Auth
  - Passenger
  - Driver
  - Operations Dashboard
- يوجد تصميم موحد عبر Design System (tokens + primitives + states + skeleton + motion).

مراجع:
- lib/features/auth/presentation/screens/auth_gate_screen.dart
- lib/features/home/presentation/screens/home_shell.dart
- lib/features/passenger/presentation/screens/passenger_screen.dart
- lib/features/driver/presentation/screens/driver_screen.dart
- lib/features/operations/presentation/screens/operations_dashboard_screen.dart
- lib/app/design/app_primitives.dart
- lib/app/design/design_tokens.dart

### 1.2 تتبع الباص والـ ETA والـ Geofencing
- تتبع الموقع المباشر للباص متاح.
- ETA محسوب من المسافة الحالية.
- Geofencing automation مطبق:
  - approaching عند اقتراب الباص.
  - picked_up_auto داخل نطاق الاستلام.
- تحديث حالة الراكب وسجل الرحلة يتم تلقائيًا.

مراجع:
- lib/features/driver/presentation/viewmodels/driver_live_view_model.dart
- lib/features/location/data/services/device_location_service.dart
- lib/features/passenger/data/repositories/passenger_repository.dart
- lib/features/automation/data/repositories/trip_event_repository.dart

### 1.3 SMS workflow + التشغيل
- يوجد Outbox + Retry + Dead-letter + Metrics + Delivery events.
- Firebase Functions مربوطة بجدولة لمعالجة pending وfailed.
- Twilio integration موجود مع تصنيف أخطاء وإعادة المحاولة.

مراجع:
- functions/index.js
- lib/features/operations/presentation/screens/operations_dashboard_screen.dart
- firestore.indexes.json

### 1.4 جودة أساسية
- التحليل يمر بدون مشاكل (flutter analyze).
- الاختبارات الحالية تمر (flutter test).
- الثيم محفوظ في التخزين المحلي.
- اللغة لا تُفرض عند البدء وتستعيد الإعداد.

مراجع:
- lib/app/app.dart
- lib/main.dart

---

## 2) النواقص الحقيقية المتبقية

## P0 (ضرورية قبل اعتبار التطبيق "100% جاهز")

### 2.1 اختبار تشغيل End-to-End فعلي (Build + Run)
الحالة الحالية: التحليل والاختبارات الوحدوية ناجحة، لكن لا يوجد توثيق Build نهائي ناجح داخل هذه الدورة.

المطلوب:
- تنفيذ Build APK/IPA بنجاح وتوثيق النتيجة.
- تشغيل فعلي على جهاز/محاكي مع التحقق من:
  - login/register
  - live tracking
  - automation transitions
  - SMS queue lifecycle

### 2.2 تغطية اختبارات غير كافية جدًا
الحالة الحالية: يوجد اختبار واحد بسيط للـ Passenger entity فقط.

المطلوب:
- إضافة اختبارات ViewModel للمنطق الحرج:
  - DriverLiveViewModel automation paths
  - Auth input validation paths
  - Operations filters/requeue logic
- إضافة widget tests للشاشات الأساسية.

مرجع:
- test/widget_test.dart

### 2.3 حماية أقوى من التكرار في أتمتة الـ SMS
الحالة الحالية: يوجد منطق جيد للتعامل مع retry/lock، لكن يلزم تدقيق production-ready لمنع أي enqueue duplicates في ظروف edge cases (network jitter/duplicate triggers).

المطلوب:
- وضع idempotency key واضح لرسائل outbox لكل نوع حدث (approaching/arrival).
- إضافة guard rules أو dedupe check قبل enqueue.

---

## P1 (مهمة جدًا بعد P0)

### 2.4 قواعد Firestore الأمنية (Security Rules)
الحالة الحالية: غير موثقة هنا ضمن النطاق المقروء.

المطلوب:
- توثيق وتفعيل قواعد تمنع:
  - وصول غير مصرح لبيانات الركاب.
  - تعديل status/metrics من العميل مباشرة خارج المسار المسموح.
  - وصول غير مصرح لـ sms_outbox / dead_letter.

### 2.5 توحيد UX إضافي للسائق
الحالة الحالية: ممتازة، لكن ما زال هناك فرصة تحسين إدارة الكثافة المعلوماتية في الشاشات الصغيرة.

المطلوب:
- collapsible schedule alerts.
- highlights أقوى للحالات الحرجة مع قواعد ألوان موحدة.

### 2.6 تحسين README التشغيلي
الحالة الحالية: README ما يزال قالب Flutter افتراضي تقريبًا.

المطلوب:
- إعداد المشروع خطوة بخطوة:
  - Flutter/Firebase setup
  - functions secrets
  - run/debug commands
  - known limitations

مرجع:
- README.md

---

## P2 (تحسينات إكمال المنتج)

### 2.7 Offline/poor-network handling
- رسائل توضيحية أو queue محلية عند انقطاع الشبكة.
- retry UX واضح في الواجهات.

### 2.8 Observability
- توسيع لوحة المقاييس بإحصاءات زمنية (نِسب النجاح/الفشل لكل فترة).
- تنبيهات تشغيلية عند تجاوز thresholds.

### 2.9 Documentation alignment
- تحديث مستمر لوثيقة البنية مع كل قرار تقني جديد (خصوصًا القيم الفعلية للـ radii والـ geofence thresholds).

---

## 3) التقييم العام الحالي
- من حيث البنية والـ UX والمنطق الأساسي: التقدم قوي جدًا.
- من حيث "جاهزية 100%": ما ينقص أساسًا هو:
  - Build/Run verification end-to-end.
  - اختبار تلقائي أوسع للمنطق الحرج.
  - تثبيت Security Rules وREADME تشغيلي.

التقييم المقترح الحالي: 85%-90% من مسار MVP التشغيلي.

---

## 4) خطة الإغلاق السريعة المقترحة

### Sprint إغلاق 1 (قصير)
1. Build verification (Android + iOS إن أمكن).
2. إضافة اختبارين ViewModel + اختبار Widget أساسي.
3. توثيق README التشغيلي.

### Sprint إغلاق 2
1. تدقيق idempotency لمنع duplicate SMS enqueue.
2. توثيق/تفعيل Security Rules.
3. تحسينات UX النهائية للسائق.

---

## 5) قرار عملي
إذا الهدف هو "100% تشغيل" بأقل وقت، الأولوية الفورية يجب أن تكون:
1) Build/Run verification
2) Test coverage للمنطق الحرج
3) Security Rules

بعدها أي تحسينات تصميم إضافية تكون تحسين جودة وليست مانع تشغيل.
