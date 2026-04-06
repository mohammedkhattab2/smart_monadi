import 'package:flutter/foundation.dart';
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
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      timeLimit: const Duration(minutes: 2),
    );

    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Smart Monadi tracking is active',
        notificationText: 'Bus location is being updated in the background.',
        enableWakeLock: true,
      ),
    );

    final appleSettings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );

    final locationSettings = defaultTargetPlatform == TargetPlatform.android
        ? androidSettings
        : defaultTargetPlatform == TargetPlatform.iOS
        ? appleSettings
        : settings;

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
