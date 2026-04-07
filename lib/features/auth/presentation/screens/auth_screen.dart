import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/auth/domain/usecases/register_use_case.dart';
import 'package:smart_monadi/features/auth/domain/usecases/sign_in_use_case.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.authService});

  final AuthRepository authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  late final TabController _tabController;
  late final SignInUseCase _signInUseCase;
  late final RegisterUseCase _registerUseCase;
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerAddressController = TextEditingController();
  final _registerPickupTimeController = TextEditingController();
  final _registerReturnTimeController = TextEditingController();
  UserRole _registerRole = UserRole.passenger;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _signInUseCase = SignInUseCase(widget.authService);
    _registerUseCase = RegisterUseCase(widget.authService);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerNameController.dispose();
    _registerPhoneController.dispose();
    _registerAddressController.dispose();
    _registerPickupTimeController.dispose();
    _registerReturnTimeController.dispose();
    super.dispose();
  }

  bool _isPassengerRegistrationValid() {
    if (_registerRole != UserRole.passenger) {
      return true;
    }

    return _registerPhoneController.text.trim().isNotEmpty &&
        _registerAddressController.text.trim().isNotEmpty &&
        _registerPickupTimeController.text.trim().isNotEmpty &&
        _registerReturnTimeController.text.trim().isNotEmpty;
  }

  String? _validateSignInInputs() {
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;
    if (!_emailRegex.hasMatch(email)) {
      return 'auth.error_email_invalid'.tr();
    }
    if (password.length < 6) {
      return 'auth.error_password_short'.tr();
    }
    return null;
  }

  String? _validateRegisterInputs() {
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;
    final name = _registerNameController.text.trim();

    if (name.isEmpty) {
      return 'auth.error_name_required'.tr();
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'auth.error_email_invalid'.tr();
    }
    if (password.length < 6) {
      return 'auth.error_password_short'.tr();
    }

    if (_registerRole == UserRole.passenger) {
      final pickup = _registerPickupTimeController.text.trim();
      final returning = _registerReturnTimeController.text.trim();
      if (!_timeRegex.hasMatch(pickup) || !_timeRegex.hasMatch(returning)) {
        return 'auth.error_time_invalid'.tr();
      }
    }

    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _mapErrorToMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapErrorToMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'Email already in use.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'weak-password':
          return 'Password is too weak (minimum 6 characters).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'operation-not-allowed':
          return 'Email/Password sign-in is disabled in Firebase.';
        case 'internal-error':
          return 'Firebase internal error. Verify SHA fingerprints and google-services.json.';
        default:
          final details = (error.message ?? '').trim();
          if (details.isNotEmpty) {
            return details;
          }
          return 'Authentication failed (${error.code}).';
      }
    }

    if (error is FirebaseException) {
      if (error.plugin == 'cloud_firestore') {
        switch (error.code) {
          case 'permission-denied':
            return 'Firestore permission denied. Check Firestore security rules.';
          case 'unavailable':
            return 'Firestore is unavailable right now. Try again.';
          default:
            final details = (error.message ?? '').trim();
            if (details.isNotEmpty) {
              return details;
            }
            return 'Database error (${error.code}).';
        }
      }
    }

    return 'auth.error_generic'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 440.w),
            child: ListView(
              padding: EdgeInsets.all(AppSpacing.md.w),
              children: [
                SizedBox(height: AppSpacing.md.h),
                AppFadeSlideIn(
                  child: AppGradientHeaderCard(
                    icon: Icons.directions_bus,
                    title: 'auth.title'.tr(),
                    subtitle: 'app.name'.tr(),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                AppFadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs.w),
                      child: TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(text: 'auth.sign_in'.tr()),
                          Tab(text: 'auth.register'.tr()),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                SizedBox(
                  height: 620.h,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSignInCard(context),
                      _buildRegisterCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCard(BuildContext context) {
    return AppFadeSlideIn(
      delay: const Duration(milliseconds: 120),
      child: AppSectionCard(
        icon: Icons.login,
        title: 'auth.sign_in'.tr(),
        child: Column(
          children: [
            TextField(
              controller: _signInEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'auth.email'.tr()),
            ),
            SizedBox(height: AppSpacing.xs.h),
            TextField(
              controller: _signInPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password'.tr()),
            ),
            SizedBox(height: AppSpacing.sm.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        final error = _validateSignInInputs();
                        if (error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }

                        _run(() {
                          return _signInUseCase(
                            email: _signInEmailController.text.trim(),
                            password: _signInPasswordController.text,
                          );
                        });
                      },
                child: _isLoading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text('auth.sign_in'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard(BuildContext context) {
    return AppFadeSlideIn(
      delay: const Duration(milliseconds: 160),
      child: AppSectionCard(
        icon: Icons.person_add_alt_1,
        title: 'auth.register'.tr(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _registerNameController,
                decoration: InputDecoration(labelText: 'auth.name'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              TextField(
                controller: _registerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'auth.email'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              TextField(
                controller: _registerPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'auth.password'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              DropdownButtonFormField<UserRole>(
                initialValue: _registerRole,
                decoration: InputDecoration(labelText: 'auth.role'.tr()),
                items: [
                  DropdownMenuItem(
                    value: UserRole.passenger,
                    child: Text('auth.role_passenger'.tr()),
                  ),
                  DropdownMenuItem(
                    value: UserRole.driver,
                    child: Text('auth.role_driver'.tr()),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _registerRole = value;
                  });
                },
              ),
              if (_registerRole == UserRole.passenger) ...[
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _registerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'auth.passenger_phone'.tr(),
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _registerAddressController,
                  decoration: InputDecoration(
                    labelText: 'auth.passenger_address'.tr(),
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _registerPickupTimeController,
                  decoration: InputDecoration(
                    labelText: 'auth.passenger_pickup_time'.tr(),
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _registerReturnTimeController,
                  decoration: InputDecoration(
                    labelText: 'auth.passenger_return_time'.tr(),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.sm.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final validationError = _validateRegisterInputs();
                          if (validationError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(validationError)),
                            );
                            return;
                          }

                          if (!_isPassengerRegistrationValid()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'auth.error_passenger_required'.tr(),
                                ),
                              ),
                            );
                            return;
                          }

                          _run(() {
                            return _registerUseCase(
                              email: _registerEmailController.text.trim(),
                              password: _registerPasswordController.text,
                              role: _registerRole,
                              name: _registerNameController.text.trim(),
                              passengerPhone: _registerPhoneController.text
                                  .trim(),
                              passengerAddress: _registerAddressController.text
                                  .trim(),
                              pickupTime: _registerPickupTimeController.text
                                  .trim(),
                              returnTime: _registerReturnTimeController.text
                                  .trim(),
                            );
                          });
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text('auth.register'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
