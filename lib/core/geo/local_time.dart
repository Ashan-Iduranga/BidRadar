/// Converts a local wall-clock time in a country to a UTC instant, using the
/// IANA time zone database from the timezone package.
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

part 'time_zones_data.dart';

/// A local deadline converted to UTC.
class LocalInstant {
  const LocalInstant(this.utc, {required this.exact});

  final DateTime utc;

  /// False when the zone is not certain (a country with several zones that
  /// disagree, or an unknown country). [utc] is then the earliest instant the
  /// local time could mean, so a tender never counts as open after it closed.
  final bool exact;
}

abstract final class LocalTime {
  /// The most eastern offset in use, UTC+14 (Pacific/Kiritimati). A local
  /// time read at this offset is the earliest instant it can mean anywhere.
  static const _earliestOffset = Duration(hours: 14);

  /// Converts [wall] (its year to minute fields are the local time; its
  /// zone is ignored) to UTC for [countryAlpha3].
  ///
  /// A country with one zone, or several that agree at that moment, gives
  /// an exact instant. Otherwise the earliest instant among its zones is
  /// used, and for an unknown country the earliest instant on Earth.
  static LocalInstant toUtc(DateTime wall, String countryAlpha3) {
    final zones = kCountryZones[countryAlpha3.toUpperCase()];
    if (zones == null || zones.isEmpty) {
      return LocalInstant(
        _wallAsUtc(wall).subtract(_earliestOffset),
        exact: false,
      );
    }
    _ensureDatabase();
    final instants = [for (final z in zones) _inZone(wall, z)]..sort();
    return LocalInstant(instants.first, exact: instants.first == instants.last);
  }

  /// A line for the notice text when [wall] could not be placed in one
  /// time zone, so the reader knows the deadline shown may be early.
  static String uncertainNote(DateTime wall) {
    String two(int v) => '$v'.padLeft(2, '0');
    final printed =
        '${wall.year}-${two(wall.month)}-${two(wall.day)} '
        '${two(wall.hour)}:${two(wall.minute)}';
    return 'Deadline as printed: $printed local time. The time zone is not '
        'certain, so BidRadar shows the earliest time this can mean.';
  }

  static DateTime _wallAsUtc(DateTime w) =>
      DateTime.utc(w.year, w.month, w.day, w.hour, w.minute);

  static DateTime _inZone(DateTime w, String zone) {
    final t = tz.TZDateTime(
      tz.getLocation(zone),
      w.year,
      w.month,
      w.day,
      w.hour,
      w.minute,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      t.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  /// Loads the zone database once per isolate. The notification service may
  /// already have loaded the same data; loading it again would only reset
  /// the local zone, so it is skipped.
  static void _ensureDatabase() {
    if (tz.timeZoneDatabase.locations.isEmpty) tzdata.initializeTimeZones();
  }
}
