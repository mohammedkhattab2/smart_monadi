import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
