import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:smart_monadi/app/app.dart';
import 'package:smart_monadi/app/di/app_dependencies.dart';
import 'package:smart_monadi/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ignore: avoid_print
  print(
    '📦 FCM background message: '
    'id=${message.messageId ?? 'unknown'}, '
    'title=${message.notification?.title ?? message.data['title'] ?? ''}, '
    'body=${message.notification?.body ?? message.data['body'] ?? ''}, '
    'data=${message.data}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env/.env', isOptional: true);
  await EasyLocalization.ensureInitialized();

  final firebaseReady = await _initializeFirebase();
  if (!firebaseReady && kIsWeb) {
    runApp(const _UnsupportedWebSetupApp());
    return;
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  final dependencies = AppDependencies.create();
  try {
    await dependencies.pushNotificationService.start();
  } catch (error, stackTrace) {
    // ignore: avoid_print
    print('PushNotificationService.start failed: $error');
    // ignore: avoid_print
    print(stackTrace);
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: SmartMonadiApp(dependencies: dependencies),
    ),
  );
}

Future<bool> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } on UnsupportedError catch (error) {
    // ignore: avoid_print
    print('Firebase setup is not available on this platform: $error');
    return false;
  }
}

class _UnsupportedWebSetupApp extends StatelessWidget {
  const _UnsupportedWebSetupApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Firebase Web is not configured for this project yet. '
              'Run on Android/iOS, or configure Web via FlutterFire CLI.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
