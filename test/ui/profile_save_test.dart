import 'dart:async';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/company_repository.dart';
import 'package:bidradar/ui/profile/profile_view_model.dart';
import 'package:bidradar/ui/session/session_providers.dart';
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
}

void main() {
  Future<ProviderContainer> ready(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(OfflineProfiles()),
        companyRepositoryProvider.overrideWithValue(OfflineCompanies()),
        currentProfileProvider.overrideWith((ref) => Stream.value(profile)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(profileViewModelProvider, (_, _) {});
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
}
