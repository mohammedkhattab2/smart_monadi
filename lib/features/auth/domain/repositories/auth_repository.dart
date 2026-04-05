import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  Future<void> signIn({required String email, required String password});

  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? passengerPhone,
    String? passengerAddress,
    String? pickupTime,
    String? returnTime,
  });

  Future<UserRole> resolveRole(String uid);

  Future<void> signOut();
}
