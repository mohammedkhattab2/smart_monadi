import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';

abstract class PassengerRepository {
  Stream<List<Passenger>> watchPassengers();

  Stream<Passenger?> watchPassengerById(String id);

  Stream<List<PassengerTimelineEvent>> watchPassengerTimeline({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  });

  Future<void> upsertPassenger({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String pickupTime,
    String returnTime = '',
    double? latitude,
    double? longitude,
  });

  Future<void> updateGeofenceState({
    required String passengerId,
    required String geofenceState,
    required double distanceMeters,
  });

  Future<void> markPickedUp({
    required String passengerId,
    double? distanceMeters,
  });
}
