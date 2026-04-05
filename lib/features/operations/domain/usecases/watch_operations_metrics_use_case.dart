import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class WatchOperationsMetricsUseCase {
  const WatchOperationsMetricsUseCase(this._repository);

  final OperationsRepository _repository;

  Stream<OperationsMetrics> call(String dayKey) {
    return _repository.watchMetricsForDay(dayKey);
  }
}
