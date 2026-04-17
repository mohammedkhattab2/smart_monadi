import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String nationalId, required String password}) {
    return _repository.signIn(nationalId: nationalId, password: password);
  }
}
