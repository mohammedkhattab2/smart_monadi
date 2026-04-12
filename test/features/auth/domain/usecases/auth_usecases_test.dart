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

      await useCase(email: 'ali@example.com', password: '123456');

      expect(repository.signInCalls, 1);
      expect(repository.lastSignInEmail, 'ali@example.com');
      expect(repository.lastSignInPassword, '123456');
    });

    test('RegisterUseCase delegates all passenger fields', () async {
      final repository = _FakeAuthRepository();
      final useCase = RegisterUseCase(repository);

      await useCase(
        email: 'ali@example.com',
        password: '123456',
        role: UserRole.passenger,
        name: 'Ali',
        passengerPhone: '+201111111111',
        passengerAddress: 'Cairo',
        pickupTime: '07:30',
        returnTime: '14:30',
      );

      expect(repository.registerCalls, 1);
      expect(repository.lastRegisteredEmail, 'ali@example.com');
      expect(repository.lastRegisteredPassword, '123456');
      expect(repository.lastRegisteredRole, UserRole.passenger);
      expect(repository.lastRegisteredName, 'Ali');
      expect(repository.lastRegisteredPhone, '+201111111111');
      expect(repository.lastRegisteredAddress, 'Cairo');
      expect(repository.lastRegisteredPickupTime, '07:30');
      expect(repository.lastRegisteredReturnTime, '14:30');
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

  String? lastSignInEmail;
  String? lastSignInPassword;

  String? lastRegisteredEmail;
  String? lastRegisteredPassword;
  UserRole? lastRegisteredRole;
  String? lastRegisteredName;
  String? lastRegisteredPhone;
  String? lastRegisteredAddress;
  String? lastRegisteredPickupTime;
  String? lastRegisteredReturnTime;

  String? lastResolvedUid;
  UserRole resolvedRole = UserRole.passenger;

  final Stream<User?> authStateStream = const Stream<User?>.empty();

  @override
  Stream<User?> authStateChanges() {
    return authStateStream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls += 1;
    lastSignInEmail = email;
    lastSignInPassword = password;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    String? name,
    String? passengerPhone,
    String? passengerAddress,
    String? pickupTime,
    String? returnTime,
  }) async {
    registerCalls += 1;
    lastRegisteredEmail = email;
    lastRegisteredPassword = password;
    lastRegisteredRole = role;
    lastRegisteredName = name;
    lastRegisteredPhone = passengerPhone;
    lastRegisteredAddress = passengerAddress;
    lastRegisteredPickupTime = pickupTime;
    lastRegisteredReturnTime = returnTime;
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
