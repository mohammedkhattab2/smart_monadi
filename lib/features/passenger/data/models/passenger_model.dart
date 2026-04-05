import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

class PassengerModel extends Passenger {
  const PassengerModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.address,
    required super.pickupTime,
    super.returnTime,
    super.latitude,
    super.longitude,
    super.isPickedUp,
    super.geofenceState,
    super.lastDistanceMeters,
    required super.updatedAtMillis,
  });

  factory PassengerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final updatedAt = data['updatedAt'] as Timestamp?;

    return PassengerModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      pickupTime: (data['pickupTime'] ?? '').toString(),
      returnTime: (data['returnTime'] ?? '').toString(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isPickedUp: (data['isPickedUp'] as bool?) ?? false,
      geofenceState: (data['geofenceState'] ?? 'idle').toString(),
      lastDistanceMeters: (data['lastDistanceMeters'] as num?)?.toDouble(),
      updatedAtMillis: updatedAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'pickupTime': pickupTime,
      'returnTime': returnTime,
      'latitude': latitude,
      'longitude': longitude,
      'isPickedUp': isPickedUp,
      'geofenceState': geofenceState,
      'lastDistanceMeters': lastDistanceMeters,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(updatedAtMillis),
    };
  }
}
