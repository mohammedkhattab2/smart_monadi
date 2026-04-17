import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

void main() {
  group('ManualMarkPickedUpUseCase', () {
    test('succeeds even if log and sms side effects fail', () async {
      final passengerRepository = _FakePassengerRepository();
      final tripEventRepository = _FailingTripEventRepository();
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
      expect(tripEventRepository.addPickupLogCalls, 1);
      expect(tripEventRepository.queueSmsCalls, 1);
    });

    test('skips sms when phone is empty', () async {
      final passengerRepository = _FakePassengerRepository();
      final tripEventRepository = _FailingTripEventRepository();
      final useCase = ManualMarkPickedUpUseCase(
        passengerRepository: passengerRepository,
        tripEventRepository: tripEventRepository,
      );

      const passenger = Passenger(
        id: 'p2',
        name: 'Sara',
        phone: '   ',
        address: 'Giza',
        pickupTime: '07:30',
        updatedAtMillis: 1,
      );

      await useCase(passenger);

      expect(passengerRepository.markPickedUpCalls, 1);
      expect(tripEventRepository.addPickupLogCalls, 1);
      expect(tripEventRepository.queueSmsCalls, 0);
    });
  });
}

class _FakePassengerRepository implements PassengerRepository {
  int markPickedUpCalls = 0;
  String? lastMarkedPassengerId;

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
  }) async {}

  @override
  Future<void> updatePassengerLocation({
    required String passengerId,
    required double latitude,
    required double longitude,
  }) async {}

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
  Stream<List<PassengerTimelineEvent>> watchPassengerTimeline({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  }) {
    return const Stream<List<PassengerTimelineEvent>>.empty();
  }

  @override
  Stream<List<Passenger>> watchPassengers() {
    return const Stream<List<Passenger>>.empty();
  }
}

class _FailingTripEventRepository implements TripEventRepository {
  int addPickupLogCalls = 0;
  int queueSmsCalls = 0;

  @override
  Future<void> addPickupLog({
    required String passengerId,
    required String passengerPhone,
    required String type,
    required String message,
    required Map<String, dynamic> payload,
  }) async {
    addPickupLogCalls += 1;
    throw Exception('log write failed');
  }

  @override
  Future<void> queueSms({
    required String passengerId,
    required String toPhone,
    required String template,
    required Map<String, dynamic> variables,
    required String idempotencyKey,
  }) async {
    queueSmsCalls += 1;
    throw Exception('sms queue failed');
  }
}
