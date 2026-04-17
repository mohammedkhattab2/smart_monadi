import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String nationalId,
    required String username,
    required String password,
    required UserRole role,
  }) {
    return _repository.register(
      nationalId: nationalId,
      username: username,
      password: password,
      role: role,
    );
  }
}
