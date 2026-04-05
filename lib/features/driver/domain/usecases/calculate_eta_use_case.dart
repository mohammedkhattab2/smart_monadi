import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';

class CalculateEtaUseCase {
  const CalculateEtaUseCase();

  int? call(BusLocation? busLocation, double? lat, double? lng) {
    if (busLocation == null || lat == null || lng == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      busLocation.latitude,
      busLocation.longitude,
      lat,
      lng,
    );
    const averageSpeedMetersPerMinute = 500.0;
    return (distanceMeters / averageSpeedMetersPerMinute).ceil();
  }
}
