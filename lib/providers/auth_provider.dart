import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Service instance provider
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ---------------------------------------------------------------------------
// Firebase auth state stream
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ---------------------------------------------------------------------------
// Current UserModel stream (null if not logged in)
// ---------------------------------------------------------------------------

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authServiceProvider).userModelStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (err, stack) => Stream.value(null),
  );
});

// ---------------------------------------------------------------------------
// Convenience: is current user owner?
// ---------------------------------------------------------------------------

final isOwnerProvider = Provider<bool>((ref) {
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;
  return userModel?.isOwner ?? false;
});

// ---------------------------------------------------------------------------
// Stream of all users (employees + owner) from Firestore
// ---------------------------------------------------------------------------

final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final firestore = ref.watch(authServiceProvider);
  return firestore.streamAllUsers();
});

// ---------------------------------------------------------------------------
// AuthNotifier - handles sign-in, sign-out, and employee creation
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  final AuthService _authService;

  /// Signs the user in with email and password.
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signIn(email, password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Signs up a new user (owner by default) and creates their Firestore record.
  Future<void> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    String role = 'owner',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Creates a new employee account.
  ///
  /// [name]     - Display name of the employee.
  /// [phone]    - Contact phone number.
  /// [email]    - Login e-mail (used as Firebase Auth credential).
  /// [password] - Initial password for the employee account.
  /// [role]     - Role string, e.g. 'employee'.
  Future<void> createEmployee({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.createEmployee(
        name: name,
        phone: phone,
        email: email,
        password: password,
        role: role,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);

