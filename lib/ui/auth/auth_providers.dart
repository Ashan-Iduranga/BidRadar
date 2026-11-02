import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_bootstrap.dart';

/// Signed-in user, or null. Always null when Firebase is not configured.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

/// Sign-in page ViewModel: holds loading and error state for the form.
class SignInViewModel extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn(String email, String password) => _run(
    () => FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    ),
  );

  Future<void> signUp(String email, String password) => _run(
    () => FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    ),
  );

  Future<void> _run(Future<Object?> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await action();
      } on FirebaseAuthException catch (e) {
        throw AuthFailure(_message(e.code));
      }
    });
  }

  static String _message(String code) => switch (code) {
    'invalid-email' => 'That email address is not valid.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email or password is incorrect.',
    'email-already-in-use' =>
      'An account already uses this email. '
          'Sign in instead.',
    'weak-password' => 'Use at least 6 characters for the password.',
    'network-request-failed' =>
      'No connection. Check your internet and '
          'try again.',
    _ => 'Sign-in failed ($code). Try again.',
  };
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final signInViewModelProvider = AsyncNotifierProvider<SignInViewModel, void>(
  SignInViewModel.new,
);
