import 'dart:async';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/company_repository.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:bidradar/ui/session/session_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
}

/// users/{uid} and companies/{id} as streams the test feeds by hand.
class FakeCompanyRepository extends Fake implements CompanyRepository {
  final companyIds = StreamController<String?>.broadcast();
  final companies = StreamController<Company?>.broadcast();

  @override
  Stream<String?> watchCompanyIdForUser(String uid) => companyIds.stream;

  @override
  Stream<Company?> watchCompany(String companyId) => companies.stream;
}

const company = Company(
  id: 'c1',
  name: 'Firm',
  country: 'LKA',
  annualTurnover: 1,
  currency: 'EUR',
  teamSize: 2,
  ownerUid: 'u1',
  members: {'u1': UserRole.owner},
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('signing in shows loading, never onboarding, until the company '
      'arrives', () async {
    final auth = StreamController<User?>.broadcast();
    final repo = FakeCompanyRepository();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        companyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    final seen = <Membership>[];
    // The router listens to these from the start, so they are alive while
    // signed out, as in the app.
    c
      ..listen(currentRoleProvider, (_, _) {})
      ..listen(
        membershipProvider,
        (_, m) => seen.add(m),
        fireImmediately: true,
      );

    auth.add(null);
    await settle();
    expect(c.read(membershipProvider), Membership.none);

    seen.clear();
    auth.add(FakeUser());
    await settle();
    expect(c.read(membershipProvider), Membership.loading);

    repo.companyIds.add('c1');
    await settle();
    expect(c.read(membershipProvider), Membership.loading);

    repo.companies.add(company);
    await settle();
    expect(c.read(membershipProvider), Membership.member);
    expect(seen, isNot(contains(Membership.none)));
  });

  test('a signed-in user without a company is sent to onboarding', () async {
    final repo = FakeCompanyRepository();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
        companyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.listen(membershipProvider, (_, _) {});
    await settle();
    expect(c.read(membershipProvider), Membership.loading);

    repo.companyIds.add(null);
    await settle();
    expect(c.read(membershipProvider), Membership.none);
  });
}
