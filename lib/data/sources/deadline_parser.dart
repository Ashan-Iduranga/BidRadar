/// Last-resort deadline extraction from free notice text, used when the
/// source has no structured deadline. Only dates that follow a deadline
/// keyword count, so publication dates are not mistaken for deadlines, and
/// secondary deadlines (clarification questions, pre-bid meetings, site
/// visits) are skipped. Returns null when nothing is found; the tender is
/// then "deadline unknown".
///
/// The result is the notice's local wall-clock time: its fields are the
/// local date and time, wrapped in a UTC DateTime. Convert it with
/// `LocalTime.toUtc` and the buyer's country before comparing instants.
abstract final class DeadlineParser {
  static final _keyword = RegExp(
    r'\b(deadline|closing date|closing time|submission date|submitted (?:on or )?before|'
    r'not later than|no later than|on or before|last date|due date|'
    r'plazo|fecha l[ií]mite|date limite|termin\b|frist\b|lhůta|'
    r'termiņš|termin składania)',
    caseSensitive: false,
  );

  /// Words that mark a deadline for something other than the bid itself.
  /// Expressions of interest and requests to participate are what a firm
  /// submits, so their deadlines count.
  static final _secondary = RegExp(
    r'clarification|question|quer(?:y|ies)|enquir|inquir|pre-?bid|'
    r'pre-?proposal|site visit|meeting|registration|purchase of',
    caseSensitive: false,
  );

  /// How far before a keyword, within the same sentence, a secondary word
  /// still counts, as in "Questions deadline: 1 November 2026".
  static const _secondaryBefore = 40;

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

  // Right after the date: "14:30", "2.00 p.m.", "3 PM", "11h00",
  // "1400 hours", "12 noon".
  static final _time = RegExp(
    r'^\D{0,20}?(?:(\d{2})(\d{2})\s*(?:hrs|hours)\b'
    r'|(\d{1,2})(?:[:.h](\d{2}))?\s*(?:([ap])\.?\s?m\b\.?|(noon))?)',
    caseSensitive: false,
  );

  /// How far after a keyword a date may appear.
  static const window = 120;

  static DateTime? fromText(String text) {
    for (final k in _keyword.allMatches(text)) {
      final end = (k.end + window).clamp(0, text.length);
      final slice = text.substring(k.end, end);
      final m = _date.firstMatch(slice);
      if (m == null) continue;
      // "deadline for clarification requests: 1 November 2026" is not the
      // bid deadline.
      final from = (k.start - _secondaryBefore).clamp(0, k.start);
      final before = text
          .substring(from, k.start)
          .split(RegExp(r'[.;:\n]'))
          .last;
      final between = slice.substring(0, m.start);
      if (_secondary.hasMatch(before) || _secondary.hasMatch(between)) {
        continue;
      }
      final date = _toDate(m);
      if (date == null) continue;
      final (hour, minute) = _timeOf(slice.substring(m.end)) ?? (23, 59);
      return DateTime.utc(date.year, date.month, date.day, hour, minute);
    }
    return null;
  }

  /// The time right after a date, as a 24-hour (hour, minute), or null.
  static (int, int)? _timeOf(String after) {
    final t = _time.firstMatch(after);
    if (t == null) return null;
    if (t[1] != null) return _valid(int.parse(t[1]!), int.parse(t[2]!));
    if (t[3] == null) return null;
    final minutes = t[4];
    final half = t[5]?.toLowerCase();
    if (t[6] != null) return t[3] == '12' ? (12, 0) : null;
    // A bare number ("2026, 10 copies") is not a time.
    if (minutes == null && half == null) return null;
    var hour = int.parse(t[3]!);
    final minute = minutes == null ? 0 : int.parse(minutes);
    if (half != null) {
      if (hour < 1 || hour > 12) return null;
      if (half == 'p' && hour != 12) hour += 12;
      if (half == 'a' && hour == 12) hour = 0;
    }
    return _valid(hour, minute);
  }

  static (int, int)? _valid(int hour, int minute) =>
      hour > 23 || minute > 59 ? null : (hour, minute);

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
