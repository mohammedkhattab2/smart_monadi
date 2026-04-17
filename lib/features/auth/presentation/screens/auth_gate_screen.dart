import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/auth/domain/usecases/resolve_role_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/watch_auth_state_use_case.dart';
import 'package:smart_monadi/features/auth/presentation/screens/auth_screen.dart';
import 'package:smart_monadi/features/home/presentation/screens/home_shell.dart';
import 'package:smart_monadi/app/di/app_dependencies.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.dependencies,
    required this.authRepository,
    required this.onToggleLocale,
    required this.onToggleTheme,
  });

  final AppDependencies dependencies;
  final AuthRepository authRepository;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleTheme;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late final WatchAuthStateUseCase _watchAuthStateUseCase;
  late final ResolveRoleUseCase _resolveRoleUseCase;
  late final SignOutUseCase _signOutUseCase;

  @override
  void initState() {
    super.initState();
    _watchAuthStateUseCase = WatchAuthStateUseCase(widget.authRepository);
    _resolveRoleUseCase = ResolveRoleUseCase(widget.authRepository);
    _signOutUseCase = SignOutUseCase(widget.authRepository);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _watchAuthStateUseCase(),
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
          return AuthScreen(authService: widget.authRepository);
        }

        return FutureBuilder<UserRole>(
          future: _resolveRoleUseCase(user.uid),
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

            final role = roleSnapshot.data ?? UserRole.parent;
            return HomeShell(
              dependencies: widget.dependencies,
              role: role,
              currentUserId: user.uid,
              onSignOut: _signOutUseCase.call,
              onToggleLocale: widget.onToggleLocale,
              onToggleTheme: widget.onToggleTheme,
            );
          },
        );
      },
    );
  }
}
