import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';

class WatchAuthStateUseCase {
  const WatchAuthStateUseCase(this._repository);

  final AuthRepository _repository;

  Stream<User?> call() {
    return _repository.authStateChanges();
  }
}
