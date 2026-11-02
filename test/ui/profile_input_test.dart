import 'dart:io';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/seed/sample_companies.dart';
import 'package:bidradar/ui/onboarding/onboarding_page.dart' show parseAmount;
import 'package:bidradar/ui/profile/profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileInput.cpv', () {
    test('accepts 8 digits, spaces, or a check digit suffix', () {
      expect(ProfileInput.cpv('72000000', []).code, '72000000');
      expect(ProfileInput.cpv('7200 0000', []).code, '72000000');
      expect(ProfileInput.cpv('72000000-8', []).code, '72000000');
    });

    test('rejects short codes and duplicates with a reason', () {
      expect(ProfileInput.cpv('720', []).error, contains('8 digits'));
      expect(
        ProfileInput.cpv('72000000', ['72000000']).error,
        contains('already'),
      );
    });
  });

  test('ProfileInput.country checks ISO alpha-3', () {
    expect(ProfileInput.country('lka', []).code, 'LKA');
    expect(ProfileInput.country('SL', []).error, contains('Unknown'));
    expect(ProfileInput.country('LKA', ['LKA']).error, contains('Sri Lanka'));
  });

  test('ProfileInput.certification trims and is case-insensitive', () {
    expect(ProfileInput.certification('  ISO   9001 ', []).value, 'ISO 9001');
    expect(
      ProfileInput.certification('iso 9001', ['ISO 9001']).error,
      contains('already'),
    );
    expect(ProfileInput.certification('', []).error, isNotNull);
  });

  test('ProfileEditState is dirty only when the draft differs', () {
    const p = CompanyProfile(
      companyId: 'c',
      cpvCodes: ['72000000'],
      countries: ['LKA'],
    );
    expect(const ProfileEditState(saved: p, draft: p).dirty, isFalse);
    expect(
      ProfileEditState(
        saved: p,
        draft: p.copyWith(countries: ['LKA', 'IND']),
      ).dirty,
      isTrue,
    );
  });

  test('parseAmount handles separators', () {
    expect(parseAmount('850,000'), 850000);
    expect(parseAmount(' 1 200.5 '), 1200.5);
    expect(parseAmount('abc'), isNull);
  });

  test('the 3 seed companies parse and use valid codes', () {
    final samples = SampleCompanies.parse(
      File('assets/seed/sample_companies.json').readAsStringSync(),
    );
    expect(samples, hasLength(3));
    for (final s in samples) {
      for (final c in s.profile.cpvCodes) {
        expect(ProfileInput.cpv(c, []).code, c);
      }
      for (final c in s.profile.countries) {
        expect(ProfileInput.country(c, []).code, c);
      }
    }
  });
}
