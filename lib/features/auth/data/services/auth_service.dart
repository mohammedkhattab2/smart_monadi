import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

class AuthService implements AuthRepository {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  static const int _resolveRoleRetries = 6;
  static const Duration _resolveRoleRetryDelay = Duration(milliseconds: 250);
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw Exception('User creation failed');
    }

    final trimmedName = (name ?? '').trim();
    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'role': userRoleToString(role),
      'name': trimmedName,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    if (role == UserRole.passenger) {
      final normalizedPickup = _normalizeScheduleTime(
        pickupTime,
        fallback: '07:30',
      );
      final normalizedReturn = _normalizeScheduleTime(
        returnTime,
        fallback: '14:30',
      );

      await _firestore.collection('passengers').doc(uid).set({
        'name': trimmedName,
        'phone': (passengerPhone ?? '').trim(),
        'address': (passengerAddress ?? '').trim(),
        'pickupTime': normalizedPickup,
        'returnTime': normalizedReturn,
        'isPickedUp': false,
        'geofenceState': 'idle',
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Future<UserRole> resolveRole(String uid) async {
    for (var attempt = 0; attempt < _resolveRoleRetries; attempt += 1) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final rawRole = (doc.data()?['role'] ?? '').toString();
      final normalized = rawRole.trim().toLowerCase();

      if (normalized.isNotEmpty) {
        final role = userRoleFromString(normalized);

        // Keep stored role normalized for future reads.
        final canonical = userRoleToString(role);
        if (normalized != canonical) {
          await _firestore.collection('users').doc(uid).set({
            'role': canonical,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        }

        return role;
      }

      // During register/sign-in races, role can be temporarily absent.
      if (attempt < _resolveRoleRetries - 1) {
        await Future<void>.delayed(_resolveRoleRetryDelay);
      }
    }

    // Conservative fallback to keep app usable if role doc is still missing.
    return UserRole.passenger;
  }

  String _normalizeScheduleTime(String? value, {required String fallback}) {
    final raw = (value ?? '').trim();
    if (_timeRegex.hasMatch(raw)) {
      return raw;
    }
    return fallback;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
