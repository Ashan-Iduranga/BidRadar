import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/seed/sample_companies.dart';
import '../auth/auth_providers.dart';

/// What the onboarding page shows: a pending invite (if any) and the
/// sample companies a new owner can start from.
class OnboardingData {
  const OnboardingData({
    required this.invite,
    required this.samples,
    this.emailVerified = true,
  });
  final Invite? invite;
  final List<SampleCompany> samples;

  /// Joining needs a verified email. Until then the invite card asks the
  /// user to verify instead of offering Join.
  final bool emailVerified;
}

/// The invite for the signed-in email, live. Phone 2 can sign up first:
/// the invite shows up as soon as the owner sends it.
final pendingInviteProvider = StreamProvider.autoDispose<Invite?>((ref) {
  final email = ref.watch(authStateProvider.select((a) => a.value?.email));
  if (email == null || email.isEmpty) return Stream.value(null);
  return ref.watch(companyRepositoryProvider).watchInvite(email);
});

final sampleCompaniesProvider = FutureProvider<List<SampleCompany>>(
  (ref) => SampleCompanies.load(),
);

class OnboardingViewModel extends AsyncNotifier<OnboardingData> {
  @override
  Future<OnboardingData> build() async {
    // Watched, so the page updates when an invite arrives or goes away,
    // and when the email becomes verified.
    final verified = ref.watch(emailVerifiedProvider);
    final samples = ref.watch(sampleCompaniesProvider.future);
    final invite = ref.watch(pendingInviteProvider.future);
    Invite? found;
    try {
      found = await invite;
    } on Object {
      found = null; // No invite readable; show the create form.
    }
    return OnboardingData(
      invite: found,
      samples: await samples,
      emailVerified: verified,
    );
  }

  User get _user {
    final u = ref.read(authStateProvider).value;
    if (u == null) throw StateError('Not signed in');
    return u;
  }

  /// Returns an error message, or null on success. The router moves on by
  /// itself once the membership stream sees the new company.
  Future<String?> createCompany({
    required String name,
    required String country,
    required double annualTurnover,
    required String currency,
    required int teamSize,
    CompanyProfile? profile,
  }) => _guard(
    () => ref
        .read(companyRepositoryProvider)
        .createCompany(
          uid: _user.uid,
          email: _user.email ?? '',
          name: name,
          country: country,
          annualTurnover: annualTurnover,
          currency: currency,
          teamSize: teamSize,
          profile: profile,
        ),
  );

  Future<String?> startFromSample(SampleCompany s) => createCompany(
    name: s.company.name,
    country: s.company.country,
    annualTurnover: s.company.annualTurnover,
    currency: s.company.currency,
    teamSize: s.company.teamSize,
    profile: s.profile,
  );

  Future<String?> acceptInvite(Invite invite) {
    if (!ref.read(emailVerifiedProvider)) {
      return Future.value('Verify your email first, then tap I have verified.');
    }
    return _guard(
      () => ref
          .read(companyRepositoryProvider)
          .acceptInvite(
            invite: invite,
            uid: _user.uid,
            email: _user.email ?? '',
          ),
      denied:
          'Could not join. If you just verified your email, tap I have '
          'verified and try again.',
    );
  }

  /// "I have verified": reloads the account and refreshes the token the
  /// rules read. Returns a message when the email is still not verified.
  Future<String?> confirmVerified() async {
    try {
      final ok = await ref.read(emailVerifiedProvider.notifier).recheck();
      return ok
          ? null
          : 'Not verified yet. Open the link in the email we sent, then '
                'try again.';
    } on FirebaseException catch (e) {
      return 'Could not check (${e.code}). Check your connection and try '
          'again.';
    }
  }

  /// Sends the verification email again. Returns what to tell the user.
  Future<String> resendVerification() async {
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      return 'Sent. Check your inbox, and the spam folder too.';
    } on FirebaseException catch (e) {
      return e.code == 'too-many-requests'
          ? 'Too many emails sent. Wait a minute, then try again.'
          : 'Could not send the email (${e.code}).';
    }
  }

  Future<String?> declineInvite(Invite invite) {
    if (!ref.read(emailVerifiedProvider)) {
      return Future.value('Verify your email first, then tap I have verified.');
    }
    return _guard(
      () => ref.read(companyRepositoryProvider).declineInvite(invite),
    );
  }

  Future<String?> _guard(
    Future<Object?> Function() action, {
    String denied = 'You do not have permission to do that.',
  }) async {
    try {
      await action();
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? denied
          : 'Could not save (${e.code}). Check your connection and try again.';
    }
  }
}

/// Auto-disposed, so the invite listener ends when onboarding is left.
final onboardingViewModelProvider =
    AsyncNotifierProvider.autoDispose<OnboardingViewModel, OnboardingData>(
      OnboardingViewModel.new,
    );
