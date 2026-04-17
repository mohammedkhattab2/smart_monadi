import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class ManualMarkPickedUpUseCase {
  const ManualMarkPickedUpUseCase({
    required PassengerRepository passengerRepository,
    required TripEventRepository tripEventRepository,
  }) : _passengerRepository = passengerRepository,
       _tripEventRepository = tripEventRepository;

  final PassengerRepository _passengerRepository;
  final TripEventRepository _tripEventRepository;

  Future<void> call(Passenger passenger) async {
    await _passengerRepository.markPickedUp(passengerId: passenger.id);

    try {
      await _tripEventRepository.addPickupLog(
        passengerId: passenger.id,
        passengerPhone: passenger.phone,
        type: 'picked_up_manual',
        message: 'Passenger manually marked as picked up by driver',
        payload: {'source': 'driver_manual_action', 'name': passenger.name},
      );
    } catch (_) {
      // Side-effects must not block pickup confirmation success.
    }

    final phone = passenger.phone.trim();
    if (phone.isEmpty) {
      return;
    }

    try {
      await _tripEventRepository.queueSms(
        passengerId: passenger.id,
        toPhone: phone,
        template: 'arrival_now',
        variables: {'name': passenger.name, 'pickupTime': passenger.pickupTime},
        idempotencyKey: _buildManualArrivalSmsKey(passenger),
      );
    } catch (_) {
      // Side-effects must not block pickup confirmation success.
    }
  }

  String _buildManualArrivalSmsKey(Passenger passenger) {
    final pickup = passenger.pickupTime.trim().isEmpty
        ? 'unscheduled'
        : passenger.pickupTime.trim();
    return 'manual_arrival_${passenger.id}_$pickup';
  }
}
