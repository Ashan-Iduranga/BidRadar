import 'dart:convert';
import 'dart:io';

import 'package:bidradar/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JSON round trips', () {
    test('Tender keeps a null deadline as "unknown"', () {
      final t = Tender(
        source: TenderSourceType.ted,
        sourceId: '612345-2026',
        title: 'Hospital IT support',
        buyer: 'City of Riga',
        country: 'LVA',
        cpvCodes: const ['72000000'],
        noticeText: 'Minimum 3 years experience.',
        textHash: 'abc',
        fetchedAt: DateTime.utc(2026, 11, 1),
      );
      final back = Tender.fromJson(t.toJson());
      expect(back.id, 'ted_612345-2026');
      expect(back.deadline, isNull);
      expect(back.source, TenderSourceType.ted);
    });

    test('Verdict survives a JSON round trip with criteria and vetoes', () {
      final v = Verdict(
        id: 'v1',
        tenderId: 'ted_1',
        companyId: 'c1',
        verdict: VerdictKind.noBid,
        fitScore: 0,
        criteria: const [
          Criterion(
            criterion: 'Experience',
            quote: 'Minimum 3 years',
            met: CriterionMet.unknown,
          ),
        ],
        missingDocs: const ['Audited accounts'],
        rulesResult: const RulesResult(
          vetoes: [
            RuleVeto(rule: VetoRule.deadlinePassed, message: 'Deadline passed'),
          ],
        ),
        status: VerdictStatus.rulesVeto,
        model: 'rules',
        at: DateTime.utc(2026, 11, 1),
      );
      final back = Verdict.fromJson(
        jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>,
      );
      expect(back.verdict, VerdictKind.noBid);
      expect(back.rulesResult.passed, isFalse);
      expect(back.rulesResult.vetoes.single.rule, VetoRule.deadlinePassed);
      expect(back.criteria.single.quoteVerified, isFalse);
      expect(back.status, VerdictStatus.rulesVeto);
    });

    test('wire values match the Firestore contract', () {
      expect(VerdictKind.noBid.wire, 'NO_BID');
      expect(TenderSourceType.worldBank.wire, 'worldbank');
      expect(UserRole.bidManager.wire, 'bid_manager');
      expect(() => VerdictKind.fromWire('MAYBE'), throwsFormatException);
    });
  });

  test('the 3 sample companies in assets/seed parse', () {
    final raw = jsonDecode(
      File('assets/seed/sample_companies.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = (raw['companies'] as List).cast<Map<String, dynamic>>();
    expect(entries, hasLength(3));
    for (final e in entries) {
      final company = Company.fromJson(e['company'] as Map<String, dynamic>);
      final profile = CompanyProfile.fromJson(
        e['profile'] as Map<String, dynamic>,
      );
      expect(profile.companyId, company.id);
      expect(profile.cpvCodes, everyElement(matches(RegExp(r'^\d{8}$'))));
      expect(profile.countries, everyElement(matches(RegExp(r'^[A-Z]{3}$'))));
    }
  });
}
