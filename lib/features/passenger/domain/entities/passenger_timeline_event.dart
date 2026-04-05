class PassengerTimelineEvent {
  const PassengerTimelineEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String message;
  final DateTime? createdAt;
}
