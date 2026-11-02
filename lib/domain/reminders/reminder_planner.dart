import 'package:intl/intl.dart';

import '../../data/models/models.dart';

/// One local notification to schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Stable per bid and offset, so re-planning replaces instead of
  /// duplicating.
  final int id;

  /// Local wall-clock time.
  final DateTime at;
  final String title;
  final String body;

  @override
  String toString() => '#$id ${at.toIso8601String()} $title';
}

/// Plans deadline reminders (7, 3 and 1 days before, at 09:00 local) for
/// active bids, plus a Monday 09:00 weekly digest. Pure: tested without a
/// device.
abstract final class ReminderPlanner {
  static const offsetsDays = [7, 3, 1];
  static const hour = 9;

  /// Reminder notification ids live in [base, base + 100000); the digest
  /// uses [digestId].
  static const base = 200000;
  static const digestId = 199999;

  /// Stages that still need the deadline.
  static bool isActive(Bid b) =>
      b.stage == BidStage.watching || b.stage == BidStage.preparing;

  static List<PlannedReminder> plan(List<Bid> bids, DateTime nowLocal) {
    final out = <PlannedReminder>[];
    for (final b in bids.where(isActive)) {
      final d = b.deadline?.toLocal();
      if (d == null || !d.isAfter(nowLocal)) continue;
      for (final days in offsetsDays) {
        final day = DateTime(d.year, d.month, d.day - days, hour);
        // A reminder after the deadline itself is useless.
        if (!day.isAfter(nowLocal) || !day.isBefore(d)) continue;
        out.add(
          PlannedReminder(
            id: idFor(b.id, days),
            at: day,
            title: days == 1
                ? 'Closes tomorrow: ${b.title}'
                : 'Closes in $days days: ${b.title}',
            body:
                '${b.buyer} · deadline '
                '${DateFormat.MMMd().add_jm().format(d)}'
                '${b.tasks.isEmpty ? '' : ' · ${b.tasks.length - b.tasksDone} tasks left'}',
          ),
        );
      }
    }
    final digest = weeklyDigest(bids, nowLocal);
    if (digest != null) out.add(digest);
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// Next Monday 09:00 (today if it is Monday before 09:00): how many
  /// active deadlines fall in the 7 days from then.
  static PlannedReminder? weeklyDigest(List<Bid> bids, DateTime nowLocal) {
    var at = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour);
    while (at.weekday != DateTime.monday || !at.isAfter(nowLocal)) {
      at = DateTime(at.year, at.month, at.day + 1, hour);
    }
    final weekEnd = DateTime(at.year, at.month, at.day + 7);
    final due = bids.where((b) {
      final d = b.deadline?.toLocal();
      return isActive(b) && d != null && !d.isBefore(at) && d.isBefore(weekEnd);
    }).toList();
    if (due.isEmpty) return null;
    return PlannedReminder(
      id: digestId,
      at: at,
      title: due.length == 1
          ? '1 deadline this week'
          : '${due.length} deadlines this week',
      body: due.map((b) => b.title).take(3).join(' · '),
    );
  }

  static int idFor(String bidId, int days) =>
      base + (bidId.hashCode.abs() % 30000) * 3 + offsetsDays.indexOf(days);
}
