import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/logging/log.dart';
import '../../data/local/app_database.dart';
import '../../data/providers.dart';

/// Signed-in user, or null. Always null when Firebase is not configured.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

/// Sign-in page ViewModel: holds loading and error state for the form.
class SignInViewModel extends AsyncNotifier<void> {
  // Synchronous on purpose: an async build starts in a loading state,
  // which drew the Sign in buttons disabled for the first frames.
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) => _run(
    () => FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    ),
  );

  /// Also sends the verification email: joining a team by invite needs a
  /// verified address. If sending fails, sign-up still succeeds and
  /// onboarding offers Resend.
  Future<void> signUp(String email, String password) => _run(() async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await cred.user?.sendEmailVerification();
    } on Object catch (e) {
      Log.warn('auth', 'verification email not sent: $e');
    }
    return cred;
  });

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

/// Account calls besides sign-in. An interface so tests can fake it.
abstract interface class AuthService {
  /// The only way the app signs out: clears what this phone kept for the
  /// user (see [clearLocalData]), then signs out of Firebase.
  Future<void> signOut();

  Future<void> sendEmailVerification();

  /// Reloads the user and forces a new ID token, so the `email_verified`
  /// claim the security rules read is current. True when verified now.
  Future<bool> refreshEmailVerified();
}

class FirebaseAuthService implements AuthService {
  /// [_clearLocal] deletes the phone's local data; see [clearLocalData].
  FirebaseAuthService(this._auth, this._clearLocal);

  final FirebaseAuth _auth;
  final Future<void> Function() _clearLocal;

  /// Signs out even if clearing fails: staying signed in would be worse.
  @override
  Future<void> signOut() async {
    try {
      await _clearLocal();
    } on Object catch (e, st) {
      Log.error('auth', 'could not clear local data on sign-out', e, st);
    }
    await _auth.signOut();
  }

  @override
  Future<void> sendEmailVerification() async =>
      _auth.currentUser?.sendEmailVerification();

  @override
  Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return false;
    await user.getIdToken(true);
    return true;
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(
    FirebaseAuth.instance,
    () => clearLocalData(ref.read(appDatabaseProvider)),
  ),
);

/// Deletes what this phone keeps for the signed-in user: the tender cache,
/// the verdict cache and the sync log. The next user on the phone starts
/// clean, and their first sync fetches and judges for their own company.
/// Uses drift's generated tables, so added columns do not affect it.
Future<void> clearLocalData(AppDatabase db) => db.transaction(() async {
  await db.delete(db.cachedVerdicts).go();
  await db.delete(db.cachedTenders).go();
  await db.delete(db.syncRuns).go();
});

/// Whether the signed-in user's email is verified. Joining a team by
/// invite needs it. Starts from the signed-in user and is updated by
/// [EmailVerified.recheck] after the user opens the link.
class EmailVerified extends Notifier<bool> {
  @override
  bool build() => ref.watch(authStateProvider).value?.emailVerified ?? false;

  /// Returns whether the email is verified now.
  Future<bool> recheck() async {
    final verified = await ref.read(authServiceProvider).refreshEmailVerified();
    if (ref.mounted) state = verified;
    return verified;
  }
}

final emailVerifiedProvider = NotifierProvider.autoDispose<EmailVerified, bool>(
  EmailVerified.new,
);
