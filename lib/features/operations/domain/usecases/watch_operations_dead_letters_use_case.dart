import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class WatchOperationsDeadLettersUseCase {
  const WatchOperationsDeadLettersUseCase(this._repository);

  final OperationsRepository _repository;

  Stream<List<OperationsDeadLetter>> call({int limit = 10}) {
    return _repository.watchDeadLetters(limit: limit);
  }
}
