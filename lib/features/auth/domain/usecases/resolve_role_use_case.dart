import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

class ResolveRoleUseCase {
  const ResolveRoleUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserRole> call(String uid) {
    return _repository.resolveRole(uid);
  }
}
