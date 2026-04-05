abstract class TripEventRepository {
  Future<void> addPickupLog({
    required String passengerId,
    required String passengerPhone,
    required String type,
    required String message,
    required Map<String, dynamic> payload,
  });

  Future<void> queueSms({
    required String passengerId,
    required String toPhone,
    required String template,
    required Map<String, dynamic> variables,
  });
}
