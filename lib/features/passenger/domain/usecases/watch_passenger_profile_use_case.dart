import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class WatchPassengerProfileUseCase {
  const WatchPassengerProfileUseCase(this._repository);

  final PassengerRepository _repository;

  Stream<Passenger?> call(String passengerId) {
    return _repository.watchPassengerById(passengerId);
  }
}
