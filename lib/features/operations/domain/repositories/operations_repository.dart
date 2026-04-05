import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';

abstract class OperationsRepository {
  Stream<OperationsMetrics> watchMetricsForDay(String dayKey);

  Stream<List<OperationsDeliveryEvent>> watchDeliveryEvents({
    DateTime? since,
    int limit = 50,
  });

  Stream<List<OperationsDeadLetter>> watchDeadLetters({int limit = 10});

  Future<void> enqueueTestSms({
    required String phone,
    required String template,
    required String name,
    required String pickupTime,
  });

  Future<void> requeueDeadLetter(OperationsDeadLetter deadLetter);

  Future<void> addDeliveryEvent({
    required String messageId,
    required String type,
    required Map<String, dynamic> payload,
  });
}
