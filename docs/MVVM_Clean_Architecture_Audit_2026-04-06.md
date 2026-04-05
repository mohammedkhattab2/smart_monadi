# Smart Monadi - MVVM + Clean Architecture Audit (2026-04-06)

## Executive Result
Current architecture is **not 100% compliant** with strict MVVM + Clean Architecture.

Estimated compliance:
- MVVM: **~75%**
- Clean Architecture: **~55%**
- Combined strict target readiness: **~60-65%**

Reason: presentation layer still has direct dependencies on data sources/framework APIs, and domain layer is too thin (mostly entities, no use-cases/contracts).

---

## What Is Good (Already Aligned)

1. Feature-based folder organization exists and is understandable.
2. Domain entities exist for key business objects.
3. ViewModels are present in some features (Passenger, Driver) and handle state changes.
4. Data repositories exist and encapsulate some Firestore operations.
5. UI/state/error/skeleton design is consistently implemented.

---

## Main Gaps Preventing 100% Compliance

## A) Presentation layer depends directly on Data layer
This violates Clean dependency direction (Presentation -> Domain -> Data).

Examples:
- `presentation` importing `data` repositories/services directly.
- Screens creating repositories/services directly.

Files:
- lib/features/home/presentation/screens/home_shell.dart
- lib/features/driver/presentation/screens/driver_screen.dart
- lib/features/passenger/presentation/screens/passenger_screen.dart
- lib/features/auth/presentation/screens/auth_screen.dart
- lib/features/auth/presentation/screens/auth_gate_screen.dart
- lib/features/passenger/presentation/viewmodels/passenger_form_view_model.dart
- lib/features/driver/presentation/viewmodels/driver_live_view_model.dart

## B) Presentation layer contains direct framework/data-source calls
This is a strong architecture break for both MVVM and Clean.

Examples:
- Direct FirebaseFirestore/FirebaseAuth usage from screens.
- Geolocator distance logic inside screens.

Files:
- lib/features/operations/presentation/screens/operations_dashboard_screen.dart
- lib/features/passenger/presentation/screens/passenger_screen.dart
- lib/features/driver/presentation/screens/driver_screen.dart

## C) Domain layer lacks use-cases and repository contracts
Strict Clean requires domain contracts and use-cases independent from data implementations.

Current status:
- Domain mostly has entities and enums.
- No explicit use-case classes (`SignInUseCase`, `TrackBusUseCase`, etc.).
- No abstract repository interfaces in domain consumed by presentation.

## D) Business logic split is inconsistent
Some business rules are in ViewModel, some in Screen widgets.

Examples:
- ETA and status logic duplicated/kept in UI screens.
- Operations workflow logic lives almost entirely in a Screen class.

Files:
- lib/features/driver/presentation/screens/driver_screen.dart
- lib/features/operations/presentation/screens/operations_dashboard_screen.dart

## E) Dependency injection pattern is manual and UI-owned
For strict Clean, composition root should wire implementations to abstractions.

Current status:
- Repositories/services instantiated in UI scope (`HomeShell` and screens).

---

## Architecture Compliance Decision

Is project 100% MVVM + Clean Architecture now?
- **No.**

Can it become 100% with current codebase?
- **Yes**, but requires structural refactor, not only styling or small edits.

---

## Practical Migration Plan to Reach 100%

## Phase 1 (High Impact, Low Risk)
1. Create domain repository interfaces for each feature.
2. Update ViewModels to depend on domain interfaces, not concrete data classes.
3. Move all FirebaseAuth/Firestore calls out of screens into repositories/use-cases.
4. Keep screens as pure View + state rendering only.

## Phase 2 (Core Clean Completion)
1. Add use-cases in domain layer:
   - Auth: SignIn, Register, ResolveRole, SignOut
   - Driver: StartTracking, ProcessPassengerAutomation
   - Passenger: SavePassengerProfile, WatchPassengerTimeline
   - Operations: EnqueueTestSms, RequeueDeadLetter, WatchMetrics/Events
2. Move business rules from screens into use-cases/viewmodels.

## Phase 3 (Strictness + Testability)
1. Add a simple DI composition root.
2. Add unit tests for use-cases and viewmodels.
3. Add architecture guard checks (import rules by convention).

---

## Immediate Refactor Priority Order
1. `operations_dashboard_screen.dart` (largest architecture debt)
2. `passenger_screen.dart` (direct Firebase/Auth calls)
3. `auth_screen.dart` + `auth_gate_screen.dart` (service calls in UI)
4. `home_shell.dart` (UI-owned data instantiation)

---

## Final Conclusion
The project is functionally strong and well-progressed, but architecture is **not yet strict-clean**.
To claim "100% MVVM/Clean Architecture", the listed dependency-direction and domain-use-case gaps must be refactored.
