import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/run_geofence_automation_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/sort_passengers_use_case.dart';
import 'package:smart_monadi/features/driver/presentation/screens/driver_screen.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/domain/services/device_location_service.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    dotenv.testLoad(fileInput: 'DIRECTIONS_API_KEY=\nETA_SERVICE_URL=');
  });

  testWidgets('driver can edit passenger schedule with validation', (
    tester,
  ) async {
    // Suppress RenderFlex overflow errors - we are testing dialog logic, not
    // pixel-perfect layout at every test resolution.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final harness = _DriverScreenTestHarness();
    final vm = harness.createViewModel();
    await vm.setTrackingEnabled(false);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(body: DriverScreen(viewModel: vm)),
            ),
          ),
        ),
      ),
    );
    // Give EasyLocalization + ScreenUtil + AppFadeSlideIn time to initialise.
    await tester.pump(const Duration(milliseconds: 500));

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');

    harness.passengerRepository.emitPassengers([
      Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '$hh:$mm',
        returnTime: '$hh:$mm',
        updatedAtMillis: 1,
      ),
    ]);

    // Let StreamBuilder + AnimatedBuilder + AppFadeSlideIn settle.
    await tester.pump(const Duration(milliseconds: 500));

    // The button text comes from translations — use the key fallback if
    // translations did not load, or the English value if they did.
    var editBtnFinder = find.widgetWithText(FilledButton, 'Edit schedule');
    if (editBtnFinder.evaluate().isEmpty) {
      editBtnFinder = find.widgetWithText(FilledButton, 'driver.edit_schedule');
    }
    expect(editBtnFinder, findsOneWidget);

    await tester.ensureVisible(editBtnFinder);
    await tester.tap(editBtnFinder);
    await tester.pump(const Duration(milliseconds: 300));

    // Dialog title — try translated first, then key fallback.
    final dialogTitleFound =
        find.text('Edit passenger schedule').evaluate().isNotEmpty ||
        find.text('driver.edit_schedule_title').evaluate().isNotEmpty;
    expect(dialogTitleFound, isTrue);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));

    // Enter invalid time → Confirm → validation error shown.
    await tester.enterText(fields.at(0), '99:99');
    await tester.enterText(fields.at(1), '15:30');
    final confirmFinder =
        find.widgetWithText(FilledButton, 'Confirm').evaluate().isNotEmpty
        ? find.widgetWithText(FilledButton, 'Confirm')
        : find.widgetWithText(FilledButton, 'driver.confirm');
    await tester.tap(confirmFinder);
    await tester.pump(const Duration(milliseconds: 300));

    final validationErrorShown =
        find.text('Time format must be HH:mm').evaluate().isNotEmpty ||
        find.text('driver.edit_schedule_invalid').evaluate().isNotEmpty;
    expect(validationErrorShown, isTrue);

    // Enter valid time → Confirm → dialog closes, repository called.
    await tester.enterText(fields.at(0), '08:15');
    await tester.enterText(fields.at(1), '15:30');
    await tester.tap(confirmFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.passengerRepository.upsertPassengerCalls, 1);
    expect(harness.passengerRepository.lastUpsertPickupTime, '08:15');
    expect(harness.passengerRepository.lastUpsertReturnTime, '15:30');

    // Tear down cleanly to avoid async leaks.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    vm.dispose();
    harness.dispose();
  });
}

class _DriverScreenTestHarness {
  final locationService = _FakeDeviceLocationService();
  final locationRepository = _FakeBusLocationRepository();
  final passengerRepository = _FakePassengerRepository();
  final tripEventRepository = _FakeTripEventRepository();

  DriverLiveViewModel createViewModel() {
    const calculateEtaUseCase = CalculateEtaUseCase();
    final sortPassengersUseCase = SortPassengersUseCase(calculateEtaUseCase);
    final manualMarkPickedUpUseCase = ManualMarkPickedUpUseCase(
      passengerRepository: passengerRepository,
      tripEventRepository: tripEventRepository,
    );
    final runGeofenceAutomationUseCase = RunGeofenceAutomationUseCase(
      passengerRepository: passengerRepository,
      tripEventRepository: tripEventRepository,
    );

    return DriverLiveViewModel(
      locationService: locationService,
      locationRepository: locationRepository,
      passengerRepository: passengerRepository,
      calculateEtaUseCase: calculateEtaUseCase,
      sortPassengersUseCase: sortPassengersUseCase,
      manualMarkPickedUpUseCase: manualMarkPickedUpUseCase,
      runGeofenceAutomationUseCase: runGeofenceAutomationUseCase,
    );
  }

  void dispose() {
    locationService.dispose();
    locationRepository.dispose();
    passengerRepository.dispose();
  }
}

class _FakeDeviceLocationService implements DeviceLocationService {
  @override
  Future<bool> ensurePermission() async => false;

  @override
  Stream<Position> watchPosition() {
    return const Stream<Position>.empty();
  }

  void dispose() {}
}

class _FakeBusLocationRepository implements BusLocationRepository {
  final StreamController<BusLocation?> _busController =
      StreamController<BusLocation?>.broadcast();

  @override
  Future<void> pushCurrentLocation(Position position) async {}

  @override
  Stream<BusLocation?> watchBusLocation() {
    return _busController.stream;
  }

  void dispose() {
    _busController.close();
  }
}

class _FakePassengerRepository implements PassengerRepository {
  final StreamController<List<Passenger>> _passengersController =
      StreamController<List<Passenger>>.broadcast();
  List<Passenger> _latestPassengers = const <Passenger>[];

  int upsertPassengerCalls = 0;
  String? lastUpsertPickupTime;
  String? lastUpsertReturnTime;

  @override
  Stream<List<Passenger>> watchPassengers() {
    return Stream<List<Passenger>>.multi((controller) {
      controller.add(_latestPassengers);
      final sub = _passengersController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void emitPassengers(List<Passenger> passengers) {
    _latestPassengers = List<Passenger>.unmodifiable(passengers);
    _passengersController.add(passengers);
  }

  @override
  Future<void> upsertPassenger({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String pickupTime,
    String returnTime = '',
    double? latitude,
    double? longitude,
  }) async {
    upsertPassengerCalls += 1;
    lastUpsertPickupTime = pickupTime;
    lastUpsertReturnTime = returnTime;
  }

  @override
  Future<void> updatePassengerLocation({
    required String passengerId,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<void> markPickedUp({
    required String passengerId,
    double? distanceMeters,
  }) async {}

  @override
  Future<void> updateGeofenceState({
    required String passengerId,
    required String geofenceState,
    required double distanceMeters,
  }) async {}

  @override
  Stream<Passenger?> watchPassengerById(String id) {
    return const Stream<Passenger?>.empty();
  }

  @override
  Stream<List<PassengerTimelineEvent>> watchPassengerTimeline({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  }) {
    return const Stream<List<PassengerTimelineEvent>>.empty();
  }

  void dispose() {
    _passengersController.close();
  }
}

class _FakeTripEventRepository implements TripEventRepository {
  @override
  Future<void> addPickupLog({
    required String passengerId,
    required String passengerPhone,
    required String type,
    required String message,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<void> queueSms({
    required String passengerId,
    required String toPhone,
    required String template,
    required Map<String, dynamic> variables,
    required String idempotencyKey,
  }) async {}
}
