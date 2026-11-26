import 'dart:async';

import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/company_repository.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:bidradar/ui/onboarding/onboarding_page.dart';
import 'package:bidradar/ui/onboarding/onboarding_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser extends Fake implements User {
  FakeUser({this.emailVerified = true});

  @override
  final bool emailVerified;

  @override
  String get uid => 'bm';

  @override
  String get email => 'bm@firm.test';
}

class FakeCompanyRepository extends Fake implements CompanyRepository {
  FakeCompanyRepository(this.invites);

  final Stream<Invite?> invites;
  final declined = <Invite>[];
  final watchedEmails = <String>[];

  @override
  Stream<Invite?> watchInvite(String email) {
    watchedEmails.add(email);
    return invites;
  }

  @override
  Future<void> declineInvite(Invite invite) async => declined.add(invite);
}

/// Verifies on the first recheck, as if the user opened the link.
class FakeAuthService implements AuthService {
  var sent = 0;
  var checks = 0;

  @override
  Future<void> sendEmailVerification() async => sent++;

  @override
  Future<bool> refreshEmailVerified() async {
    checks++;
    return true;
  }
}

final invite = Invite(
  email: 'bm@firm.test',
  companyId: 'c1',
  companyName: 'Firm',
  invitedBy: 'owner',
  createdAt: DateTime.utc(2026, 11, 26),
);

/// Lets streams and rebuilds run until [done] holds.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

ProviderContainer containerFor(
  CompanyRepository repo, {
  User? user,
  AuthService? auth,
}) {
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(user ?? FakeUser())),
      companyRepositoryProvider.overrideWithValue(repo),
      sampleCompaniesProvider.overrideWith((ref) async => const []),
      authServiceProvider.overrideWithValue(auth ?? FakeAuthService()),
    ],
  );
  addTearDown(c.dispose);
  // Keep the auto-disposed view model alive, as the page does.
  c.listen(onboardingViewModelProvider, (_, _) {});
  return c;
}

void main() {
  test('an invite sent after sign-up shows up without a restart', () async {
    final invites = StreamController<Invite?>();
    addTearDown(invites.close);
    final repo = FakeCompanyRepository(invites.stream);
    final c = containerFor(repo);

    invites.add(null);
    await until(() => c.read(onboardingViewModelProvider).hasValue);
    expect(c.read(onboardingViewModelProvider).value!.invite, isNull);
    expect(repo.watchedEmails, ['bm@firm.test']);

    // The owner sends the invite while phone 2 sits on onboarding.
    invites.add(invite);
    await until(
      () => c.read(onboardingViewModelProvider).value?.invite != null,
    );
    expect(
      c.read(onboardingViewModelProvider).value!.invite!.companyName,
      'Firm',
    );

    // Accepted or declined elsewhere: it goes away again.
    invites.add(null);
    await until(
      () => c.read(onboardingViewModelProvider).value?.invite == null,
    );
    expect(c.read(onboardingViewModelProvider).value!.invite, isNull);
  });

  test('declining deletes the invite', () async {
    final repo = FakeCompanyRepository(Stream.value(invite));
    final c = containerFor(repo);
    await until(() => c.read(onboardingViewModelProvider).hasValue);

    final error = await c
        .read(onboardingViewModelProvider.notifier)
        .declineInvite(invite);

    expect(error, isNull);
    expect(repo.declined, [invite]);
  });

  test('an unverified invitee is asked to verify, not to join', () async {
    final repo = FakeCompanyRepository(Stream.value(invite));
    final auth = FakeAuthService();
    final c = containerFor(
      repo,
      user: FakeUser(emailVerified: false),
      auth: auth,
    );
    await until(
      () => c.read(onboardingViewModelProvider).value?.invite != null,
    );
    final vm = c.read(onboardingViewModelProvider.notifier);
    expect(c.read(onboardingViewModelProvider).value!.emailVerified, isFalse);

    // Join and Decline are refused before the repository is touched.
    expect(await vm.acceptInvite(invite), contains('Verify your email'));
    expect(await vm.declineInvite(invite), contains('Verify your email'));
    expect(repo.declined, isEmpty);

    expect(await vm.resendVerification(), contains('Sent'));
    expect(auth.sent, 1);

    expect(await vm.confirmVerified(), isNull);
    await until(
      () => c.read(onboardingViewModelProvider).value?.emailVerified ?? false,
    );
    expect(c.read(onboardingViewModelProvider).value!.emailVerified, isTrue);
  });

  testWidgets('I have verified turns the card into Join', (tester) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(FakeUser(emailVerified: false)),
          ),
          companyRepositoryProvider.overrideWithValue(
            FakeCompanyRepository(Stream.value(invite)),
          ),
          sampleCompaniesProvider.overrideWith((ref) async => const []),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OnboardingPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('I have verified'), findsOneWidget);
    expect(find.text('Join Firm'), findsNothing);
    expect(find.textContaining('bm@firm.test'), findsOneWidget);

    await tester.tap(find.text('I have verified'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.checks, 1);
    expect(find.text('Join Firm'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
