import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class RequeueDeadLetterUseCase {
  const RequeueDeadLetterUseCase(this._repository);

  final OperationsRepository _repository;

  Future<void> call(OperationsDeadLetter deadLetter) {
    return _repository.requeueDeadLetter(deadLetter);
  }
}
