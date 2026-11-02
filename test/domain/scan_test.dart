import 'dart:io';
import 'dart:typed_data';

import 'package:bidradar/core/text/text_utils.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/rules/eligibility_rules.dart';
import 'package:bidradar/domain/scan/scan.dart';
import 'package:bidradar/ui/scan/scan_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const ocr =
    'INVITATION FOR BIDS. Ministry of Health. Bidders must hold ISO 9001 '
    'certification. Bids must be submitted no later than 28 November 2026.';

class FakeOcr implements TextOcr {
  FakeOcr(this.text);
  final String text;
  @override
  Future<String> read(String imagePath) async => text;
}

class FakeReader implements NoticeReader {
  FakeReader({this.fail = false});
  final bool fail;
  @override
  Future<ScannedNotice> read({
    required Uint8List image,
    required String mimeType,
    required String ocrText,
  }) async {
    if (fail) throw Exception('quota');
    return ScannedNotice.fromJson(const {
      'title': 'Hospital appointment system',
      'buyer': 'Ministry of Health',
      'deadline': '2026-11-28T14:00:00',
      'country': 'lka',
      'requirements': ['Bidders must hold ISO 9001 certification'],
      'minTurnover': 150000000,
      'currency': 'lkr',
    });
  }
}

void main() {
  group('ScannedNotice.fromJson is lenient', () {
    test('valid fields are kept and normalised', () {
      final n = ScannedNotice.fromJson(const {
        'title': ' X ',
        'buyer': 'B',
        'deadline': '2026-11-28T14:00:00',
        'country': 'lka',
        'requirements': ['a', ' ', 3],
        'minTurnover': 1000,
        'currency': 'usd',
        'cpvCodes': ['72000000-8', 'abc'],
      });
      expect(n.title, 'X');
      expect(n.country, 'LKA');
      expect(n.deadline, DateTime(2026, 11, 28, 14));
      expect(n.requirements, ['a']);
      expect(n.currency, 'USD');
      expect(n.cpvCodes, ['72000000']);
    });

    test('bad fields become empty instead of failing', () {
      final n = ScannedNotice.fromJson(const {
        'title': 5,
        'deadline': 'next Friday',
        'country': 'Sri Lanka',
        'minTurnover': -3,
        'currency': 'rupees',
      });
      expect(n.title, '');
      expect(n.deadline, isNull);
      expect(n.country, '');
      expect(n.minTurnover, isNull);
      expect(n.currency, isNull);
    });
  });

  group('ScanDraft', () {
    ScanDraft draft({String buyer = 'Ministry', DateTime? deadline}) =>
        ScanDraft(
          title: 'Hospital system',
          buyer: buyer,
          deadline: deadline ?? DateTime(2026, 11, 28, 14),
          country: 'LKA',
          ocrText: ocr,
          minTurnover: 150000000,
          currency: 'LKR',
        );

    test('buyer and deadline must be confirmed', () {
      expect(draft().problems, isEmpty);
      expect(draft(buyer: ' ').problems, ['Confirm the buyer.']);
    });

    test('becomes a scan tender whose notice text is the OCR text', () {
      final t = draft().toTender(DateTime.utc(2026, 11, 2));
      expect(t.source, TenderSourceType.scan);
      expect(t.noticeText, ocr);
      expect(t.textHash, TextUtils.hash(ocr));
      expect(t.id, 'scan_${TextUtils.hash(ocr).substring(0, 16)}');
      expect(t.minTurnover, 150000000);
      expect(t.currency, 'LKR');
    });

    test('the same page scanned twice gets the same id', () {
      expect(
        draft().toTender(DateTime.utc(2026)).id,
        draft(buyer: 'Other').toTender(DateTime.utc(2027)).id,
      );
    });

    test('the turnover rule now applies to scanned tenders', () {
      const company = Company(
        id: 'c',
        name: 'Small firm',
        country: 'LKA',
        annualTurnover: 100000,
        currency: 'EUR', // about LKR 32M, below LKR 150M
        teamSize: 5,
        ownerUid: 'u',
      );
      const profile = CompanyProfile(
        companyId: 'c',
        cpvCodes: [],
        countries: ['LKA'],
      );
      final r = const EligibilityRules().check(
        company: company,
        profile: profile,
        tender: draft().toTender(DateTime.utc(2026, 11, 2)),
        now: DateTime.utc(2026, 11, 2),
      );
      expect(r.vetoes.single.rule, VetoRule.turnoverBelowMinimum);
    });
  });

  group('ScanViewModel', () {
    late File photo;
    setUp(() async {
      photo = File('${Directory.systemTemp.path}/br_scan_test.jpg');
      await photo.writeAsBytes([1, 2, 3]);
    });

    ProviderContainer container({TextOcr? ocrImpl, NoticeReader? reader}) {
      final c = ProviderContainer(
        overrides: [
          textOcrProvider.overrideWithValue(ocrImpl ?? FakeOcr(ocr)),
          noticeReaderProvider.overrideWithValue(reader ?? FakeReader()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('OCR then AI gives a review with the fields filled', () async {
      final c = container();
      await c.read(scanViewModelProvider.notifier).process(photo.path);
      final s = c.read(scanViewModelProvider) as ScanReview;
      expect(s.aiFailed, isFalse);
      expect(s.read.buyer, 'Ministry of Health');
      expect(s.read.country, 'LKA');
      expect(s.ocrText, ocr);
    });

    test('if the AI fails the user can still fill the form', () async {
      final c = container(reader: FakeReader(fail: true));
      await c.read(scanViewModelProvider.notifier).process(photo.path);
      final s = c.read(scanViewModelProvider) as ScanReview;
      expect(s.aiFailed, isTrue);
      expect(s.read.title, '');
      expect(s.ocrText, ocr);
    });

    test('an unreadable photo fails with advice', () async {
      final c = container(ocrImpl: FakeOcr('   '));
      await c.read(scanViewModelProvider.notifier).process(photo.path);
      final s = c.read(scanViewModelProvider) as ScanFailed;
      expect(s.message, contains('good light'));
    });
  });
}
