import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

class SortPassengersUseCase {
  const SortPassengersUseCase(this._calculateEtaUseCase);

  final CalculateEtaUseCase _calculateEtaUseCase;

  List<Passenger> call(
    List<Passenger> passengers,
    BusLocation? busLocation,
    int Function(Passenger passenger) statusPriority,
  ) {
    final sorted = passengers.toList(growable: false);
    sorted.sort((a, b) {
      final statusCompare = statusPriority(a).compareTo(statusPriority(b));
      if (statusCompare != 0) {
        return statusCompare;
      }

      final aEta = _calculateEtaUseCase(busLocation, a.latitude, a.longitude);
      final bEta = _calculateEtaUseCase(busLocation, b.latitude, b.longitude);

      if (aEta == null && bEta == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (aEta == null) {
        return 1;
      }
      if (bEta == null) {
        return -1;
      }
      return aEta.compareTo(bEta);
    });
    return sorted;
  }
}
