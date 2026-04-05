import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class SavePassengerProfileUseCase {
  const SavePassengerProfileUseCase(this._repository);

  final PassengerRepository _repository;

  Future<void> call({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String pickupTime,
    String returnTime = '',
    double? latitude,
    double? longitude,
  }) {
    return _repository.upsertPassenger(
      id: id,
      name: name,
      phone: phone,
      address: address,
      pickupTime: pickupTime,
      returnTime: returnTime,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
