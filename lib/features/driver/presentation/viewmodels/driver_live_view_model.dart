import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/automation/data/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/location/data/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/data/services/device_location_service.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/data/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

class DriverLiveViewModel extends ChangeNotifier {
  DriverLiveViewModel({
    required DeviceLocationService locationService,
    required BusLocationRepository locationRepository,
    required PassengerRepository passengerRepository,
    required TripEventRepository tripEventRepository,
  }) : _locationService = locationService,
       _locationRepository = locationRepository,
       _passengerRepository = passengerRepository,
       _tripEventRepository = tripEventRepository;

  final DeviceLocationService _locationService;
  final BusLocationRepository _locationRepository;
  final PassengerRepository _passengerRepository;
  final TripEventRepository _tripEventRepository;

  bool _isTracking = false;
  String? _trackingError;
  StreamSubscription<dynamic>? _positionSubscription;
  StreamSubscription<BusLocation?>? _busSubscription;
  StreamSubscription<List<Passenger>>? _passengerSubscription;
  final Set<String> _approachLogged = <String>{};
  bool _isAutomating = false;
  List<Passenger> _latestPassengers = const [];
  BusLocation? _latestBusLocation;

  static const double _approachRadiusMeters = 450;
  static const double _pickupRadiusMeters = 120;

  bool get isTracking => _isTracking;
  String? get trackingError => _trackingError;

  Stream<BusLocation?> watchBusLocation() =>
      _locationRepository.watchBusLocation();

  Future<void> startTracking() async {
    if (_isTracking) {
      return;
    }

    final hasPermission = await _locationService.ensurePermission();
    if (!hasPermission) {
      _trackingError = 'driver.location_error';
      notifyListeners();
      return;
    }

    _trackingError = null;
    _isTracking = true;
    notifyListeners();

    _busSubscription = _locationRepository.watchBusLocation().listen((
      location,
    ) {
      _latestBusLocation = location;
      _runAutomation();
    });

    _passengerSubscription = _passengerRepository.watchPassengers().listen((
      items,
    ) {
      _latestPassengers = items;
      _runAutomation();
    });

    _positionSubscription = _locationService.watchPosition().listen(
      _locationRepository.pushCurrentLocation,
      onError: (_) {
        _trackingError = 'driver.location_error';
        notifyListeners();
      },
    );
  }

  Future<void> _runAutomation() async {
    if (_isAutomating) {
      return;
    }

    final bus = _latestBusLocation;
    if (bus == null || _latestPassengers.isEmpty) {
      return;
    }

    _isAutomating = true;
    try {
      for (final passenger in _latestPassengers) {
        final lat = passenger.latitude;
        final lng = passenger.longitude;
        if (lat == null || lng == null) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          bus.latitude,
          bus.longitude,
          lat,
          lng,
        );

        if (!passenger.isPickedUp && distance <= _pickupRadiusMeters) {
          await _passengerRepository.markPickedUp(
            passengerId: passenger.id,
            distanceMeters: distance,
          );

          await _tripEventRepository.addPickupLog(
            passengerId: passenger.id,
            passengerPhone: passenger.phone,
            type: 'picked_up_auto',
            message: 'Passenger automatically marked as picked up',
            payload: {
              'distanceMeters': distance,
              'busLat': bus.latitude,
              'busLng': bus.longitude,
              'passengerLat': lat,
              'passengerLng': lng,
            },
          );

          await _tripEventRepository.queueSms(
            passengerId: passenger.id,
            toPhone: passenger.phone,
            template: 'arrival_now',
            variables: {
              'name': passenger.name,
              'pickupTime': passenger.pickupTime,
            },
          );

          _approachLogged.remove(passenger.id);
          continue;
        }

        if (!passenger.isPickedUp && distance <= _approachRadiusMeters) {
          await _passengerRepository.updateGeofenceState(
            passengerId: passenger.id,
            geofenceState: 'approaching',
            distanceMeters: distance,
          );

          if (!_approachLogged.contains(passenger.id)) {
            _approachLogged.add(passenger.id);

            await _tripEventRepository.addPickupLog(
              passengerId: passenger.id,
              passengerPhone: passenger.phone,
              type: 'approaching',
              message: 'Bus entered passenger approach zone',
              payload: {
                'distanceMeters': distance,
                'busLat': bus.latitude,
                'busLng': bus.longitude,
                'passengerLat': lat,
                'passengerLng': lng,
              },
            );

            await _tripEventRepository.queueSms(
              passengerId: passenger.id,
              toPhone: passenger.phone,
              template: 'arriving_soon',
              variables: {
                'name': passenger.name,
                'pickupTime': passenger.pickupTime,
              },
            );
          }
          continue;
        }

        if (!passenger.isPickedUp && distance > _approachRadiusMeters) {
          await _passengerRepository.updateGeofenceState(
            passengerId: passenger.id,
            geofenceState: 'idle',
            distanceMeters: distance,
          );
          _approachLogged.remove(passenger.id);
        }
      }
    } finally {
      _isAutomating = false;
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _busSubscription?.cancel();
    _passengerSubscription?.cancel();
    super.dispose();
  }
}
