import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? passengerPhone,
    String? passengerAddress,
    String? pickupTime,
    String? returnTime,
  }) {
    return _repository.register(
      email: email,
      password: password,
      role: role,
      name: name,
      passengerPhone: passengerPhone,
      passengerAddress: passengerAddress,
      pickupTime: pickupTime,
      returnTime: returnTime,
    );
  }
}
