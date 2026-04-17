import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  Future<void> signIn({required String nationalId, required String password});

  Future<void> register({
    required String nationalId,
    required String username,
    required String password,
    required UserRole role,
  });

  Future<UserRole> resolveRole(String uid);

  Future<void> signOut();
}
