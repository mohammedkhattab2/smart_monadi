import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';

class FirestoreTripEventRepository implements TripEventRepository {
  FirestoreTripEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _pickupLogsRef =>
      _firestore.collection('pickup_logs');

  CollectionReference<Map<String, dynamic>> get _smsOutboxRef =>
      _firestore.collection('sms_outbox');

  @override
  Future<void> addPickupLog({
    required String passengerId,
    required String passengerPhone,
    required String type,
    required String message,
    required Map<String, dynamic> payload,
  }) {
    return _pickupLogsRef.add({
      'passengerId': passengerId,
      'passengerPhone': passengerPhone,
      'type': type,
      'message': message,
      'payload': payload,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Future<void> queueSms({
    required String passengerId,
    required String toPhone,
    required String template,
    required Map<String, dynamic> variables,
  }) {
    return _smsOutboxRef.add({
      'passengerId': passengerId,
      'toPhone': toPhone,
      'template': template,
      'variables': variables,
      'status': 'pending',
      'createdAt': Timestamp.now(),
      'nextRetryAt': Timestamp.now(),
      'attempts': 0,
    });
  }
}
