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
  static final RegExp _nationalIdRegex = RegExp(r'^\d{10}$');

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> signIn({
    required String nationalId,
    required String password,
  }) async {
    final normalizedNationalId = _normalizeNationalId(nationalId);
    await _auth.signInWithEmailAndPassword(
      email: _emailFromNationalId(normalizedNationalId),
      password: password,
    );
  }

  @override
  Future<void> register({
    required String nationalId,
    required String username,
    required String password,
    required UserRole role,
  }) async {
    final normalizedNationalId = _normalizeNationalId(nationalId, role: role);
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-username',
        message: 'Username is required.',
      );
    }

    final internalEmail = _emailFromNationalId(normalizedNationalId);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: internalEmail,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw Exception('User creation failed');
    }

    await _firestore.collection('users').doc(uid).set({
      'email': internalEmail,
      'nationalId': normalizedNationalId,
      'username': normalizedUsername,
      'role': userRoleToString(role),
      'name': normalizedUsername,
      'authVersion': 2,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
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
    return UserRole.parent;
  }

  String _normalizeNationalId(String value, {UserRole? role}) {
    final normalized = value.trim();

    if (_nationalIdRegex.hasMatch(normalized)) {
      return normalized;
    }

    throw FirebaseAuthException(
      code: 'invalid-national-id',
      message: 'National ID must be exactly 10 digits.',
    );
  }

  String _emailFromNationalId(String nationalId) {
    return 'nid_$nationalId@smartmonadi.local';
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
