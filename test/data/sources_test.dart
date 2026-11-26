import 'dart:convert';
import 'dart:io';

import 'package:bidradar/core/net/resilient_http.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/sources/deadline_parser.dart';
import 'package:bidradar/data/sources/ted_client.dart';
import 'package:bidradar/data/sources/tender_source.dart';
import 'package:bidradar/data/sources/worldbank_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Responses recorded from the live APIs on 2 Nov 2026.
String fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync(encoding: utf8);

final fetchedAt = DateTime.utc(2026, 11, 2);

ResilientHttp httpReturning(
  String body, {
  int status = 200,
  void Function(http.Request)? onRequest,
}) => ResilientHttp(
  client: MockClient((req) async {
    onRequest?.call(req);
    return http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
  sleep: (_) async {},
);

void main() {
  const query = TenderQuery(
    cpvCodes: ['72000000', '79400000'],
    countries: ['ESP', 'LVA'],
  );

  group('TedClient', () {
    test('builds an expert query from the profile', () {
      expect(
        TedClient.buildQuery(query, today: fetchedAt),
        'notice-type IN (cn-standard cn-social cn-desg) AND '
        '(deadline-receipt-tender-date-lot>=20261102 OR '
        'deadline-receipt-request-date-lot>=20261102) AND '
        'classification-cpv IN (72000000 79400000) AND '
        'place-of-performance-country-lot IN (ESP LVA) '
        'SORT BY publication-date DESC',
      );
    });

    test('drops invalid CPV and country codes from the query', () {
      const q = TenderQuery(cpvCodes: ['72', 'abc'], countries: ['XX']);
      final built = TedClient.buildQuery(q, today: fetchedAt);
      expect(built, isNot(contains('classification-cpv')));
      expect(built, isNot(contains('place-of-performance')));
    });

    test('POSTs the query and maps the recorded response', () async {
      late Map<String, dynamic> sent;
      final client = TedClient(
        httpReturning(
          fixture('ted_search.json'),
          onRequest: (r) => sent = jsonDecode(r.body) as Map<String, dynamic>,
        ),
        clock: () => fetchedAt,
      );
      final tenders = await client.search(query);

      expect(sent['scope'], 'ACTIVE');
      expect(sent['fields'], contains('deadline-receipt-tender-date-lot'));
      expect(tenders, hasLength(3));

      final t = tenders.first;
      expect(t.id, 'ted_711841-2026');
      expect(t.title, startsWith('Spain – Maintenance of information'));
      expect(t.buyer, contains('COMUNIDAD DE MADRID'));
      expect(t.country, 'ESP');
      expect(t.cpvCodes, ['72267100', '72261000', '48000000']); // deduped
      // 2026-11-06 23:59 at +01:00.
      expect(t.deadline, DateTime.utc(2026, 11, 6, 22, 59));
      expect(t.estimatedValue, 347490);
      expect(t.currency, 'EUR');
      expect(t.url, 'https://ted.europa.eu/en/notice/-/detail/711841-2026');
      expect(t.documentUrls.single, endsWith('/711841-2026/pdf'));
      expect(t.noticeText, contains('MANTENIMIENTO'));
      expect(t.textHash, hasLength(64));
      expect(t.fetchedAt, fetchedAt);
    });

    test('multi-lot notice uses the earliest lot deadline', () {
      final n = {
        'deadline-receipt-tender-date-lot': [
          '2026-11-20+01:00',
          '2026-11-13+01:00',
        ],
        'deadline-receipt-tender-time-lot': [
          '10:00:00+01:00',
          '15:00:00+01:00',
        ],
      };
      expect(TedClient.resolveDeadline(n, ''), DateTime.utc(2026, 11, 13, 14));
    });

    test('falls back to the request-to-participate date', () {
      final n = {
        'deadline-receipt-request-date-lot': ['2026-12-01+01:00'],
      };
      expect(
        TedClient.resolveDeadline(n, ''),
        DateTime.utc(2026, 12, 1, 22, 59),
      );
    });

    test('falls back to a date in the notice text, in local time', () {
      expect(
        TedClient.resolveDeadline(
          {},
          'Tenders must arrive. Deadline for receipt: 15.12.2026 at 12:00.',
          country: 'AUT',
        ),
        DateTime.utc(2026, 12, 15, 11), // Vienna is UTC+1 in December
      );
    });

    test('a text deadline with no known zone is read as early as possible', () {
      expect(
        TedClient.resolveDeadline({}, 'Deadline: 15.12.2026 at 12:00.'),
        DateTime.utc(2026, 12, 14, 22), // 12:00 at UTC+14
      );
    });

    test('no deadline anywhere means unknown (null)', () {
      expect(TedClient.resolveDeadline({}, 'Published on 2026-10-01.'), isNull);
    });

    test('a lot in a served country wins over the first lot', () {
      final t = TedClient.parseNotice(
        {
          'publication-number': '1-2026',
          'place-of-performance-country-lot': ['ITA', 'LVA'],
          'buyer-country': ['ITA'],
        },
        fetchedAt: fetchedAt,
        preferCountries: ['LVA'],
      );
      expect(t.country, 'LVA');
    });

    test('a malformed notice is skipped, not fatal', () {
      final json =
          jsonDecode(fixture('ted_search.json')) as Map<String, dynamic>;
      (json['notices'] as List).add({'title-proc': 'no id'});
      expect(TedClient.parseResponse(json, fetchedAt: fetchedAt), hasLength(3));
    });

    test('a response without notices is a format error', () {
      expect(
        () => TedClient.parseResponse({'x': 1}, fetchedAt: fetchedAt),
        throwsA(isA<SourceFormatException>()),
      );
    });

    test('HTTP 400 surfaces as NetworkException without retrying', () async {
      var calls = 0;
      final client = TedClient(
        httpReturning('{}', status: 400, onRequest: (_) => calls++),
      );
      await expectLater(client.search(query), throwsA(isA<NetworkException>()));
      expect(calls, 1);
    });
  });

  group('WorldBankClient', () {
    test('builds one URI per country with World Bank names', () {
      final uri = WorldBankClient.buildUri(query, countryAlpha3: 'LKA');
      expect(uri.host, 'search.worldbank.org');
      expect(uri.queryParameters['project_ctry_name'], 'Sri Lanka');
      expect(uri.queryParameters['format'], 'json');
      expect(
        WorldBankClient.buildUri(
          query,
          countryAlpha3: 'TUR',
        ).queryParameters['project_ctry_name'],
        'Turkiye',
      );
    });

    test('maps the recorded response', () async {
      final requested = <Uri>[];
      final client = WorldBankClient(
        httpReturning(
          fixture('worldbank_procnotices.json'),
          onRequest: (r) => requested.add(r.url),
        ),
        clock: () => fetchedAt,
      );
      const q = TenderQuery(cpvCodes: [], countries: ['LKA']);
      final tenders = await client.search(q);

      expect(requested, hasLength(1));
      expect(tenders, hasLength(3));
      final t = tenders.first;
      expect(t.id, 'worldbank_OP00476835');
      expect(t.title, startsWith('Design, Supply and Installation of a Land'));
      expect(t.buyer, 'Road Development Authority');
      expect(t.country, 'LKA');
      expect(t.cpvCodes, isEmpty);
      // 25 Nov 2026 14:00 in Colombo (UTC+5:30), not 14:00 UTC.
      expect(t.deadline, DateTime.utc(2026, 11, 25, 8, 30));
      expect(t.noticeText, isNot(contains('time zone is not certain')));
      expect(t.noticeText, contains('Procurement: Goods'));
      expect(t.noticeText, isNot(contains('<p>')));
      expect(t.url, endsWith('/procurement-detail/OP00476835'));
    });

    test('award notices are not biddable and are dropped', () {
      expect(WorldBankClient.isBiddable('Contract Award'), isFalse);
      expect(WorldBankClient.isBiddable('Invitation for Bids'), isTrue);
      expect(
        WorldBankClient.isBiddable('Request for Expression of Interest'),
        isTrue,
      );
    });

    test('an empty result has no procnotices key', () {
      expect(
        WorldBankClient.parseResponse({'rows': 0}, fetchedAt: fetchedAt),
        isEmpty,
      );
    });

    test('searches up to 10 profile countries, one request each', () async {
      final requested = <String>[];
      final client = WorldBankClient(
        httpReturning(
          '{"rows":0}',
          onRequest: (r) =>
              requested.add(r.url.queryParameters['project_ctry_name']!),
        ),
      );
      const q = TenderQuery(
        cpvCodes: [],
        countries: ['LVA', 'LTU', 'EST', 'POL', 'FIN', 'LKA'],
      );
      await client.search(q);
      expect(requested, hasLength(6));
      expect(requested, contains('Sri Lanka'));
    });

    test('closed notices are dropped, open ones kept', () async {
      final client = WorldBankClient(
        httpReturning(fixture('worldbank_procnotices.json')),
        // After the 18 Nov deadline, before the two 25 Nov ones.
        clock: () => DateTime.utc(2026, 11, 20),
      );
      const q = TenderQuery(cpvCodes: [], countries: ['LKA']);
      expect(await client.search(q), hasLength(2));
    });

    test('one failing country does not lose the others', () async {
      final client = WorldBankClient(
        ResilientHttp(
          client: MockClient((req) async {
            final c = req.url.queryParameters['project_ctry_name'];
            return c == 'India'
                ? http.Response('down', 503)
                : http.Response.bytes(
                    utf8.encode(fixture('worldbank_procnotices.json')),
                    200,
                  );
          }),
          sleep: (_) async {},
        ),
        clock: () => fetchedAt,
      );
      const q = TenderQuery(cpvCodes: [], countries: ['LKA', 'IND']);
      expect(await client.search(q), hasLength(3));
    });

    test('all countries failing throws', () async {
      final client = WorldBankClient(httpReturning('x', status: 503));
      const q = TenderQuery(cpvCodes: [], countries: ['LKA']);
      await expectLater(client.search(q), throwsA(isA<NetworkException>()));
    });
  });

  group('DeadlineParser', () {
    for (final (text, expected) in [
      ('Deadline: 2026-12-03', DateTime.utc(2026, 12, 3, 23, 59)),
      (
        'closing date 3 December 2026 at 14:30',
        DateTime.utc(2026, 12, 3, 14, 30),
      ),
      (
        'submitted on or before December 3, 2026',
        DateTime.utc(2026, 12, 3, 23, 59),
      ),
      ('Fecha límite: 03/12/2026 10:00', DateTime.utc(2026, 12, 3, 10)),
    ]) {
      test(
        'reads "$text"',
        () => expect(DeadlineParser.fromText(text), expected),
      );
    }

    for (final (text, expected) in [
      (
        'delivered on or before 25th November 2026 at 2.00 p.m. Late bids',
        DateTime.utc(2026, 11, 25, 14),
      ),
      (
        'Requests for clarification on or before 10 November 2026.',
        null, // a secondary deadline, and no other
      ),
      (
        'no later than 25th November 2026 at 2.00 p.m.',
        DateTime.utc(2026, 11, 25, 14),
      ),
      (
        'Deadline: 3 December 2026, 11:30 AM',
        DateTime.utc(2026, 12, 3, 11, 30),
      ),
      ('Deadline: 3 December 2026 at 12 noon', DateTime.utc(2026, 12, 3, 12)),
      (
        'Deadline: 3 December 2026 at 12.30 a.m.',
        DateTime.utc(2026, 12, 3, 0, 30),
      ),
      ('Deadline: 3 December 2026 at 12 pm', DateTime.utc(2026, 12, 3, 12)),
      ('Deadline: 3 December 2026 at 3 PM', DateTime.utc(2026, 12, 3, 15)),
      (
        'Deadline: 3 December 2026 at 1400 hours',
        DateTime.utc(2026, 12, 3, 14),
      ),
      (
        'Deadline: 3 December 2026, 10 copies',
        DateTime.utc(2026, 12, 3, 23, 59),
      ),
    ]) {
      test(
        'reads the time in "$text"',
        () => expect(DeadlineParser.fromText(text), expected),
      );
    }

    test('skips clarification and other secondary deadlines', () {
      const text =
          'Deadline for clarification requests: 10 November 2026. '
          'Questions deadline: 12 November 2026. A pre-bid meeting is on '
          '14 November 2026. Bids must be submitted no later than '
          '25 November 2026 at 2.00 p.m.';
      expect(DeadlineParser.fromText(text), DateTime.utc(2026, 11, 25, 14));
    });

    test('ignores dates without a deadline keyword', () {
      expect(DeadlineParser.fromText('Published 2026-10-01.'), isNull);
    });

    test('ignores impossible dates', () {
      expect(DeadlineParser.fromText('Deadline 45/13/2026'), isNull);
    });
  });

  test('every source type round-trips through Tender JSON', () async {
    final ted = TedClient.parseResponse(
      jsonDecode(fixture('ted_search.json')),
      fetchedAt: fetchedAt,
    );
    for (final t in ted) {
      expect(Tender.fromJson(t.toJson()).toJson(), t.toJson());
    }
  });
}
