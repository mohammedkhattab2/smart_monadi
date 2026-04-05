import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/passenger/data/models/passenger_model.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';

class PassengerRepository {
  PassengerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _passengersRef =>
      _firestore.collection('passengers');

  Stream<List<Passenger>> watchPassengers() {
    return _passengersRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PassengerModel.fromFirestore)
              .cast<Passenger>()
              .toList(growable: false),
        );
  }

  Stream<Passenger?> watchPassengerById(String id) {
    return _passengersRef.doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return PassengerModel.fromFirestore(snapshot);
    });
  }

  Future<void> upsertPassenger({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String pickupTime,
    String returnTime = '',
    double? latitude,
    double? longitude,
  }) {
    final model = PassengerModel(
      id: id,
      name: name,
      phone: phone,
      address: address,
      pickupTime: pickupTime,
      returnTime: returnTime,
      latitude: latitude,
      longitude: longitude,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    return _passengersRef
        .doc(id)
        .set(model.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateGeofenceState({
    required String passengerId,
    required String geofenceState,
    required double distanceMeters,
  }) {
    return _passengersRef.doc(passengerId).set({
      'geofenceState': geofenceState,
      'lastDistanceMeters': distanceMeters,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> markPickedUp({
    required String passengerId,
    double? distanceMeters,
  }) {
    final payload = <String, dynamic>{
      'isPickedUp': true,
      'geofenceState': 'picked_up',
      'pickedUpAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    if (distanceMeters != null) {
      payload['lastDistanceMeters'] = distanceMeters;
    }

    return _passengersRef
        .doc(passengerId)
        .set(payload, SetOptions(merge: true));
  }
}
