import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() {
    return _repository.signOut();
  }
}
