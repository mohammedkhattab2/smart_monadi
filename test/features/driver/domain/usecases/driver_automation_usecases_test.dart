import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/run_geofence_automation_use_case.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

void main() {
  group('ManualMarkPickedUpUseCase', () {
    test('marks picked up and emits log + sms', () async {
      final passengerRepository = _FakePassengerRepository();
      final tripEventRepository = _FakeTripEventRepository();
      final useCase = ManualMarkPickedUpUseCase(
        passengerRepository: passengerRepository,
        tripEventRepository: tripEventRepository,
      );
      const passenger = Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '07:30',
        updatedAtMillis: 1,
      );

      await useCase(passenger);

      expect(passengerRepository.markPickedUpCalls, 1);
      expect(passengerRepository.lastMarkedPassengerId, 'p1');
      expect(tripEventRepository.pickupLogCalls, 1);
      expect(tripEventRepository.smsCalls, 1);
      expect(tripEventRepository.lastSmsTemplate, 'arrival_now');
    });
  });

  group('RunGeofenceAutomationUseCase', () {
    test('approaching passenger updates state and logs once', () async {
      final passengerRepository = _FakePassengerRepository();
      final tripEventRepository = _FakeTripEventRepository();
      final useCase = RunGeofenceAutomationUseCase(
        passengerRepository: passengerRepository,
        tripEventRepository: tripEventRepository,
      );

      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );
      const passenger = Passenger(
        id: 'p1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '07:30',
        latitude: 0.003,
        longitude: 0.0,
        updatedAtMillis: 1,
      );

      await useCase(busLocation: bus, passengers: const [passenger]);
      await useCase(busLocation: bus, passengers: const [passenger]);

      expect(passengerRepository.updateGeofenceCalls, 2);
      expect(passengerRepository.lastGeofenceState, 'approaching');
      expect(tripEventRepository.pickupLogCalls, 1);
      expect(tripEventRepository.smsCalls, 1);
      expect(tripEventRepository.lastSmsTemplate, 'arriving_soon');
    });

    test('pickup radius marks picked up and emits pickup events', () async {
      final passengerRepository = _FakePassengerRepository();
      final tripEventRepository = _FakeTripEventRepository();
      final useCase = RunGeofenceAutomationUseCase(
        passengerRepository: passengerRepository,
        tripEventRepository: tripEventRepository,
      );

      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );
      const passenger = Passenger(
        id: 'p2',
        name: 'Mona',
        phone: '+202222222222',
        address: 'Giza',
        pickupTime: '08:00',
        latitude: 0.0005,
        longitude: 0.0,
        updatedAtMillis: 1,
      );

      await useCase(busLocation: bus, passengers: const [passenger]);

      expect(passengerRepository.markPickedUpCalls, 1);
      expect(passengerRepository.lastMarkedPassengerId, 'p2');
      expect(tripEventRepository.pickupLogCalls, 1);
      expect(tripEventRepository.smsCalls, 1);
      expect(tripEventRepository.lastSmsTemplate, 'arrival_now');
    });
  });
}

class _FakePassengerRepository implements PassengerRepository {
  int markPickedUpCalls = 0;
  int updateGeofenceCalls = 0;
  String? lastMarkedPassengerId;
  String? lastGeofenceState;

  @override
  Future<void> markPickedUp({
    required String passengerId,
    double? distanceMeters,
  }) async {
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
  }) async {}

  @override
  Stream<Passenger?> watchPassengerById(String id) {
    return const Stream<Passenger?>.empty();
  }

  @override
  Stream<List<Passenger>> watchPassengers() {
    return const Stream<List<Passenger>>.empty();
  }

  @override
  Stream<List<PassengerTimelineEvent>> watchPassengerTimeline({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  }) {
    return const Stream<List<PassengerTimelineEvent>>.empty();
  }
}

class _FakeTripEventRepository implements TripEventRepository {
  int pickupLogCalls = 0;
  int smsCalls = 0;
  String? lastSmsTemplate;

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
  }) async {
    smsCalls += 1;
    lastSmsTemplate = template;
  }
}
