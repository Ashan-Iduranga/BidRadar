/// Last-resort deadline extraction from free notice text, used when the
/// source has no structured deadline. Only dates that follow a deadline
/// keyword count, so publication dates are not mistaken for deadlines.
/// Returns null when nothing is found; the tender is then "deadline unknown".
abstract final class DeadlineParser {
  static final _keyword = RegExp(
    r'\b(deadline|closing date|closing time|submission date|submitted (?:on or )?before|'
    r'not later than|no later than|last date|due date|'
    r'plazo|fecha l[ií]mite|date limite|termin\b|frist\b|lhůta|'
    r'termiņš|termin składania)',
    caseSensitive: false,
  );

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // 2026-11-20 | 20/11/2026 | 20.11.2026 | 20-11-2026 | 20 November 2026 |
  // November 20, 2026
  static final _date = RegExp(
    r'(\d{4})-(\d{1,2})-(\d{1,2})'
    r'|(\d{1,2})[./-](\d{1,2})[./-](\d{4})'
    r'|(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9}),?\s+(\d{4})'
    r'|([A-Za-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
  );

  static final _time = RegExp(r'^\D{0,20}?(\d{1,2})[:.h](\d{2})');

  /// How far after a keyword a date may appear.
  static const window = 120;

  static DateTime? fromText(String text) {
    for (final k in _keyword.allMatches(text)) {
      final end = (k.end + window).clamp(0, text.length);
      final slice = text.substring(k.end, end);
      final m = _date.firstMatch(slice);
      if (m == null) continue;
      final date = _toDate(m);
      if (date == null) continue;
      final t = _time.firstMatch(slice.substring(m.end));
      final hour = int.tryParse(t?[1] ?? '') ?? 23;
      final minute = int.tryParse(t?[2] ?? '') ?? 59;
      if (hour > 23 || minute > 59) {
        return DateTime.utc(date.year, date.month, date.day, 23, 59);
      }
      return DateTime.utc(date.year, date.month, date.day, hour, minute);
    }
    return null;
  }

  static DateTime? _toDate(RegExpMatch m) {
    int? y, mo, d;
    if (m[1] != null) {
      y = int.parse(m[1]!);
      mo = int.parse(m[2]!);
      d = int.parse(m[3]!);
    } else if (m[4] != null) {
      // Day first, as in EU and South Asian notices.
      d = int.parse(m[4]!);
      mo = int.parse(m[5]!);
      y = int.parse(m[6]!);
    } else if (m[7] != null) {
      d = int.parse(m[7]!);
      mo = _month(m[8]!);
      y = int.parse(m[9]!);
    } else {
      mo = _month(m[10]!);
      d = int.parse(m[11]!);
      y = int.parse(m[12]!);
    }
    if (mo == null || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    if (y < 2000 || y > 2100) return null;
    return DateTime.utc(y, mo, d);
  }

  static int? _month(String name) =>
      _months[name.toLowerCase().substring(0, 3)];
}
