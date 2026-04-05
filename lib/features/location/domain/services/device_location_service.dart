import 'package:geolocator/geolocator.dart';

abstract class DeviceLocationService {
  Future<bool> ensurePermission();

  Stream<Position> watchPosition();
}
