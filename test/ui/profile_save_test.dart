import 'dart:async';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/company_repository.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:bidradar/ui/profile/profile_view_model.dart';
import 'package:bidradar/ui/session/session_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const company = Company(
  id: 'c',
  name: 'Small firm',
  country: 'LKA',
  annualTurnover: 100000000,
  currency: 'LKR',
  teamSize: 5,
  ownerUid: 'u',
);

const profile = CompanyProfile(
  companyId: 'c',
  cpvCodes: ['72000000'],
  countries: ['LKA'],
);

/// Firestore offline: writes are kept on the phone and never confirmed.
final _never = Completer<void>().future;

class OfflineProfiles implements ProfileRepository {
  @override
  Stream<CompanyProfile?> watch(String companyId) => Stream.value(profile);

  @override
  Future<void> save(CompanyProfile profile) => _never;
}

class OfflineCompanies extends Fake implements CompanyRepository {
  @override
  Future<void> updateCompany(Company company) => _never;

  @override
  Future<void> invite({
    required Company company,
    required String email,
    required String invitedBy,
  }) => _never;
}

/// The address already holds another company's invite.
class TakenInvites extends OfflineCompanies {
  @override
  Future<void> invite({
    required Company company,
    required String email,
    required String invitedBy,
  }) async => throw InviteTakenException(email);
}

class FakeUser extends Fake implements User {
  @override
  String get uid => 'u';
}

void main() {
  Future<ProviderContainer> ready(
    WidgetTester tester, {
    CompanyRepository? companies,
  }) async {
    final c = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(OfflineProfiles()),
        companyRepositoryProvider.overrideWithValue(
          companies ?? OfflineCompanies(),
        ),
        currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
        currentCompanyProvider.overrideWith((ref) => Stream.value(company)),
        authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
      ],
    );
    addTearDown(c.dispose);
    c.listen(profileViewModelProvider, (_, _) {});
    c.listen(currentCompanyProvider, (_, _) {});
    c.listen(authStateProvider, (_, _) {});
    await tester.pump();
    return c;
  }

  testWidgets('an offline profile save ends, saved on the phone', (
    tester,
  ) async {
    final c = await ready(tester);
    final vm = c.read(profileViewModelProvider.notifier);
    expect(vm.addCountry('IND'), isNull);
    expect(c.read(profileViewModelProvider).dirty, isTrue);

    final saving = vm.save();
    await tester.pump(kSaveWait + const Duration(seconds: 1));
    expect(await saving, kSavedOnPhone);
    final s = c.read(profileViewModelProvider);
    expect(s.saving, isFalse);
    expect(s.dirty, isFalse);
  });

  testWidgets('an offline company update ends, saved on the phone', (
    tester,
  ) async {
    final c = await ready(tester);
    final saving = c
        .read(profileViewModelProvider.notifier)
        .updateCompany(company.copyWith(teamSize: 6));
    await tester.pump(kSaveWait + const Duration(seconds: 1));
    expect(await saving, kSavedOnPhone);
  });

  testWidgets('an offline invite ends, saved on the phone', (tester) async {
    final c = await ready(tester);
    final sending = c
        .read(profileViewModelProvider.notifier)
        .invite('bm@example.com');
    await tester.pump(kSaveWait + const Duration(seconds: 1));
    expect(await sending, kSavedOnPhone);
  });

  testWidgets('an invite held by another company says what to do', (
    tester,
  ) async {
    final c = await ready(tester, companies: TakenInvites());
    final error = await c
        .read(profileViewModelProvider.notifier)
        .invite('bm@example.com');
    expect(error, contains('already has an invite from another company'));
    expect(error, contains('accept or decline it first'));
  });
}
