import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static final RegExp _nationalIdRegex = RegExp(r'^\d{10}$');
  static const _rememberPasswordKey = 'auth.remember_password';
  static const _rememberedNationalIdKey = 'auth.remembered_national_id';
  static const _securePasswordKey = 'auth.remembered_password';

  late final TabController _tabController;
  late final SignInUseCase _signInUseCase;
  late final RegisterUseCase _registerUseCase;
  final _signInNationalIdController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerNationalIdController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  UserRole _registerRole = UserRole.parent;
  bool _rememberPassword = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _signInUseCase = SignInUseCase(widget.authService);
    _registerUseCase = RegisterUseCase(widget.authService);
    _restoreRememberedCredentials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInNationalIdController.dispose();
    _signInPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerNationalIdController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _restoreRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberPasswordKey) ?? false;
    if (!remember) {
      return;
    }

    final nationalId = prefs.getString(_rememberedNationalIdKey) ?? '';
    final password = await _secureStorage.read(key: _securePasswordKey) ?? '';
    if (!mounted) {
      return;
    }

    setState(() {
      _rememberPassword = true;
      _signInNationalIdController.text = nationalId;
      _signInPasswordController.text = password;
    });
  }

  Future<void> _persistRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberPasswordKey, _rememberPassword);

    if (_rememberPassword) {
      await prefs.setString(
        _rememberedNationalIdKey,
        _signInNationalIdController.text.trim(),
      );
      await _secureStorage.write(
        key: _securePasswordKey,
        value: _signInPasswordController.text,
      );
      return;
    }

    await prefs.remove(_rememberedNationalIdKey);
    await _secureStorage.delete(key: _securePasswordKey);
  }

  String? _validateSignInInputs() {
    final nationalId = _signInNationalIdController.text.trim();
    final password = _signInPasswordController.text;
    if (!_nationalIdRegex.hasMatch(nationalId)) {
      return 'auth.error_national_id_invalid_sign_in'.tr();
    }
    if (password.length < 6) {
      return 'auth.error_password_short'.tr();
    }
    return null;
  }

  String? _validateRegisterInputs() {
    final username = _registerUsernameController.text.trim();
    final nationalId = _registerNationalIdController.text.trim();
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    if (username.isEmpty) {
      return 'auth.error_username_required'.tr();
    }
    final validNationalId = _nationalIdRegex.hasMatch(nationalId);
    if (!validNationalId) {
      return 'auth.error_national_id_invalid'.tr();
    }
    if (password.length < 6) {
      return 'auth.error_password_short'.tr();
    }
    if (confirmPassword != password) {
      return 'auth.error_password_mismatch'.tr();
    }

    return null;
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await action();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final message = _mapErrorToMessage(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
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
        case 'invalid-national-id':
          return 'auth.error_national_id_invalid_sign_in'.tr();
        case 'invalid-username':
          return 'auth.error_username_required'.tr();
        case 'email-already-in-use':
          return 'auth.error_national_id_exists'.tr();
        case 'invalid-email':
          return 'auth.error_national_id_invalid'.tr();
        case 'weak-password':
          return 'auth.error_password_short'.tr();
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'auth.error_invalid_credentials'.tr();
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Try again later.';
        case 'operation-not-allowed':
          return 'National ID/Password sign-in is disabled in Firebase.';
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
              controller: _signInNationalIdController,
              keyboardType: TextInputType.number,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'auth.national_id'.tr()),
            ),
            SizedBox(height: AppSpacing.xs.h),
            TextField(
              controller: _signInPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password'.tr()),
            ),
            SizedBox(height: AppSpacing.xs.h),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _rememberPassword,
              title: Text('auth.remember_password'.tr()),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _rememberPassword = value ?? false;
                      });
                    },
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

                        _run(() async {
                          return _signInUseCase(
                            nationalId: _signInNationalIdController.text.trim(),
                            password: _signInPasswordController.text,
                          );
                        }).then((success) {
                          if (success) {
                            _persistRememberedCredentials();
                          }
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
                controller: _registerUsernameController,
                decoration: InputDecoration(labelText: 'auth.username'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              TextField(
                controller: _registerNationalIdController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'auth.national_id'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              TextField(
                controller: _registerPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'auth.password'.tr()),
              ),
              SizedBox(height: AppSpacing.xs.h),
              TextField(
                controller: _registerConfirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'auth.confirm_password'.tr(),
                ),
              ),
              SizedBox(height: AppSpacing.xs.h),
              DropdownButtonFormField<UserRole>(
                initialValue: _registerRole,
                decoration: InputDecoration(labelText: 'auth.role'.tr()),
                items: [
                  DropdownMenuItem(
                    value: UserRole.parent,
                    child: Text('auth.role_parent'.tr()),
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
                    const maxLength = 10;
                    final current = _registerNationalIdController.text;
                    if (current.length > maxLength) {
                      _registerNationalIdController.text = current.substring(
                        0,
                        maxLength,
                      );
                    }
                  });
                },
              ),
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

                          _run(() {
                            return _registerUseCase(
                              nationalId: _registerNationalIdController.text
                                  .trim(),
                              username: _registerUsernameController.text.trim(),
                              password: _registerPasswordController.text,
                              role: _registerRole,
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
