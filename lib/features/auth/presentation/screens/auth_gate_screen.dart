import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/features/auth/data/services/auth_service.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/auth/presentation/screens/auth_screen.dart';
import 'package:smart_monadi/features/home/presentation/screens/home_shell.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.onToggleLocale,
    required this.onToggleTheme,
  });

  final VoidCallback onToggleLocale;
  final VoidCallback onToggleTheme;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AppSkeletonList(itemCount: 4),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppStateCard(
                  icon: Icons.error_outline,
                  title: 'states.error_title'.tr(),
                  message: 'states.error_message'.tr(),
                  actionLabel: 'actions.retry'.tr(),
                  onAction: () => setState(() {}),
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return AuthScreen(authService: _authService);
        }

        return FutureBuilder<UserRole>(
          future: _authService.resolveRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AppSkeletonList(itemCount: 3),
                  ),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppStateCard(
                      icon: Icons.error_outline,
                      title: 'states.error_title'.tr(),
                      message: 'states.error_message'.tr(),
                      actionLabel: 'actions.retry'.tr(),
                      onAction: () => setState(() {}),
                    ),
                  ),
                ),
              );
            }

            final role = roleSnapshot.data ?? UserRole.passenger;
            return HomeShell(
              role: role,
              onSignOut: _authService.signOut,
              onToggleLocale: widget.onToggleLocale,
              onToggleTheme: widget.onToggleTheme,
            );
          },
        );
      },
    );
  }
}
