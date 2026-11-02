import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../data/seed/sample_companies.dart';
import '../auth/auth_providers.dart';

/// What the onboarding page shows: a pending invite (if any) and the
/// sample companies a new owner can start from.
class OnboardingData {
  const OnboardingData({required this.invite, required this.samples});
  final Invite? invite;
  final List<SampleCompany> samples;
}

class OnboardingViewModel extends AsyncNotifier<OnboardingData> {
  @override
  Future<OnboardingData> build() async {
    final email = ref.watch(authStateProvider).value?.email;
    final samples = await SampleCompanies.load();
    Invite? invite;
    if (email != null) {
      try {
        invite = await ref.read(companyRepositoryProvider).findInvite(email);
      } on Object {
        invite = null; // No invite readable; show the create form.
      }
    }
    return OnboardingData(invite: invite, samples: samples);
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

  Future<String?> acceptInvite(Invite invite) => _guard(
    () => ref
        .read(companyRepositoryProvider)
        .acceptInvite(invite: invite, uid: _user.uid, email: _user.email ?? ''),
  );

  Future<String?> _guard(Future<Object?> Function() action) async {
    try {
      await action();
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You do not have permission to do that.'
          : 'Could not save (${e.code}). Check your connection and try again.';
    }
  }
}

final onboardingViewModelProvider =
    AsyncNotifierProvider<OnboardingViewModel, OnboardingData>(
      OnboardingViewModel.new,
    );
