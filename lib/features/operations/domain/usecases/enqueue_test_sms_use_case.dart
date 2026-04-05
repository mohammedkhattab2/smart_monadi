import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';

class EnqueueTestSmsUseCase {
  const EnqueueTestSmsUseCase(this._repository);

  final OperationsRepository _repository;

  Future<void> call({
    required String phone,
    required String template,
    required String name,
    required String pickupTime,
  }) {
    return _repository.enqueueTestSms(
      phone: phone,
      template: template,
      name: name,
      pickupTime: pickupTime,
    );
  }
}
