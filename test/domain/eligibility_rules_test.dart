import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/rules/eligibility_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 2, 12);

Company company({double turnover = 850000, String currency = 'EUR'}) => Company(
  id: 'c1',
  name: 'Lanka Code Works',
  country: 'LKA',
  annualTurnover: turnover,
  currency: currency,
  teamSize: 28,
  ownerUid: 'u1',
);

CompanyProfile profile({
  List<String> cpv = const ['72000000', '48000000'],
  List<String> countries = const ['LKA', 'IND'],
}) => CompanyProfile(companyId: 'c1', cpvCodes: cpv, countries: countries);

Tender tender({
  DateTime? deadline,
  bool noDeadline = false,
  String country = 'LKA',
  List<String> cpv = const ['72267100'],
  double? minTurnover,
  String? currency = 'EUR',
}) => Tender(
  source: TenderSourceType.ted,
  sourceId: '1-2026',
  title: 'Software maintenance',
  buyer: 'Ministry',
  country: country,
  cpvCodes: cpv,
  deadline: noDeadline ? null : (deadline ?? now.add(const Duration(days: 20))),
  minTurnover: minTurnover,
  currency: currency,
  noticeText: 'text',
  textHash: 'h',
  fetchedAt: now,
);

void main() {
  const rules = EligibilityRules();

  RulesResult check(Tender t, {Company? c, CompanyProfile? p}) => rules.check(
    company: c ?? company(),
    profile: p ?? profile(),
    tender: t,
    now: now,
  );

  Set<VetoRule> vetoes(RulesResult r) => r.vetoes.map((v) => v.rule).toSet();

  test('an eligible tender passes with no warnings', () {
    final r = check(tender());
    expect(r.passed, isTrue);
    expect(r.warnings, isEmpty);
  });

  group('deadline', () {
    test('passed deadline is vetoed', () {
      final r = check(tender(deadline: now.subtract(const Duration(days: 1))));
      expect(vetoes(r), {VetoRule.deadlinePassed});
      expect(r.vetoes.single.message, contains('Nov 1, 2026'));
    });

    test('deadline exactly now is vetoed (boundary)', () {
      expect(vetoes(check(tender(deadline: now))), {VetoRule.deadlinePassed});
    });

    test('one second before the deadline still passes', () {
      final r = check(tender(deadline: now.add(const Duration(seconds: 1))));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('less than 72 hours'));
    });

    test('deadline in another time zone is compared in UTC', () {
      // 12:30 at +01:00 is 11:30 UTC, which is before now (12:00 UTC).
      final d = DateTime.parse('2026-11-02T12:30:00+01:00');
      expect(vetoes(check(tender(deadline: d))), {VetoRule.deadlinePassed});
    });

    test('unknown deadline warns but never vetoes', () {
      final r = check(tender(noDeadline: true));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('Deadline unknown'));
    });
  });

  group('country', () {
    test('country not served is vetoed', () {
      final r = check(tender(country: 'ESP'));
      expect(vetoes(r), {VetoRule.countryNotServed});
      expect(r.vetoes.single.message, contains('Spain'));
    });

    test('unknown country warns', () {
      final r = check(tender(country: ''));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('Country not stated'));
    });

    test('profile without countries warns instead of vetoing', () {
      final r = check(
        tender(country: 'ESP'),
        p: profile(countries: []),
      );
      expect(r.passed, isTrue);
      expect(r.warnings, isNotEmpty);
    });
  });

  group('sector (CPV)', () {
    test('sub-code of a profile code matches', () {
      expect(check(tender(cpv: ['72267100'])).passed, isTrue);
    });

    test('broader tender code matches a narrower profile code', () {
      final r = check(
        tender(cpv: ['72000000']),
        p: profile(cpv: ['72260000']),
      );
      expect(r.passed, isTrue);
    });

    test('unrelated sector is vetoed', () {
      final r = check(tender(cpv: ['45000000', '45310000']));
      expect(vetoes(r), {VetoRule.sectorMismatch});
      expect(r.vetoes.single.message, contains('45000000'));
    });

    test('same division but different group does not match', () {
      // 72200000 (software) vs 72500000 (computer-related services).
      final r = check(
        tender(cpv: ['72500000']),
        p: profile(cpv: ['72200000']),
      );
      expect(vetoes(r), {VetoRule.sectorMismatch});
    });

    test('tender without CPV codes (World Bank) warns', () {
      final r = check(tender(cpv: []));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('No CPV codes'));
    });

    test('cpvPrefix keeps at least the 2-digit division', () {
      expect(EligibilityRules.cpvPrefix('72000000'), '72');
      expect(EligibilityRules.cpvPrefix('72267100'), '722671');
      expect(EligibilityRules.cpvPrefix('70000000'), '70');
    });
  });

  group('turnover', () {
    test('no minimum in the notice: nothing to check', () {
      expect(check(tender()).warnings, isEmpty);
    });

    test('below the minimum in the same currency is vetoed', () {
      final r = check(tender(minTurnover: 1000000));
      expect(vetoes(r), {VetoRule.turnoverBelowMinimum});
    });

    test('exactly the minimum passes', () {
      expect(check(tender(minTurnover: 850000)).passed, isTrue);
    });

    test('missing company turnover warns instead of vetoing', () {
      final r = check(tender(minTurnover: 1000000), c: company(turnover: 0));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('Add your yearly turnover'));
    });

    test('minimum without a currency warns', () {
      final r = check(tender(minTurnover: 1000000, currency: null));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('no currency'));
    });

    test('cross-currency: clearly short is vetoed', () {
      // 850k EUR is about 924k USD; needs 2M USD.
      final r = check(tender(minTurnover: 2000000, currency: 'USD'));
      expect(vetoes(r), {VetoRule.turnoverBelowMinimum});
    });

    test('cross-currency within the 10% FX margin only warns', () {
      // About 924k USD against a 1M USD minimum: 7.6% short.
      final r = check(tender(minTurnover: 1000000, currency: 'USD'));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('close to the minimum'));
    });

    test('unknown currency pair warns', () {
      final r = check(tender(minTurnover: 1000, currency: 'XYZ'));
      expect(r.passed, isTrue);
      expect(r.warnings.single, contains('Cannot compare'));
    });
  });

  test('several failures are all reported', () {
    final r = check(
      tender(
        deadline: now.subtract(const Duration(hours: 1)),
        country: 'ESP',
        cpv: ['45000000'],
        minTurnover: 5000000,
      ),
    );
    expect(vetoes(r), VetoRule.values.toSet());
  });

  test('rules are pure: same input, same output', () {
    final t = tender(country: 'ESP');
    expect(check(t).toJson(), check(t).toJson());
  });
}
