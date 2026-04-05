class OperationsMetrics {
  const OperationsMetrics({
    required this.sent,
    required this.failed,
    required this.failedPermanent,
  });

  final int sent;
  final int failed;
  final int failedPermanent;
}

class OperationsDeliveryEvent {
  const OperationsDeliveryEvent({
    required this.id,
    required this.type,
    required this.messageId,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String type;
  final String messageId;
  final DateTime? createdAt;
  final Map<String, dynamic> payload;
}

class OperationsDeadLetter {
  const OperationsDeadLetter({
    required this.id,
    required this.toPhone,
    required this.attempts,
    required this.reason,
    required this.movedAt,
    required this.errorUserMessage,
    required this.errorMessage,
    required this.originalPayload,
  });

  final String id;
  final String toPhone;
  final int attempts;
  final String reason;
  final DateTime? movedAt;
  final String errorUserMessage;
  final String errorMessage;
  final Map<String, dynamic> originalPayload;
}
