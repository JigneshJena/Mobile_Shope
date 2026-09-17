import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Handles all Firebase Authentication and user-profile operations.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────
  // Auth state
  // ──────────────────────────────────────────────

  /// Stream of Firebase [User] objects; emits `null` when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in [User], or `null` if signed out.
  User? get currentUser => _auth.currentUser;

  // ──────────────────────────────────────────────
  // Sign in / Sign out
  // ──────────────────────────────────────────────

  /// Signs in with [email] and [password].
  ///
  /// Returns the [UserCredential] on success.
  /// Rethrows [FirebaseAuthException] on failure so callers can surface
  /// a meaningful message to the user.
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      // Ensure Firestore user document exists (handles external/console creations)
      if (credential.user != null) {
        final uid = credential.user!.uid;
        final doc = await _firestore.collection('users').doc(uid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(uid).set({
            'name': credential.user!.displayName ?? email.split('@').first,
            'phone': '',
            'role': 'owner',
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      return credential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  /// Signs up a new user (default role: owner) and sets up their Firestore profile.
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'owner',
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // If user was already created in Auth (e.g. previous attempt failed at Firestore)
      if (e.code == 'email-already-in-use') {
        try {
          credential = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } catch (_) {
          // If signIn with this password fails, throw the original exception
          rethrow;
        }
      } else {
        rethrow;
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }

    try {
      final uid = credential.user!.uid;
      await credential.user?.updateDisplayName(name.trim());

      final now = DateTime.now();
      await _firestore.collection('users').doc(uid).set({
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role,
        'createdAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      return credential;
    } on FirebaseException {
      rethrow;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ──────────────────────────────────────────────
  // User model helpers
  // ──────────────────────────────────────────────

  /// Fetches the [UserModel] document from Firestore for [uid].
  ///
  /// Returns `null` if the document does not exist.
  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(uid, doc.data()!);
  }

  /// Returns a real-time stream of all [UserModel] documents in the 'users' collection.
  Stream<List<UserModel>> streamAllUsers() {
    return _firestore.collection('users').snapshots().map((snap) {
      return snap.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Returns a real-time stream of [UserModel] for the given [uid].
  ///
  /// Emits `null` if the document does not exist or has been deleted.
  Stream<UserModel?> userModelStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserModel.fromMap(uid, snap.data()!);
    });
  }

  // ──────────────────────────────────────────────
  // Employee creation (secondary app pattern)
  // ──────────────────────────────────────────────

  /// Creates a new employee account without disrupting the owner's auth session.
  ///
  /// Uses a secondary [FirebaseApp] instance so that `createUserWithEmailAndPassword`
  /// does not replace the currently signed-in owner. After writing the Firestore
  /// user doc, the secondary app is deleted.
  Future<void> createEmployee({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'employee',
  }) async {
    // Give each secondary app a unique name to avoid conflicts on retries.
    final appName = 'secondary_${DateTime.now().millisecondsSinceEpoch}';

    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;
      final now = DateTime.now();

      await _firestore.collection('users').doc(uid).set({
        'name': name.trim(),
        'phone': phone.trim(),
        'role': role,
        'createdAt': Timestamp.fromDate(now),
      });
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create employee: $e');
    } finally {
      // Always clean up the secondary app regardless of success or failure.
      await secondaryApp.delete();
    }
  }

  // ──────────────────────────────────────────────
  // Profile update
  // ──────────────────────────────────────────────

  /// Updates the [name] and [phone] fields of the Firestore user doc for [uid].
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'phone': phone.trim(),
    });
  }

  // ──────────────────────────────────────────────
  // Friendly error messages
  // ──────────────────────────────────────────────

  /// Converts Firebase Auth and general exceptions into user-friendly English messages.
  static String getReadableErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found with this email address. Please register first.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid email or password. Please verify your credentials.';
        case 'email-already-in-use':
          return 'This email is already registered. Please sign in instead.';
        case 'weak-password':
          return 'Password must be at least 6 characters long.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again in a few moments.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'operation-not-allowed':
        case 'configuration-not-found':
          return 'Email/Password sign-in is not enabled in Firebase Console. Please enable it in Authentication > Sign-in method.';
        case 'permission-denied':
          return 'Access denied by Firestore security rules. Please check your Firestore rules.';
        default:
          if ((error.message ?? '').contains('CONFIGURATION_NOT_FOUND')) {
            return 'Email/Password sign-in is not enabled in Firebase Console. Please enable it in Authentication > Sign-in method.';
          }
          return error.message ?? 'Authentication error occurred. Please try again.';
      }
    }

    final str = error.toString().toLowerCase();
    if (str.contains('permission-denied') || str.contains('permission_denied')) {
      return 'Access denied by Firestore database rules. Please check your Firestore rules.';
    }
    if (str.contains('configuration_not_found') ||
        str.contains('configuration-not-found') ||
        str.contains('operation-not-allowed')) {
      return 'Email/Password sign-in is not enabled in Firebase Console. Please enable it in Authentication > Sign-in method.';
    }
    if (str.contains('user-not-found')) {
      return 'No account found with this email. Please register first.';
    }
    if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Invalid email or password.';
    }
    if (str.contains('email-already-in-use')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (str.contains('weak-password')) {
      return 'Password must be at least 6 characters long.';
    }
    if (str.contains('network-request-failed') ||
        str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('unable to resolve host')) {
      return 'Network connection unavailable. Please check your internet connection.';
    }
    return 'An unexpected error occurred: ${error.toString().replaceAll('Exception:', '').trim()}';
  }

  // ──────────────────────────────────────────────
  // Owner Account Seeding (Task 6)
  // ──────────────────────────────────────────────

  /// Ensures the hardcoded owner account exists in Firebase Auth and Firestore.
  ///
  /// This is called once on app startup (from main.dart). It is idempotent —
  /// safe to call every run. If the account already exists nothing is changed.
  ///
  /// IMPORTANT: Do NOT remove this without providing an alternative owner
  ///            account management flow. This is the only way owners can log in.
  static const String _ownerEmail    = 'jigneshowner@gmail.com';
  static const String _ownerPassword = 'jignesh123';
  static const String _ownerName     = 'Jignesh (Owner)';

  Future<void> seedOwnerAccount() async {
    // If a user is already logged in, do not perform silent sign-in/sign-out seeding
    if (_auth.currentUser != null) return;

    try {
      // 1. Try to sign in silently — if it works, owner already exists
      final credential = await _auth.signInWithEmailAndPassword(
        email: _ownerEmail,
        password: _ownerPassword,
      );

      // 2. Ensure Firestore profile exists and has role = owner
      if (credential.user != null) {
        final uid = credential.user!.uid;
        final ref = _firestore.collection('users').doc(uid);
        await ref.set({
          'name': _ownerName,
          'phone': '',
          'role': 'owner',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));

        // Sign out so the app starts on the login screen ONLY when not previously logged in
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      // Firebase Auth returns 'invalid-credential' in newer SDKs when user is not found
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        // Account doesn't exist yet — create it
        try {
          final cred = await _auth.createUserWithEmailAndPassword(
            email: _ownerEmail,
            password: _ownerPassword,
          );
          if (cred.user != null) {
            await _firestore.collection('users').doc(cred.user!.uid).set({
              'name': _ownerName,
              'phone': '',
              'role': 'owner',
              'createdAt': Timestamp.fromDate(DateTime.now()),
            });
            await _auth.signOut();
          }
        } catch (_) {
          // Silently fail — app will still work
        }
      }
    } catch (_) {
      // Network error or other issue
    }
  }
}
