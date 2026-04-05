import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/sort_passengers_use_case.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

void main() {
  group('CalculateEtaUseCase', () {
    const useCase = CalculateEtaUseCase();

    test('returns null when location inputs are incomplete', () {
      const bus = BusLocation(
        latitude: 30.0,
        longitude: 31.0,
        updatedAtMillis: 1,
      );

      expect(useCase(null, 30.0, 31.0), isNull);
      expect(useCase(bus, null, 31.0), isNull);
      expect(useCase(bus, 30.0, null), isNull);
    });

    test('returns ceil(minutes) based on configured average speed', () {
      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );

      final eta = useCase(bus, 0.01, 0.0);

      expect(eta, 3);
    });
  });

  group('SortPassengersUseCase', () {
    const calculateEtaUseCase = CalculateEtaUseCase();
    const sortUseCase = SortPassengersUseCase(calculateEtaUseCase);

    int statusPriority(Passenger passenger) {
      if (passenger.geofenceState == 'approaching') {
        return 0;
      }
      if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
        return 2;
      }
      return 1;
    }

    test('sorts by status first then ETA inside same status', () {
      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );

      const passengers = [
        Passenger(
          id: 'waiting-far',
          name: 'Waiting Far',
          phone: '1',
          address: 'a',
          pickupTime: '07:30',
          latitude: 0.02,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
        Passenger(
          id: 'waiting-near',
          name: 'Waiting Near',
          phone: '2',
          address: 'b',
          pickupTime: '07:30',
          latitude: 0.01,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
        Passenger(
          id: 'approaching',
          name: 'Approaching',
          phone: '3',
          address: 'c',
          pickupTime: '07:30',
          geofenceState: 'approaching',
          latitude: 0.03,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
        Passenger(
          id: 'picked',
          name: 'Picked',
          phone: '4',
          address: 'd',
          pickupTime: '07:30',
          geofenceState: 'picked_up',
          latitude: 0.005,
          longitude: 0.0,
          updatedAtMillis: 1,
        ),
      ];

      final sorted = sortUseCase(passengers, bus, statusPriority);

      expect(sorted.map((p) => p.id), [
        'approaching',
        'waiting-near',
        'waiting-far',
        'picked',
      ]);
    });

    test('sorts by name when ETA is unavailable for both', () {
      const bus = BusLocation(
        latitude: 0.0,
        longitude: 0.0,
        updatedAtMillis: 1,
      );
      const passengers = [
        Passenger(
          id: 'z',
          name: 'Zed',
          phone: '1',
          address: 'a',
          pickupTime: '07:30',
          updatedAtMillis: 1,
        ),
        Passenger(
          id: 'a',
          name: 'Adam',
          phone: '2',
          address: 'b',
          pickupTime: '07:30',
          updatedAtMillis: 1,
        ),
      ];

      final sorted = sortUseCase(passengers, bus, statusPriority);

      expect(sorted.map((p) => p.name), ['Adam', 'Zed']);
    });
  });
}
