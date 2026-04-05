import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';

abstract class BusLocationRepository {
  Stream<BusLocation?> watchBusLocation();

  Future<void> pushCurrentLocation(Position position);
}
