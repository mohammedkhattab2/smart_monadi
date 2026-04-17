import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_monadi/features/notifications/domain/entities/notification_route_intent.dart';

class PushNotificationService {
  static const String _highImportanceChannelId = 'high_importance_channel';

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterLocalNotificationsPlugin? localNotifications,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(NotificationRouteIntent intent)? onRouteIntent,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _navigatorKey = navigatorKey,
       _onRouteIntent = onRouteIntent;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final void Function(NotificationRouteIntent intent)? _onRouteIntent;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  bool _isStarted = false;
  final List<_NotificationNavigationRequest> _pendingNavigationRequests =
      <_NotificationNavigationRequest>[];

  void onAppReady() {
    _drainPendingNavigationRequests();
  }

  Future<void> start() async {
    if (_isStarted) {
      _log('Push service start skipped: already started.');
      return;
    }
    _isStarted = true;

    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedAppSubscription?.cancel();

    _log('🚀 Push Service Started');

    await _configureLocalNotifications();
    await _wireMessageLifecycleListeners();

    await _requestPermissionAndLogToken();

    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        if (user == null) {
          _log('Skipping FCM token sync: no authenticated user.');
          return;
        }
        unawaited(_syncCurrentTokenForUser(user.uid));
      },
      onError: (Object error, StackTrace stackTrace) {
        _log('Auth state subscription error: $error');
        _log('$stackTrace');
      },
    );

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (nextToken) {
        _log('🔄 FCM TOKEN REFRESHED: $nextToken');
        if (nextToken.isEmpty) {
          _log('Skipping FCM token refresh: empty token received.');
          return;
        }
        unawaited(_syncRefreshedToken(nextToken));
      },
      onError: (Object error, StackTrace stackTrace) {
        _log('FCM token refresh listener error: $error');
        _log('$stackTrace');
      },
    );

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _syncCurrentTokenForUser(currentUser.uid);
    }
  }

  Future<void> _configureLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          _log(
            '📬 Local notification tapped. payload=${response.payload ?? ''}',
          );
          _handleLocalNotificationTap(response.payload);
        },
      );

      final androidPlatform = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidPlatform?.createNotificationChannel(
        const AndroidNotificationChannel(
          _highImportanceChannelId,
          'High Importance Notifications',
          description: 'Channel for important ride and trip notifications.',
          importance: Importance.max,
          playSound: true,
        ),
      );
      _log('✅ Notification channel ready: $_highImportanceChannelId');
    } catch (error, stackTrace) {
      _log('Local notification setup failed: $error');
      _log('$stackTrace');
    }
  }

  Future<void> _wireMessageLifecycleListeners() async {
    try {
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
        (message) async {
          _log(
            '📩 FCM foreground message received: '
            '${_describeMessage(message)}',
          );
          await _showForegroundNotification(message);
        },
        onError: (Object error, StackTrace stackTrace) {
          _log('Foreground message listener error: $error');
          _log('$stackTrace');
        },
      );

      _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp
          .listen(
            (message) {
              _log(
                '📲 App opened from notification: '
                '${_describeMessage(message)}',
              );
              _navigateFromData(
                _sanitizePayload(message.data),
                source: 'onMessageOpenedApp',
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              _log('Message-opened listener error: $error');
              _log('$stackTrace');
            },
          );

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _log(
          '🚀 App launched from terminated notification: '
          '${_describeMessage(initialMessage)}',
        );
        _navigateFromData(
          _sanitizePayload(initialMessage.data),
          source: 'getInitialMessage',
        );
      } else {
        _log('No initial FCM message found on startup.');
      }
    } catch (error, stackTrace) {
      _log('Failed to wire FCM message lifecycle listeners: $error');
      _log('$stackTrace');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    final payload = message.data.isEmpty ? '' : jsonEncode(message.data);

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      _log(
        'Foreground message missing display fields; local notification skipped. '
        'messageId=${message.messageId ?? 'unknown'}',
      );
      return;
    }

    try {
      await _localNotifications.show(
        message.messageId.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _highImportanceChannelId,
            'High Importance Notifications',
            channelDescription:
                'Channel for important ride and trip notifications.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: payload,
      );
      _log('🔔 Foreground local notification shown.');
    } catch (error, stackTrace) {
      _log('Failed to show foreground local notification: $error');
      _log('$stackTrace');
    }
  }

  String _describeMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    return 'id=${message.messageId ?? 'unknown'}, title=${title ?? ''}, '
        'body=${body ?? ''}, data=${message.data}';
  }

  void _handleLocalNotificationTap(String? payloadRaw) {
    if (payloadRaw == null || payloadRaw.isEmpty) {
      _log('Local notification tap payload is empty; skipping navigation.');
      return;
    }

    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) {
        _log('Local notification payload is not a JSON object.');
        return;
      }

      final data = <String, String>{};
      for (final entry in decoded.entries) {
        data['${entry.key}'] = entry.value?.toString() ?? '';
      }
      _navigateFromData(data, source: 'localNotificationTap');
    } catch (error, stackTrace) {
      _log('Failed to parse local notification payload: $error');
      _log('$stackTrace');
    }
  }

  Map<String, String> _sanitizePayload(Map<String, dynamic> data) {
    final sanitized = <String, String>{};
    for (final entry in data.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      sanitized[key] = entry.value?.toString() ?? '';
    }
    return sanitized;
  }

  void _navigateFromData(
    Map<String, String> payload, {
    required String source,
  }) {
    final destination = _resolveDestination(payload);

    final request = _NotificationNavigationRequest(
      destination: destination,
      payload: payload,
      source: source,
    );

    if (!_tryNavigate(request)) {
      _pendingNavigationRequests.add(request);
      _log(
        'Navigator not ready. Queued notification navigation '
        'to ${destination.screenLabel}.',
      );
    }
  }

  NotificationRouteTarget _resolveDestination(Map<String, String> payload) {
    final type = payload['type']?.trim().toLowerCase() ?? '';
    final status = payload['status']?.trim().toLowerCase() ?? '';

    if (type == 'trip_update') {
      if (status == 'driver_arriving') {
        return NotificationRouteTarget.liveTracking;
      }
      return NotificationRouteTarget.tripDetails;
    }

    if (status == 'driver_arriving') {
      return NotificationRouteTarget.liveTracking;
    }

    if (type == 'eta_update' || status == 'eta_update') {
      return NotificationRouteTarget.eta;
    }

    return NotificationRouteTarget.home;
  }

  void _drainPendingNavigationRequests() {
    if (_pendingNavigationRequests.isEmpty) {
      return;
    }

    final buffered = List<_NotificationNavigationRequest>.from(
      _pendingNavigationRequests,
    );
    _pendingNavigationRequests.clear();

    for (final request in buffered) {
      if (!_tryNavigate(request)) {
        _pendingNavigationRequests.add(request);
      }
    }
  }

  bool _tryNavigate(_NotificationNavigationRequest request) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null || !navigator.mounted) {
      return false;
    }

    final intent = NotificationRouteIntent(
      target: request.destination,
      payload: request.payload,
      source: request.source,
    );

    _log(
      '📲 Navigating to LIVE SCREEN: '
      '${request.destination.screenLabel} '
      '(source=${request.source}, tripId=${request.payload['tripId'] ?? ''}, '
      'status=${request.payload['status'] ?? ''})',
    );
    _log('📦 Navigation payload: ${request.payload}');

    if (_onRouteIntent == null) {
      _log('⚠️ Notification route consumer is not configured.');
      return false;
    }

    _onRouteIntent.call(intent);
    return true;
  }

  Future<void> _requestPermissionAndLogToken() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _log('🔔 Permission Status: ${settings.authorizationStatus}');

      final token = await _messaging.getToken();
      _log('🔥 FCM TOKEN: ${token ?? '<null>'}');
      if (token == null || token.isEmpty) {
        _logNullTokenRootCauseHints(settings.authorizationStatus);
      }
    } on FirebaseException catch (error, stackTrace) {
      _log(
        'Failed to request permission/read FCM token '
        '[${error.code}] ${error.message ?? ''}',
      );
      _log('$stackTrace');
    } catch (error, stackTrace) {
      _log('Unexpected permission/token read failure: $error');
      _log('$stackTrace');
    }
  }

  Future<void> _syncCurrentTokenForUser(String uid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      _log('Skipping FCM token sync for uid=$uid: auth user not ready.');
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      _log(
        'Skipping FCM token sync for uid=$uid: notification permission '
        'status=${settings.authorizationStatus}.',
      );
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      _log('Skipping FCM token sync for uid=$uid: getToken returned empty.');
      _logNullTokenRootCauseHints(settings.authorizationStatus);
      return;
    }

    try {
      await _upsertToken(uid, token);
    } on FirebaseException catch (error, stackTrace) {
      _log(
        'FCM token write failed for uid=$uid '
        '[${error.code}] ${error.message ?? ''}',
      );
      _log('$stackTrace');
    } catch (error, stackTrace) {
      _log('Unexpected FCM token write failure for uid=$uid: $error');
      _log('$stackTrace');
    }
  }

  Future<void> _syncRefreshedToken(String token) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _log('Skipping refreshed FCM token sync: no authenticated user.');
      return;
    }

    try {
      await _upsertToken(currentUser.uid, token);
    } on FirebaseException catch (error, stackTrace) {
      _log(
        'Refreshed FCM token write failed for uid=${currentUser.uid} '
        '[${error.code}] ${error.message ?? ''}',
      );
      _log('$stackTrace');
    } catch (error, stackTrace) {
      _log(
        'Unexpected refreshed FCM token write failure for '
        'uid=${currentUser.uid}: $error',
      );
      _log('$stackTrace');
    }
  }

  Future<void> _upsertToken(String uid, String token) {
    return _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  void _logNullTokenRootCauseHints(AuthorizationStatus status) {
    _log(
      'FCM token is null/empty. Root-cause checklist: '
      'permissionStatus=$status, Firebase app initialization order, '
      'google-services config/package name mismatch, emulator/device '
      'Google Play Services availability, and network connectivity.',
    );
  }

  void _log(String message) {
    // Keep both logs so markers are visible in release and debug builds.
    // ignore: avoid_print
    print(message);
    debugPrint('PushNotificationService: $message');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = null;
    await _messageOpenedAppSubscription?.cancel();
    _messageOpenedAppSubscription = null;
    _pendingNavigationRequests.clear();
    _isStarted = false;
  }
}

class _NotificationNavigationRequest {
  const _NotificationNavigationRequest({
    required this.destination,
    required this.payload,
    required this.source,
  });

  final NotificationRouteTarget destination;
  final Map<String, String> payload;
  final String source;
}
