import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/location/domain/services/device_location_service.dart';

class GeolocatorDeviceLocationService implements DeviceLocationService {
  @override
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  @override
  Stream<Position> watchPosition() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
