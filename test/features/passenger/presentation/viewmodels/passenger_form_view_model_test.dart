import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/presentation/viewmodels/passenger_form_view_model.dart';

void main() {
  group('PassengerFormViewModel', () {
    test('savePassenger succeeds and resets isSaving', () async {
      final repository = _FakePassengerRepository();
      final viewModel = PassengerFormViewModel.fromRepository(repository);

      final result = await viewModel.savePassenger(
        id: 'p1',
        name: 'Ali',
        phone: '+201111111111',
        address: 'Cairo',
        pickupTime: '07:30',
      );

      expect(result, isTrue);
      expect(viewModel.isSaving, isFalse);
      expect(repository.upsertCalls, 1);
      expect(repository.lastId, 'p1');
    });

    test(
      'savePassenger blocks concurrent second call while first is running',
      () async {
        final repository = _FakePassengerRepository()..holdUpsert = true;
        final viewModel = PassengerFormViewModel.fromRepository(repository);

        final firstFuture = viewModel.savePassenger(
          id: 'p1',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
        );

        await Future<void>.delayed(Duration.zero);
        expect(viewModel.isSaving, isTrue);

        final secondResult = await viewModel.savePassenger(
          id: 'p1',
          name: 'Ali',
          phone: '+201111111111',
          address: 'Cairo',
          pickupTime: '07:30',
        );

        expect(secondResult, isFalse);
        expect(repository.upsertCalls, 1);

        repository.releaseUpsert();
        final firstResult = await firstFuture;

        expect(firstResult, isTrue);
        expect(viewModel.isSaving, isFalse);
      },
    );
  });
}

class _FakePassengerRepository implements PassengerRepository {
  int upsertCalls = 0;
  String? lastId;
  bool holdUpsert = false;
  Completer<void>? _holdCompleter;

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
    upsertCalls += 1;
    lastId = id;
    if (holdUpsert) {
      _holdCompleter ??= Completer<void>();
      await _holdCompleter!.future;
    }
  }

  @override
  Future<void> updatePassengerLocation({
    required String passengerId,
    required double latitude,
    required double longitude,
  }) async {}

  void releaseUpsert() {
    _holdCompleter?.complete();
    _holdCompleter = null;
  }

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
