import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class FirestoreOperationsRepository implements OperationsRepository {
  FirestoreOperationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _normalizeIdempotencyPart(String value) {
    final compact = value.trim().toLowerCase();
    if (compact.isEmpty) {
      return 'na';
    }
    return compact.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  String _buildOpsTestIdempotencyKey({
    required String phone,
    required String template,
  }) {
    final minuteBucket = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 60000;
    final safePhone = _normalizeIdempotencyPart(phone);
    final safeTemplate = _normalizeIdempotencyPart(template);
    return 'ops_test_${safePhone}_${safeTemplate}_$minuteBucket';
  }

  String _buildDeadLetterRequeueIdempotencyKey(String deadLetterId) {
    final safeDeadLetterId = _normalizeIdempotencyPart(deadLetterId);
    return 'dead_letter_requeue_$safeDeadLetterId';
  }

  @override
  Stream<OperationsMetrics> watchMetricsForDay(String dayKey) {
    return _firestore.collection('sms_metrics').doc(dayKey).snapshots().map((
      doc,
    ) {
      final data = doc.data() ?? const <String, dynamic>{};
      return OperationsMetrics(
        sent: (data['sentCount'] as num?)?.toInt() ?? 0,
        failed: (data['failedCount'] as num?)?.toInt() ?? 0,
        failedPermanent: (data['failedPermanentCount'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Stream<List<OperationsDeliveryEvent>> watchDeliveryEvents({
    DateTime? since,
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('sms_delivery_events')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (since != null) {
      query = _firestore
          .collection('sms_delivery_events')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final createdAtRaw = data['createdAt'];
            return OperationsDeliveryEvent(
              id: doc.id,
              type: (data['type'] ?? '').toString(),
              messageId: (data['messageId'] ?? '').toString(),
              createdAt: createdAtRaw is Timestamp
                  ? createdAtRaw.toDate().toLocal()
                  : null,
              payload: (data['payload'] is Map)
                  ? (data['payload'] as Map).map(
                      (k, v) => MapEntry(k.toString(), v),
                    )
                  : const <String, dynamic>{},
            );
          })
          .toList(growable: false);
    });
  }

  @override
  Stream<List<OperationsDeadLetter>> watchDeadLetters({int limit = 10}) {
    return _firestore
        .collection('sms_outbox_dead_letter')
        .orderBy('movedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                final movedAtRaw = data['movedAt'];
                final originalPayloadRaw = data['originalPayload'];

                return OperationsDeadLetter(
                  id: doc.id,
                  toPhone: (data['toPhone'] ?? '').toString(),
                  attempts: (data['attempts'] as num?)?.toInt() ?? 0,
                  reason: (data['reason'] ?? '').toString(),
                  movedAt: movedAtRaw is Timestamp
                      ? movedAtRaw.toDate().toLocal()
                      : null,
                  errorUserMessage: (data['errorUserMessage'] ?? '').toString(),
                  errorMessage: (data['errorMessage'] ?? '').toString(),
                  originalPayload: originalPayloadRaw is Map
                      ? originalPayloadRaw.map(
                          (k, v) => MapEntry(k.toString(), v),
                        )
                      : const <String, dynamic>{},
                );
              })
              .toList(growable: false);
        });
  }

  @override
  Future<void> enqueueTestSms({
    required String phone,
    required String template,
    required String name,
    required String pickupTime,
  }) {
    final idempotencyKey = _buildOpsTestIdempotencyKey(
      phone: phone,
      template: template,
    );

    return _firestore.collection('sms_outbox').add({
      'passengerId': 'manual-test',
      'toPhone': phone,
      'template': template,
      'variables': {'name': name, 'pickupTime': pickupTime},
      'idempotencyKey': idempotencyKey,
      'status': 'pending',
      'attempts': 0,
      'createdAt': Timestamp.now(),
      'nextRetryAt': Timestamp.now(),
    });
  }

  @override
  Future<void> requeueDeadLetter(OperationsDeadLetter deadLetter) async {
    final originalPayload = deadLetter.originalPayload;
    final toPhone = (originalPayload['toPhone'] ?? deadLetter.toPhone)
        .toString()
        .trim();
    final template = (originalPayload['template'] ?? 'arriving_soon')
        .toString();
    final passengerId = (originalPayload['passengerId'] ?? 'manual-retry')
        .toString();
    final rawVariables = originalPayload['variables'] ?? const {};
    final variables = rawVariables is Map
        ? rawVariables.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const <String, String>{};

    final idempotencyKey = _buildDeadLetterRequeueIdempotencyKey(deadLetter.id);

    await _firestore.collection('sms_outbox').add({
      'passengerId': passengerId,
      'toPhone': toPhone,
      'template': template,
      'variables': variables,
      'idempotencyKey': idempotencyKey,
      'status': 'pending',
      'attempts': 0,
      'createdAt': Timestamp.now(),
      'nextRetryAt': Timestamp.now(),
      'retrySource': 'dead_letter_manual',
      'deadLetterId': deadLetter.id,
    });

    await _firestore
        .collection('sms_outbox_dead_letter')
        .doc(deadLetter.id)
        .set({
          'lastRequeuedAt': Timestamp.now(),
          'requeueCount': FieldValue.increment(1),
        }, SetOptions(merge: true));

    await addDeliveryEvent(
      messageId: deadLetter.id,
      type: 'requeued_manual',
      payload: {
        'source': 'operations_dashboard',
        'toPhone': toPhone,
        'template': template,
      },
    );
  }

  @override
  Future<void> addDeliveryEvent({
    required String messageId,
    required String type,
    required Map<String, dynamic> payload,
  }) {
    return _firestore.collection('sms_delivery_events').add({
      'messageId': messageId,
      'type': type,
      'payload': payload,
      'createdAt': Timestamp.now(),
    });
  }
}
