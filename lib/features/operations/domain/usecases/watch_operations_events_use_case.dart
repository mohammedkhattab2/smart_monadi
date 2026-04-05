import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class WatchOperationsEventsUseCase {
  const WatchOperationsEventsUseCase(this._repository);

  final OperationsRepository _repository;

  Stream<List<OperationsDeliveryEvent>> call({DateTime? since, int limit = 50}) {
    return _repository.watchDeliveryEvents(since: since, limit: limit);
  }
}
