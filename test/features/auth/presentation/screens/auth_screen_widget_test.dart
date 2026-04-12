import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/auth/presentation/screens/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('sign in validates email and blocks repository call', (
    tester,
  ) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final authRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: Builder(
          builder: (context) => ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, child) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: AuthScreen(authService: authRepository),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(2));

    await tester.enterText(textFields.at(0), 'invalid-email');
    await tester.enterText(textFields.at(1), '123456');

    var signInButton = find.widgetWithText(FilledButton, 'Sign In');
    if (signInButton.evaluate().isEmpty) {
      signInButton = find.widgetWithText(FilledButton, 'auth.sign_in');
    }

    expect(signInButton, findsOneWidget);
    await tester.tap(signInButton);
    await tester.pump(const Duration(milliseconds: 250));

    expect(authRepository.signInCalls, 0);
  });
}

class _FakeAuthRepository implements AuthRepository {
  int signInCalls = 0;
  int registerCalls = 0;

  String? lastSignInEmail;
  String? lastSignInPassword;

  String? lastRegisteredEmail;
  String? lastRegisteredPassword;
  UserRole? lastRegisteredRole;
  String? lastRegisteredPickupTime;
  String? lastRegisteredReturnTime;

  @override
  Stream<User?> authStateChanges() {
    return const Stream<User?>.empty();
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
    lastRegisteredPickupTime = pickupTime;
    lastRegisteredReturnTime = returnTime;
  }

  @override
  Future<UserRole> resolveRole(String uid) async {
    return UserRole.passenger;
  }

  @override
  Future<void> signOut() async {}
}
