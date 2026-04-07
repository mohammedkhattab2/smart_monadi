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
    required String idempotencyKey,
  }) async {
    final normalizedKey = _normalizeIdempotencyKey(idempotencyKey);
    final docRef = _smsOutboxRef.doc(normalizedKey);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(docRef);
      if (existing.exists) {
        return;
      }

      tx.set(docRef, {
        'passengerId': passengerId,
        'toPhone': toPhone,
        'template': template,
        'variables': variables,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'nextRetryAt': Timestamp.now(),
        'attempts': 0,
        'idempotencyKey': normalizedKey,
      });
    });
  }

  String _normalizeIdempotencyKey(String value) {
    final compact = value.trim().toLowerCase();
    if (compact.isEmpty) {
      return 'sms_key_unknown';
    }

    final normalized = compact.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    if (normalized.length <= 128) {
      return normalized;
    }
    return normalized.substring(0, 128);
  }
}
