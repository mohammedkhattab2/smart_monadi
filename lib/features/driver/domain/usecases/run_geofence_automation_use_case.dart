import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class RunGeofenceAutomationUseCase {
  RunGeofenceAutomationUseCase({
    required PassengerRepository passengerRepository,
    required TripEventRepository tripEventRepository,
  }) : _passengerRepository = passengerRepository,
       _tripEventRepository = tripEventRepository;

  final PassengerRepository _passengerRepository;
  final TripEventRepository _tripEventRepository;
  final Set<String> _approachLogged = <String>{};

  static const double _approachRadiusMeters = 450;
  static const double _pickupRadiusMeters = 120;

  Future<void> call({
    required BusLocation busLocation,
    required List<Passenger> passengers,
  }) async {
    for (final passenger in passengers) {
      final lat = passenger.latitude;
      final lng = passenger.longitude;
      if (lat == null || lng == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        busLocation.latitude,
        busLocation.longitude,
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
            'busLat': busLocation.latitude,
            'busLng': busLocation.longitude,
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
              'busLat': busLocation.latitude,
              'busLng': busLocation.longitude,
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
  }
}
