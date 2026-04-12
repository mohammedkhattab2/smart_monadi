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
    final normalizedKey = normalizeIdempotencyKeyForDocId(idempotencyKey);
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

  static String normalizeIdempotencyKeyForDocId(String value) {
    final compact = value.trim().toLowerCase();
    if (compact.isEmpty) {
      return 'sms_key_unknown';
    }

    final normalizedBody = compact.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final hashSuffix = _stableHash8(compact);
    final maxBodyLen = 128 - 1 - hashSuffix.length;
    final body = normalizedBody.length <= maxBodyLen
        ? normalizedBody
        : normalizedBody.substring(0, maxBodyLen);

    final composed = '${body}_$hashSuffix';
    if (composed.length <= 128) {
      return composed;
    }

    return composed.substring(0, 128);
  }

  static String _stableHash8(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }
}
