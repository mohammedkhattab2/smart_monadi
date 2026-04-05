import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';

class BusLocationModel extends BusLocation {
  const BusLocationModel({
    required super.latitude,
    required super.longitude,
    required super.updatedAtMillis,
    super.speedMetersPerSecond,
  });

  factory BusLocationModel.fromFirestore(Map<String, dynamic> data) {
    final updatedAt = data['updatedAt'] as Timestamp?;
    return BusLocationModel(
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      updatedAtMillis: updatedAt?.millisecondsSinceEpoch ?? 0,
      speedMetersPerSecond: (data['speedMetersPerSecond'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speedMetersPerSecond': speedMetersPerSecond,
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(updatedAtMillis),
    };
  }
}
