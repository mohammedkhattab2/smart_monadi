import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/run_geofence_automation_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/sort_passengers_use_case.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/domain/services/device_location_service.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class DriverLiveViewModel extends ChangeNotifier {
  DriverLiveViewModel({
    required DeviceLocationService locationService,
    required BusLocationRepository locationRepository,
    required PassengerRepository passengerRepository,
    required CalculateEtaUseCase calculateEtaUseCase,
    required SortPassengersUseCase sortPassengersUseCase,
    required ManualMarkPickedUpUseCase manualMarkPickedUpUseCase,
    required RunGeofenceAutomationUseCase runGeofenceAutomationUseCase,
  }) : _locationService = locationService,
       _locationRepository = locationRepository,
       _passengerRepository = passengerRepository,
       _calculateEtaUseCase = calculateEtaUseCase,
       _sortPassengersUseCase = sortPassengersUseCase,
       _manualMarkPickedUpUseCase = manualMarkPickedUpUseCase,
       _runGeofenceAutomationUseCase = runGeofenceAutomationUseCase;

  final DeviceLocationService _locationService;
  final BusLocationRepository _locationRepository;
  final PassengerRepository _passengerRepository;
  final CalculateEtaUseCase _calculateEtaUseCase;
  final SortPassengersUseCase _sortPassengersUseCase;
  final ManualMarkPickedUpUseCase _manualMarkPickedUpUseCase;
  final RunGeofenceAutomationUseCase _runGeofenceAutomationUseCase;

  bool _isTracking = false;
  String? _trackingError;
  StreamSubscription<dynamic>? _positionSubscription;
  StreamSubscription<BusLocation?>? _busSubscription;
  StreamSubscription<List<Passenger>>? _passengerSubscription;
  bool _isAutomating = false;
  List<Passenger> _latestPassengers = const [];
  BusLocation? _latestBusLocation;
  final Set<String> _manualPickupInProgress = <String>{};
  final Map<String, _PassengerScheduleSnapshot> _knownSchedules =
      <String, _PassengerScheduleSnapshot>{};
  final List<DriverScheduleAlert> _scheduleAlerts = <DriverScheduleAlert>[];

  bool get isTracking => _isTracking;
  String? get trackingError => _trackingError;
  List<DriverScheduleAlert> get scheduleAlerts =>
      List.unmodifiable(_scheduleAlerts);

  Stream<BusLocation?> watchBusLocation() =>
      _locationRepository.watchBusLocation();

  Stream<List<Passenger>> watchPassengers() =>
      _passengerRepository.watchPassengers();

  bool isManualPickupInProgress(String passengerId) {
    return _manualPickupInProgress.contains(passengerId);
  }

  String statusKey(Passenger passenger) {
    if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
      return 'driver.status_picked_up';
    }
    if (passenger.geofenceState == 'approaching') {
      return 'driver.status_approaching';
    }
    return 'driver.status_waiting';
  }

  int statusPriority(Passenger passenger) {
    if (passenger.geofenceState == 'approaching') {
      return 0;
    }
    if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
      return 2;
    }
    return 1;
  }

  int? etaMinutes(BusLocation? busLocation, double? lat, double? lng) {
    return _calculateEtaUseCase(busLocation, lat, lng);
  }

  List<Passenger> sortPassengers(
    List<Passenger> passengers,
    BusLocation? busLocation,
  ) {
    return _sortPassengersUseCase(passengers, busLocation, statusPriority);
  }

  void onPassengerSchedulesSnapshot(List<Passenger> passengers) {
    final activeIds = <String>{};
    for (final passenger in passengers) {
      activeIds.add(passenger.id);

      final current = _PassengerScheduleSnapshot(
        pickupTime: passenger.pickupTime,
        returnTime: passenger.returnTime,
      );
      final previous = _knownSchedules[passenger.id];

      if (previous != null &&
          (previous.pickupTime != current.pickupTime ||
              previous.returnTime != current.returnTime)) {
        _scheduleAlerts.insert(
          0,
          DriverScheduleAlert(
            passengerName: passenger.name,
            previousPickup: previous.pickupTime,
            currentPickup: current.pickupTime,
            previousReturn: previous.returnTime,
            currentReturn: current.returnTime,
          ),
        );
      }

      _knownSchedules[passenger.id] = current;
    }

    _knownSchedules.removeWhere((id, _) => !activeIds.contains(id));
    if (_scheduleAlerts.length > 8) {
      _scheduleAlerts.removeRange(8, _scheduleAlerts.length);
    }
    notifyListeners();
  }

  Future<String?> manualMarkPickedUp(Passenger passenger) async {
    if (_manualPickupInProgress.contains(passenger.id)) {
      return 'driver.manual_pickup_failed';
    }

    _manualPickupInProgress.add(passenger.id);
    notifyListeners();

    try {
      await _manualMarkPickedUpUseCase(passenger);

      return null;
    } catch (_) {
      return 'driver.manual_pickup_failed';
    } finally {
      _manualPickupInProgress.remove(passenger.id);
      notifyListeners();
    }
  }

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
      await _runGeofenceAutomationUseCase(
        busLocation: bus,
        passengers: _latestPassengers,
      );
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

class DriverScheduleAlert {
  const DriverScheduleAlert({
    required this.passengerName,
    required this.previousPickup,
    required this.currentPickup,
    required this.previousReturn,
    required this.currentReturn,
  });

  final String passengerName;
  final String previousPickup;
  final String currentPickup;
  final String previousReturn;
  final String currentReturn;
}

class _PassengerScheduleSnapshot {
  const _PassengerScheduleSnapshot({
    required this.pickupTime,
    required this.returnTime,
  });

  final String pickupTime;
  final String returnTime;
}
