import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/passenger/data/models/passenger_model.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class FirestorePassengerRepository implements PassengerRepository {
  FirestorePassengerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _passengersRef =>
      _firestore.collection('passengers');

  @override
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

  @override
  Stream<Passenger?> watchPassengerById(String id) {
    return _passengersRef.doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return PassengerModel.fromFirestore(snapshot);
    });
  }

  @override
  Stream<List<PassengerTimelineEvent>> watchPassengerTimeline({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('pickup_logs')
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (since != null) {
      query = _firestore
          .collection('pickup_logs')
          .where('passengerId', isEqualTo: passengerId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final createdAtRaw = data['createdAt'];
            return PassengerTimelineEvent(
              id: doc.id,
              type: (data['type'] ?? '').toString(),
              message: (data['message'] ?? '').toString(),
              createdAt: createdAtRaw is Timestamp
                  ? createdAtRaw.toDate().toLocal()
                  : null,
            );
          })
          .toList(growable: false);
    });
  }

  @override
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

  @override
  Future<void> updatePassengerLocation({
    required String passengerId,
    required double latitude,
    required double longitude,
  }) {
    return _passengersRef.doc(passengerId).set({
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  @override
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

  @override
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
