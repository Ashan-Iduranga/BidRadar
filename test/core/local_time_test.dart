import 'package:bidradar/core/geo/local_time.dart';
import 'package:bidradar/data/sources/worldbank_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final wall = DateTime.utc(2026, 11, 25, 14);

  test('a one-zone country gives the exact instant', () {
    final l = LocalTime.toUtc(wall, 'LKA');
    expect(l.utc, DateTime.utc(2026, 11, 25, 8, 30));
    expect(l.exact, isTrue);
  });

  test('summer time is applied', () {
    // Madrid is UTC+2 in July and UTC+1 in November; the Canary Islands
    // are an hour behind, so Spain is not exact and the earlier is used.
    final july = LocalTime.toUtc(DateTime.utc(2026, 7, 1, 12), 'ESP');
    expect(july.utc, DateTime.utc(2026, 7, 1, 10));
    expect(july.exact, isFalse);
    final nov = LocalTime.toUtc(DateTime.utc(2026, 11, 2, 12), 'AUT');
    expect(nov.utc, DateTime.utc(2026, 11, 2, 11));
    expect(nov.exact, isTrue);
  });

  test('a country with zones that disagree uses the earliest instant', () {
    // Indonesia: Jakarta UTC+7 to Jayapura UTC+9.
    final l = LocalTime.toUtc(wall, 'IDN');
    expect(l.utc, DateTime.utc(2026, 11, 25, 5));
    expect(l.exact, isFalse);
  });

  test('zones that agree count as exact', () {
    // Argentina has many zone names, all UTC-3.
    expect(LocalTime.toUtc(wall, 'ARG').exact, isTrue);
  });

  test('an unknown country is read at UTC+14, never late', () {
    final l = LocalTime.toUtc(wall, '');
    expect(l.utc, DateTime.utc(2026, 11, 25));
    expect(l.exact, isFalse);
    expect(LocalTime.uncertainNote(wall), contains('2026-11-25 14:00 local'));
  });

  test('every mapped zone exists in the bundled database', () {
    LocalTime.toUtc(wall, 'LKA'); // loads the database
    for (final zones in kCountryZones.values) {
      for (final z in zones) {
        expect(() => tz.getLocation(z), returnsNormally, reason: z);
      }
    }
  });

  test('a World Bank notice in an unknown region says the time is local', () {
    final t = WorldBankClient.parseNotice({
      'id': 'OP1',
      'notice_type': 'Invitation for Bids',
      'project_ctry_name': 'Eastern and Southern Africa',
      'bid_description': 'Regional data centre',
      'submission_deadline_date': '2026-11-25T00:00:00Z',
      'submission_deadline_time': '14:00',
    }, fetchedAt: DateTime.utc(2026, 11, 2));
    expect(t.country, '');
    expect(t.deadline, DateTime.utc(2026, 11, 25));
    expect(t.noticeText, contains('local time'));
  });
}
