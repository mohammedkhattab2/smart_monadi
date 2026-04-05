import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_monadi/features/location/data/models/bus_location_model.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';

class BusLocationRepository {
  BusLocationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _firestore.collection('bus_live').doc('current');

  Stream<BusLocation?> watchBusLocation() {
    return _docRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return BusLocationModel.fromFirestore(data);
    });
  }

  Future<void> pushCurrentLocation(Position position) {
    final model = BusLocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      speedMetersPerSecond: position.speed,
    );

    return _docRef.set(model.toFirestore(), SetOptions(merge: true));
  }
}
