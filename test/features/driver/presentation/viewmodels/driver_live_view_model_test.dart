import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/run_geofence_automation_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/sort_passengers_use_case.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/domain/services/device_location_service.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

void main() {
  group('DriverLiveViewModel', () {
    test('status helpers return expected values', () {
      final harness = _TestHarness();
      final vm = harness.createViewModel();

      const waiting = Passenger(
        id: '1',
        name: 'Waiting',
        phone: '1',
        address: 'a',
        pickupTime: '07:30',
        updatedAtMillis: 1,
      );
      const approaching = Passenger(
        id: '2',
        name: 'Approaching',
        phone: '2',
        address: 'b',
        pickupTime: '07:30',
        geofenceState: 'approaching',
        updatedAtMillis: 1,
      );
      const picked = Passenger(
        id: '3',
        name: 'Picked',
        phone: '3',
        address: 'c',
        pickupTime: '07:30',
        geofenceState: 'picked_up',
        updatedAtMillis: 1,
      );

      expect(vm.statusKey(waiting), 'driver.status_waiting');
      expect(vm.statusKey(approaching), 'driver.status_approaching');
      expect(vm.statusKey(picked), 'driver.status_picked_up');

      expect(vm.statusPriority(approaching), 0);
      expect(vm.statusPriority(waiting), 1);
      expect(vm.statusPriority(picked), 2);
    });

    test('onPassengerSchedulesSnapshot creates schedule alerts on changes', () {
      final harness = _TestHarness();
      final vm = harness.createViewModel();

      const initial = Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '1',
        address: 'Cairo',
        pickupTime: '07:30',
        returnTime: '14:00',
        updatedAtMillis: 1,
      );
      const changed = Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '1',
        address: 'Cairo',
        pickupTime: '08:00',
        returnTime: '15:00',
        updatedAtMillis: 2,
      );

      vm.onPassengerSchedulesSnapshot(const [initial]);
      expect(vm.scheduleAlerts, isEmpty);

      vm.onPassengerSchedulesSnapshot(const [changed]);
      expect(vm.scheduleAlerts.length, 1);
      expect(vm.scheduleAlerts.first.passengerName, 'Ali');
      expect(vm.scheduleAlerts.first.previousPickup, '07:30');
      expect(vm.scheduleAlerts.first.currentPickup, '08:00');
    });

    test('manualMarkPickedUp success clears in-progress flag', () async {
      final harness = _TestHarness();
      final vm = harness.createViewModel();

      const passenger = Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '07:30',
        updatedAtMillis: 1,
      );

      final result = await vm.manualMarkPickedUp(passenger);

      expect(result, isNull);
      expect(vm.isManualPickupInProgress('p1'), isFalse);
      expect(harness.passengerRepository.markPickedUpCalls, 1);
      expect(harness.tripEventRepository.pickupLogCalls, 1);
      expect(harness.tripEventRepository.smsCalls, 1);
    });

    test('manualMarkPickedUp returns failure when usecase throws', () async {
      final harness = _TestHarness()
        ..passengerRepository.throwOnMarkPickedUp = true;
      final vm = harness.createViewModel();

      const passenger = Passenger(
        id: 'p2',
        name: 'Mona',
        phone: '+202222222222',
        address: 'Giza',
        pickupTime: '08:00',
        updatedAtMillis: 1,
      );

      final result = await vm.manualMarkPickedUp(passenger);

      expect(result, 'driver.manual_pickup_failed');
      expect(vm.isManualPickupInProgress('p2'), isFalse);
    });

    test(
      'startTracking sets location error when permission is denied',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = false;
        final vm = harness.createViewModel();

        await vm.startTracking();

        expect(vm.isTracking, isFalse);
        expect(vm.trackingError, 'driver.location_error');
      },
    );

    test(
      'startTracking clears previous trackingError after later success',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = false;
        final vm = harness.createViewModel();

        await vm.startTracking();
        expect(vm.trackingError, 'driver.location_error');

        harness.locationService.hasPermission = true;
        await vm.startTracking();

        expect(vm.isTracking, isTrue);
        expect(vm.trackingError, isNull);

        vm.dispose();
        harness.dispose();
      },
    );

    test(
      'startTracking enables tracking and reacts to position stream error',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = true;
        final vm = harness.createViewModel();

        await vm.startTracking();

        expect(vm.isTracking, isTrue);
        expect(vm.trackingError, isNull);

        harness.locationService.emitError(Exception('location stream failed'));
        await Future<void>.delayed(Duration.zero);

        expect(vm.isTracking, isFalse);
        expect(vm.trackingError, 'driver.location_error');

        vm.dispose();
        harness.dispose();
      },
    );

    test(
      'startTracking forwards position updates to location repository',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = true;
        final vm = harness.createViewModel();

        await vm.startTracking();

        harness.locationService.emitPosition(_testPosition());
        await Future<void>.delayed(Duration.zero);

        expect(harness.locationRepository.pushCurrentLocationCalls, 1);

        vm.dispose();
        harness.dispose();
      },
    );

    test('automation gate prevents re-entrant automation runs', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final slowAutomationUseCase = _SlowRunGeofenceAutomationUseCase(
        passengerRepository: harness.passengerRepository,
        tripEventRepository: harness.tripEventRepository,
      );
      final vm = harness.createViewModel(
        runGeofenceAutomationUseCase: slowAutomationUseCase,
      );

      await vm.startTracking();

      harness.locationRepository.emitBusLocation(
        const BusLocation(latitude: 0.0, longitude: 0.0, updatedAtMillis: 1),
      );
      harness.passengerRepository.emitPassengers([
        const Passenger(
          id: 'gate-test',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
          latitude: 0.003,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(slowAutomationUseCase.callCount, 1);

      harness.locationRepository.emitBusLocation(
        const BusLocation(latitude: 0.0, longitude: 0.0, updatedAtMillis: 2),
      );
      harness.passengerRepository.emitPassengers([
        const Passenger(
          id: 'gate-test',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
          latitude: 0.003,
          longitude: 0.0,
          updatedAtMillis: 2,
        ),
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(slowAutomationUseCase.callCount, 1);

      slowAutomationUseCase.completePendingRun();
      await Future<void>.delayed(Duration.zero);

      harness.locationRepository.emitBusLocation(
        const BusLocation(latitude: 0.0, longitude: 0.0, updatedAtMillis: 3),
      );
      harness.passengerRepository.emitPassengers([
        const Passenger(
          id: 'gate-test',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
          latitude: 0.003,
          longitude: 0.0,
          updatedAtMillis: 3,
        ),
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(slowAutomationUseCase.callCount, 2);

      slowAutomationUseCase.completePendingRun();
      await Future<void>.delayed(Duration.zero);

      vm.dispose();
      harness.dispose();
    });

    test(
      'startTracking triggers approaching automation when streams update',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = true;
        final vm = harness.createViewModel();

        final now = DateTime.now();
        final currentMinute = now.hour * 60 + now.minute;
        final pickupMinute = currentMinute + 5;
        final pickupHourText = ((pickupMinute ~/ 60) % 24).toString().padLeft(
          2,
          '0',
        );
        final pickupMinuteText = (pickupMinute % 60).toString().padLeft(2, '0');

        await vm.startTracking();

        harness.locationRepository.emitBusLocation(
          BusLocation(
            latitude: 0.0,
            longitude: 0.0,
            updatedAtMillis: now.millisecondsSinceEpoch,
          ),
        );
        harness.passengerRepository.emitPassengers([
          Passenger(
            id: 'p-approach',
            name: 'Ali',
            phone: '+201111111111',
            address: 'Cairo',
            pickupTime: '$pickupHourText:$pickupMinuteText',
            latitude: 0.018,
            longitude: 0.0,
            updatedAtMillis: 1,
          ),
        ]);

        await Future<void>.delayed(Duration.zero);

        expect(harness.passengerRepository.updateGeofenceCalls, 1);
        expect(harness.passengerRepository.lastGeofenceState, 'approaching');
        expect(harness.tripEventRepository.pickupLogCalls, 1);
        expect(harness.tripEventRepository.smsCalls, 1);

        vm.dispose();
        harness.dispose();
      },
    );

    test(
      'startTracking triggers pickup automation after leaving pickup zone',
      () async {
        final harness = _TestHarness()..locationService.hasPermission = true;
        final vm = harness.createViewModel();

        final now = DateTime.now();
        final currentMinute = now.hour * 60 + now.minute;
        final pickupMinute = currentMinute + 4;
        final pickupHourText = ((pickupMinute ~/ 60) % 24).toString().padLeft(
          2,
          '0',
        );
        final pickupMinuteText = (pickupMinute % 60).toString().padLeft(2, '0');

        await vm.startTracking();

        harness.locationRepository.emitBusLocation(
          BusLocation(
            latitude: 0.0,
            longitude: 0.0,
            updatedAtMillis: now.millisecondsSinceEpoch,
          ),
        );
        harness.passengerRepository.emitPassengers([
          Passenger(
            id: 'p-pickup',
            name: 'Mona',
            phone: '+202222222222',
            address: 'Giza',
            pickupTime: '$pickupHourText:$pickupMinuteText',
            latitude: 0.0005,
            longitude: 0.0,
            updatedAtMillis: 1,
          ),
        ]);

        await Future<void>.delayed(Duration.zero);

        expect(harness.passengerRepository.markPickedUpCalls, 0);
        expect(harness.tripEventRepository.pickupLogCalls, 1);
        expect(harness.tripEventRepository.smsCalls, 1);

        harness.locationRepository.emitBusLocation(
          BusLocation(
            latitude: 0.01,
            longitude: 0.0,
            updatedAtMillis: now
                .add(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
          ),
        );
        harness.passengerRepository.emitPassengers([
          Passenger(
            id: 'p-pickup',
            name: 'Mona',
            phone: '+202222222222',
            address: 'Giza',
            pickupTime: '$pickupHourText:$pickupMinuteText',
            latitude: 0.0005,
            longitude: 0.0,
            updatedAtMillis: 1,
          ),
        ]);

        await Future<void>.delayed(Duration.zero);

        expect(harness.passengerRepository.markPickedUpCalls, 1);
        expect(harness.passengerRepository.lastMarkedPassengerId, 'p-pickup');
        expect(harness.tripEventRepository.pickupLogCalls, 2);
        expect(harness.tripEventRepository.smsCalls, 1);

        vm.dispose();
        harness.dispose();
      },
    );

    test('sortPassengers uses injected sort use case contract', () {
      final harness = _TestHarness();
      final vm = harness.createViewModel();
      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );

      const passengers = [
        Passenger(
          id: 'b',
          name: 'B',
          phone: '1',
          address: 'a',
          pickupTime: '07:30',
          updatedAtMillis: 1,
        ),
        Passenger(
          id: 'a',
          name: 'A',
          phone: '2',
          address: 'b',
          pickupTime: '07:30',
          updatedAtMillis: 1,
        ),
      ];

      final sorted = vm.sortPassengers(passengers, bus);
      expect(sorted.map((p) => p.name), ['A', 'B']);
    });

    test('onPassengerSchedulesSnapshot keeps only latest 8 alerts', () {
      final harness = _TestHarness();
      final vm = harness.createViewModel();

      vm.onPassengerSchedulesSnapshot(const [
        Passenger(
          id: 'p1',
          name: 'Ali',
          phone: '1',
          address: 'Cairo',
          pickupTime: '07:00',
          returnTime: '14:00',
          updatedAtMillis: 1,
        ),
      ]);

      for (var i = 1; i <= 12; i++) {
        final nextHour = (7 + i).toString().padLeft(2, '0');
        final nextReturnHour = (14 + i).toString().padLeft(2, '0');
        vm.onPassengerSchedulesSnapshot([
          Passenger(
            id: 'p1',
            name: 'Ali',
            phone: '1',
            address: 'Cairo',
            pickupTime: '$nextHour:00',
            returnTime: '$nextReturnHour:00',
            updatedAtMillis: 1 + i,
          ),
        ]);
      }

      expect(vm.scheduleAlerts.length, 8);
      expect(vm.scheduleAlerts.first.currentPickup, '19:00');
      expect(vm.scheduleAlerts.last.currentPickup, '12:00');
    });

    test('dispose stops reacting to stream emissions', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final vm = harness.createViewModel();

      await vm.startTracking();
      vm.dispose();

      harness.locationService.emitPosition(_testPosition());
      harness.locationRepository.emitBusLocation(
        const BusLocation(latitude: 0.0, longitude: 0.0, updatedAtMillis: 1),
      );
      harness.passengerRepository.emitPassengers([
        const Passenger(
          id: 'post-dispose',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
          latitude: 0.003,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(harness.locationRepository.pushCurrentLocationCalls, 0);
      expect(harness.passengerRepository.updateGeofenceCalls, 0);
      expect(harness.passengerRepository.markPickedUpCalls, 0);

      harness.dispose();
    });

    test('startTracking is idempotent when called twice', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final vm = harness.createViewModel();

      await vm.startTracking();
      await vm.startTracking();

      expect(harness.locationService.ensurePermissionCalls, 1);
      expect(harness.locationService.watchPositionCalls, 1);
      expect(harness.locationRepository.watchBusLocationCalls, 1);
      expect(harness.passengerRepository.watchPassengersCalls, 1);

      harness.locationService.emitPosition(_testPosition());
      await Future<void>.delayed(Duration.zero);
      expect(harness.locationRepository.pushCurrentLocationCalls, 1);

      vm.dispose();
      harness.dispose();
    });

    test('setTrackingEnabled(false) stops all active streams', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final vm = harness.createViewModel();

      await vm.startTracking();
      expect(vm.isTrackingEnabled, isTrue);
      expect(vm.isTracking, isTrue);

      await vm.setTrackingEnabled(false);

      expect(vm.isTrackingEnabled, isFalse);
      expect(vm.isTracking, isFalse);

      harness.locationService.emitPosition(_testPosition());
      await Future<void>.delayed(Duration.zero);
      expect(harness.locationRepository.pushCurrentLocationCalls, 0);

      vm.dispose();
      harness.dispose();
    });

    test('setTrackingEnabled(true) starts tracking again', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final vm = harness.createViewModel();

      await vm.setTrackingEnabled(false);
      expect(vm.isTracking, isFalse);

      await vm.setTrackingEnabled(true);

      expect(vm.isTrackingEnabled, isTrue);
      expect(vm.isTracking, isTrue);
      expect(harness.locationService.ensurePermissionCalls, 1);

      vm.dispose();
      harness.dispose();
    });

    test('startTracking does nothing while tracking is disabled', () async {
      final harness = _TestHarness()..locationService.hasPermission = true;
      final vm = harness.createViewModel();

      await vm.setTrackingEnabled(false);
      await vm.startTracking();

      expect(vm.isTracking, isFalse);
      expect(harness.locationService.ensurePermissionCalls, 0);
      expect(harness.locationService.watchPositionCalls, 0);

      vm.dispose();
      harness.dispose();
    });

    test('updatePassengerSchedule updates repository with new times', () async {
      final harness = _TestHarness();
      final vm = harness.createViewModel();
      const passenger = Passenger(
        id: 'p-schedule-1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '07:30',
        returnTime: '14:00',
        latitude: 30.0,
        longitude: 31.0,
        updatedAtMillis: 1,
      );

      final result = await vm.updatePassengerSchedule(
        passenger: passenger,
        pickupTime: '08:15',
        returnTime: '15:30',
      );

      expect(result, isNull);
      expect(harness.passengerRepository.upsertPassengerCalls, 1);
      expect(harness.passengerRepository.lastUpsertPickupTime, '08:15');
      expect(harness.passengerRepository.lastUpsertReturnTime, '15:30');
      expect(vm.isScheduleUpdateInProgress(passenger.id), isFalse);
    });

    test(
      'updatePassengerSchedule returns failure when repository throws',
      () async {
        final harness = _TestHarness()
          ..passengerRepository.throwOnUpsert = true;
        final vm = harness.createViewModel();
        const passenger = Passenger(
          id: 'p-schedule-2',
          name: 'Mona',
          phone: '+202222222222',
          address: 'Giza',
          pickupTime: '07:30',
          returnTime: '14:00',
          updatedAtMillis: 1,
        );

        final result = await vm.updatePassengerSchedule(
          passenger: passenger,
          pickupTime: '08:00',
          returnTime: '15:00',
        );

        expect(result, 'driver.schedule_update_failed');
        expect(vm.isScheduleUpdateInProgress(passenger.id), isFalse);
      },
    );
  });
}

class _TestHarness {
  final locationService = _FakeDeviceLocationService();
  final locationRepository = _FakeBusLocationRepository();
  final passengerRepository = _FakePassengerRepository();
  final tripEventRepository = _FakeTripEventRepository();

  DriverLiveViewModel createViewModel({
    RunGeofenceAutomationUseCase? runGeofenceAutomationUseCase,
  }) {
    const calculateEtaUseCase = CalculateEtaUseCase();
    final sortPassengersUseCase = SortPassengersUseCase(calculateEtaUseCase);
    final manualMarkPickedUpUseCase = ManualMarkPickedUpUseCase(
      passengerRepository: passengerRepository,
      tripEventRepository: tripEventRepository,
    );
    final effectiveRunGeofenceAutomationUseCase =
        runGeofenceAutomationUseCase ??
        RunGeofenceAutomationUseCase(
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
      runGeofenceAutomationUseCase: effectiveRunGeofenceAutomationUseCase,
    );
  }

  void dispose() {
    locationService.dispose();
    locationRepository.dispose();
    passengerRepository.dispose();
  }
}

class _FakeDeviceLocationService implements DeviceLocationService {
  bool hasPermission = true;
  int ensurePermissionCalls = 0;
  int watchPositionCalls = 0;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  @override
  Future<bool> ensurePermission() async {
    ensurePermissionCalls += 1;
    return hasPermission;
  }

  @override
  Stream<Position> watchPosition() {
    watchPositionCalls += 1;
    return _positionController.stream;
  }

  void emitError(Object error) {
    _positionController.addError(error);
  }

  void emitPosition(Position position) {
    _positionController.add(position);
  }

  void dispose() {
    _positionController.close();
  }
}

class _FakeBusLocationRepository implements BusLocationRepository {
  final StreamController<BusLocation?> _busController =
      StreamController<BusLocation?>.broadcast();
  int pushCurrentLocationCalls = 0;
  int watchBusLocationCalls = 0;

  @override
  Future<void> pushCurrentLocation(Position position) async {
    pushCurrentLocationCalls += 1;
  }

  @override
  Stream<BusLocation?> watchBusLocation() {
    watchBusLocationCalls += 1;
    return _busController.stream;
  }

  void emitBusLocation(BusLocation location) {
    _busController.add(location);
  }

  void dispose() {
    _busController.close();
  }
}

class _FakePassengerRepository implements PassengerRepository {
  final StreamController<List<Passenger>> _passengersController =
      StreamController<List<Passenger>>.broadcast();
  bool throwOnMarkPickedUp = false;
  bool throwOnUpsert = false;
  int markPickedUpCalls = 0;
  int watchPassengersCalls = 0;
  int updateGeofenceCalls = 0;
  int upsertPassengerCalls = 0;
  String? lastMarkedPassengerId;
  String? lastGeofenceState;
  String? lastUpsertPickupTime;
  String? lastUpsertReturnTime;

  @override
  Future<void> markPickedUp({
    required String passengerId,
    double? distanceMeters,
  }) async {
    if (throwOnMarkPickedUp) {
      throw StateError('mark failure');
    }
    markPickedUpCalls += 1;
    lastMarkedPassengerId = passengerId;
  }

  @override
  Future<void> updateGeofenceState({
    required String passengerId,
    required String geofenceState,
    required double distanceMeters,
  }) async {
    updateGeofenceCalls += 1;
    lastGeofenceState = geofenceState;
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
    if (throwOnUpsert) {
      throw StateError('upsert failure');
    }
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
  Stream<Passenger?> watchPassengerById(String id) {
    return const Stream<Passenger?>.empty();
  }

  @override
  Stream<List<Passenger>> watchPassengers() {
    watchPassengersCalls += 1;
    return _passengersController.stream;
  }

  void emitPassengers(List<Passenger> passengers) {
    _passengersController.add(passengers);
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
  int pickupLogCalls = 0;
  int smsCalls = 0;

  @override
  Future<void> addPickupLog({
    required String passengerId,
    required String passengerPhone,
    required String type,
    required String message,
    required Map<String, dynamic> payload,
  }) async {
    pickupLogCalls += 1;
  }

  @override
  Future<void> queueSms({
    required String passengerId,
    required String toPhone,
    required String template,
    required Map<String, dynamic> variables,
    required String idempotencyKey,
  }) async {
    smsCalls += 1;
  }
}

class _SlowRunGeofenceAutomationUseCase extends RunGeofenceAutomationUseCase {
  _SlowRunGeofenceAutomationUseCase({
    required super.passengerRepository,
    required super.tripEventRepository,
  });

  int callCount = 0;
  Completer<void>? _currentRun;

  @override
  Future<void> call({
    required BusLocation busLocation,
    required List<Passenger> passengers,
  }) async {
    callCount += 1;
    _currentRun ??= Completer<void>();
    await _currentRun!.future;
    _currentRun = null;
  }

  void completePendingRun() {
    _currentRun?.complete();
  }
}

Position _testPosition() {
  return Position(
    longitude: 31.0,
    latitude: 30.0,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}
