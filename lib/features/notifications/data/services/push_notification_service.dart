import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> registerUser(String uid) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _upsertToken(uid, token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((nextToken) {
      if (nextToken.isEmpty) {
        return;
      }
      _upsertToken(uid, nextToken);
    });
  }

  Future<void> unregisterUser(String uid) async {
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _safeSetUserDoc(uid, {
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': Timestamp.now(),
      });
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> _upsertToken(String uid, String token) {
    return _safeSetUserDoc(uid, {
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> _safeSetUserDoc(String uid, Map<String, dynamic> payload) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        // Ignore transient auth/rules race conditions during sign-out/sign-in.
        return;
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
