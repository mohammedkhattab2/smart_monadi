import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

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
      await _firestore.collection('passengers').doc(uid).set({
        'name': trimmedName,
        'phone': (passengerPhone ?? '').trim(),
        'address': (passengerAddress ?? '').trim(),
        'pickupTime': (pickupTime ?? '').trim(),
        'returnTime': (returnTime ?? '').trim(),
        'isPickedUp': false,
        'geofenceState': 'idle',
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    }
  }

  Future<UserRole> resolveRole(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final role = (doc.data()?['role'] ?? 'passenger').toString();
    return userRoleFromString(role);
  }

  Future<void> signOut() => _auth.signOut();
}
