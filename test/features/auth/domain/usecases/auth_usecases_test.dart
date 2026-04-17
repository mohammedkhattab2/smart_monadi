import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/auth/domain/usecases/register_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/resolve_role_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/watch_auth_state_use_case.dart';

void main() {
  group('Auth use cases', () {
    test('SignInUseCase delegates to repository', () async {
      final repository = _FakeAuthRepository();
      final useCase = SignInUseCase(repository);

      await useCase(nationalId: '12345678901234', password: '123456');

      expect(repository.signInCalls, 1);
      expect(repository.lastSignInNationalId, '12345678901234');
      expect(repository.lastSignInPassword, '123456');
    });

    test('RegisterUseCase delegates registration fields', () async {
      final repository = _FakeAuthRepository();
      final useCase = RegisterUseCase(repository);

      await useCase(
        nationalId: '12345678901234',
        username: 'Ali',
        password: '123456',
        role: UserRole.parent,
      );

      expect(repository.registerCalls, 1);
      expect(repository.lastRegisteredNationalId, '12345678901234');
      expect(repository.lastRegisteredUsername, 'Ali');
      expect(repository.lastRegisteredPassword, '123456');
      expect(repository.lastRegisteredRole, UserRole.parent);
    });

    test('ResolveRoleUseCase returns repository role', () async {
      final repository = _FakeAuthRepository()..resolvedRole = UserRole.driver;
      final useCase = ResolveRoleUseCase(repository);

      final role = await useCase('uid-1');

      expect(repository.resolveRoleCalls, 1);
      expect(repository.lastResolvedUid, 'uid-1');
      expect(role, UserRole.driver);
    });

    test('SignOutUseCase delegates to repository', () async {
      final repository = _FakeAuthRepository();
      final useCase = SignOutUseCase(repository);

      await useCase();

      expect(repository.signOutCalls, 1);
    });

    test('WatchAuthStateUseCase returns repository stream', () async {
      final repository = _FakeAuthRepository();
      final useCase = WatchAuthStateUseCase(repository);

      final stream = useCase();
      expect(identical(stream, repository.authStateStream), isTrue);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  int signInCalls = 0;
  int registerCalls = 0;
  int resolveRoleCalls = 0;
  int signOutCalls = 0;

  String? lastSignInNationalId;
  String? lastSignInPassword;

  String? lastRegisteredNationalId;
  String? lastRegisteredUsername;
  String? lastRegisteredPassword;
  UserRole? lastRegisteredRole;

  String? lastResolvedUid;
  UserRole resolvedRole = UserRole.parent;

  final Stream<User?> authStateStream = const Stream<User?>.empty();

  @override
  Stream<User?> authStateChanges() {
    return authStateStream;
  }

  @override
  Future<void> signIn({
    required String nationalId,
    required String password,
  }) async {
    signInCalls += 1;
    lastSignInNationalId = nationalId;
    lastSignInPassword = password;
  }

  @override
  Future<void> register({
    required String nationalId,
    required String username,
    required String password,
    required UserRole role,
  }) async {
    registerCalls += 1;
    lastRegisteredNationalId = nationalId;
    lastRegisteredUsername = username;
    lastRegisteredPassword = password;
    lastRegisteredRole = role;
  }

  @override
  Future<UserRole> resolveRole(String uid) async {
    resolveRoleCalls += 1;
    lastResolvedUid = uid;
    return resolvedRole;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}
