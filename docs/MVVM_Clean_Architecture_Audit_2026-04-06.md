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

---

## Progress Update (Executed)

Implemented in this round:

1. Driver refactor (step 1)
- Moved core driver presentation logic out of `driver_screen.dart` into `DriverLiveViewModel`:
   - ETA computation and passenger sorting
   - status key/priority rules
   - manual pickup orchestration (mark pickup + log + SMS)
   - schedule-change tracking/alerts
- `driver_screen.dart` now behaves more as a view layer and delegates logic to ViewModel.

2. Use-cases added for Auth, Passenger, Operations (step 2)
- Auth use-cases: SignIn/Register/ResolveRole/SignOut/WatchAuthState.
- Passenger use-cases: SavePassengerProfile/WatchPassengerProfile/WatchPassengerTimeline.
- Operations use-cases: EnqueueTestSms/RequeueDeadLetter/WatchMetrics/WatchEvents/WatchDeadLetters.
- Presentation wiring updated to consume these use-cases in key screens/viewmodels.

3. Composition Root introduced (step 3)
- Added centralized dependency container: `lib/app/di/app_dependencies.dart`.
- Implementations are now composed in one place and injected downward:
   - `SmartMonadiApp` -> `AuthGateScreen` -> `HomeShell` -> feature screens/viewmodels.
- Reduced direct construction of repositories/services inside screens.

Validation after changes:
- `flutter analyze`: clean
- `flutter test`: pass

Additional continuation executed:
- Driver feature automation was further extracted into dedicated use-cases:
   - `CalculateEtaUseCase`
   - `SortPassengersUseCase`
   - `ManualMarkPickedUpUseCase`
   - `RunGeofenceAutomationUseCase`
- `DriverLiveViewModel` now orchestrates these use-cases instead of owning full automation business logic inline.

Latest continuation (strict-clean pass):
- Introduced Automation domain contract for events/SMS queue:
   - `TripEventRepository` (domain abstraction)
   - `FirestoreTripEventRepository` now implements it
- Updated Driver use-cases to depend on domain `TripEventRepository` abstraction (removed direct data dependency).
- Added dedicated tests for driver automation use-cases:
   - `ManualMarkPickedUpUseCase`
   - `RunGeofenceAutomationUseCase`
- Introduced Location domain abstractions:
   - `BusLocationRepository` (domain)
   - `DeviceLocationService` (domain)
   - concrete implementations now: `FirestoreBusLocationRepository`, `GeolocatorDeviceLocationService`
- Updated `AppDependencies`, `DriverLiveViewModel`, and `PassengerScreen` wiring to use location abstractions.
- Presentation-layer scan for `features/.../data/...` imports now returns no matches.

Validation after latest continuation:
- `flutter analyze`: clean
- targeted unit tests: pass (11/11)

Latest testing extension:
- Added `DriverLiveViewModel` behavior tests covering:
   - status keys/priorities
   - schedule alerts generation
   - manual pickup success/failure state handling
   - tracking permission denied/error path
   - sorting delegation behavior
- Extended `startTracking` success-path tests to assert automation side effects when bus/passenger streams emit:
   - approaching flow triggers geofence update + event + SMS
   - pickup-radius flow triggers markPickedUp + event + SMS
- Added startTracking plumbing/concurrency safety tests:
   - position stream emits are forwarded to `pushCurrentLocation`
   - `_isAutomating` gate prevents re-entrant automation while an automation run is still pending
- Added resilience/limits tests for `DriverLiveViewModel`:
   - dispose safety: stream emissions after dispose do not trigger side effects
   - schedule alerts cap remains bounded to latest 8 entries
- Added idempotency test for `startTracking`:
   - calling `startTracking` twice does not create duplicate subscriptions
   - position emission still produces a single `pushCurrentLocation` side effect
- Added tracking-recovery test:
   - `trackingError` is cleared after a later successful `startTracking`
- Expanded Operations ViewModel tests:
   - empty phone validation
   - dead-letter requeue missing-phone validation
   - dead-letter requeue failure handling and in-progress cleanup
   - time filter `all` behavior and template setter state update
- Added Passenger Form ViewModel tests:
   - successful save path
   - concurrent-save guard while first save is still in progress
- Validation now:
   - full test suite: pass (34/34)
   - `flutter analyze`: clean
