import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_p_mobile/models/user_model.dart';
import 'package:s_p_mobile/services/auth_service.dart';

void main() {
  group('AuthService error message translations', () {
    test('Translates FirebaseAuthException user-not-found', () {
      final exc = FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
      final msg = AuthService.getReadableErrorMessage(exc);
      expect(msg, contains('No account found with this email'));
    });

    test('Translates FirebaseAuthException wrong-password', () {
      final exc = FirebaseAuthException(
        code: 'wrong-password',
        message: 'Wrong password provided.',
      );
      final msg = AuthService.getReadableErrorMessage(exc);
      expect(msg, contains('Incorrect password'));
    });

    test('Translates FirebaseAuthException email-already-in-use', () {
      final exc = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'Email is already in use.',
      );
      final msg = AuthService.getReadableErrorMessage(exc);
      expect(msg, contains('This email is already registered'));
    });

    test('Translates FirebaseAuthException weak-password', () {
      final exc = FirebaseAuthException(
        code: 'weak-password',
        message: 'Password should be at least 6 characters.',
      );
      final msg = AuthService.getReadableErrorMessage(exc);
      expect(msg, contains('Password must be at least 6 characters'));
    });

    test('Translates CONFIGURATION_NOT_FOUND error', () {
      final exc = FirebaseAuthException(
        code: 'configuration-not-found',
        message: 'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]',
      );
      final msg = AuthService.getReadableErrorMessage(exc);
      expect(msg, contains('Email/Password sign-in is not enabled'));
    });

    test('Translates generic error strings', () {
      final msg = AuthService.getReadableErrorMessage(
        Exception('Something network-request-failed happened'),
      );
      expect(msg, contains('Network connection unavailable'));
    });
  });

  group('UserModel tests', () {
    test('UserModel isOwner logic', () {
      final owner = UserModel(
        uid: 'owner123',
        name: 'Ramesh',
        phone: '9876543210',
        role: 'owner',
        createdAt: DateTime.now(),
      );
      expect(owner.isOwner, isTrue);

      final employee = UserModel(
        uid: 'emp123',
        name: 'Suresh',
        phone: '9876543211',
        role: 'employee',
        createdAt: DateTime.now(),
      );
      expect(employee.isOwner, isFalse);
    });
  });
}
