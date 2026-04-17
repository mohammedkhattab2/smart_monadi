import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_monadi/app/di/app_dependencies.dart';
import 'package:smart_monadi/app/theme/app_theme.dart';
import 'package:smart_monadi/features/auth/presentation/screens/auth_gate_screen.dart';

class SmartMonadiApp extends StatefulWidget {
  const SmartMonadiApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<SmartMonadiApp> createState() => _SmartMonadiAppState();
}

class _SmartMonadiAppState extends State<SmartMonadiApp> {
  static const _themeModeKey = 'app.theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.dependencies.pushNotificationService.onAppReady();
    });
  }

  Future<void> _restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString(_themeModeKey) ?? 'system';

    if (!mounted) {
      return;
    }

    setState(() {
      if (modeRaw == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeRaw == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      _settingsLoaded = true;
    });
  }

  Future<void> _persistThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = _themeMode == ThemeMode.light
        ? 'light'
        : _themeMode == ThemeMode.dark
        ? 'dark'
        : 'system';
    await prefs.setString(_themeModeKey, value);
  }

  void _toggleThemeMode() {
    setState(() {
      if (_themeMode == ThemeMode.system) {
        _themeMode = ThemeMode.light;
      } else if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
    _persistThemeMode();
  }

  void _toggleLocale(BuildContext context) {
    final current = context.locale;
    final next = current.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    context.setLocale(next);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        if (!_settingsLoaded) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return MaterialApp(
          title: 'Smart Monadi',
          debugShowCheckedModeBanner: false,
          navigatorKey: widget.dependencies.navigatorKey,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          home: AuthGateScreen(
            dependencies: widget.dependencies,
            authRepository: widget.dependencies.authRepository,
            onToggleLocale: () => _toggleLocale(context),
            onToggleTheme: _toggleThemeMode,
          ),
        );
      },
    );
  }
}
