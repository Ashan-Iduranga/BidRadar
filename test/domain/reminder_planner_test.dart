import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/reminders/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// Sunday 1 Nov 2026, 10:00 local.
final now = DateTime(2026, 11, 1, 10);

Bid bid(String id, {DateTime? deadline, BidStage stage = BidStage.watching}) =>
    Bid(
      id: id,
      tenderId: 't$id',
      companyId: 'c1',
      stage: stage,
      ownerUid: 'u',
      title: 'Tender $id',
      buyer: 'Buyer',
      deadline: deadline,
      updatedAt: now,
    );

void main() {
  test('7, 3 and 1 days before, at 09:00', () {
    final plan = ReminderPlanner.plan([
      bid('a', deadline: DateTime(2026, 11, 20, 14)),
    ], now);
    final reminders = plan.where((p) => p.id != ReminderPlanner.digestId);
    expect(reminders.map((p) => p.at), [
      DateTime(2026, 11, 13, 9),
      DateTime(2026, 11, 17, 9),
      DateTime(2026, 11, 19, 9),
    ]);
    expect(reminders.last.title, 'Closes tomorrow: Tender a');
    expect(reminders.first.title, 'Closes in 7 days: Tender a');
  });

  test('past reminder times are skipped', () {
    // Deadline in 2 days: only the 1-day reminder is still ahead.
    final plan = ReminderPlanner.plan([
      bid('a', deadline: DateTime(2026, 11, 3, 12)),
    ], now);
    expect(
      plan.where((p) => p.id != ReminderPlanner.digestId).map((p) => p.at),
      [DateTime(2026, 11, 2, 9)],
    );
  });

  test('no reminders for closed, submitted, won or lost bids', () {
    final plan = ReminderPlanner.plan([
      bid('old', deadline: DateTime(2026, 10, 1)),
      bid('sub', deadline: DateTime(2026, 11, 20), stage: BidStage.submitted),
      bid('won', deadline: DateTime(2026, 11, 20), stage: BidStage.won),
      bid('none'),
    ], now);
    expect(plan, isEmpty);
  });

  test('ids are stable and distinct per bid and offset', () {
    final a = ReminderPlanner.idFor('bid-1', 7);
    expect(ReminderPlanner.idFor('bid-1', 7), a);
    expect(
      {
        for (final d in ReminderPlanner.offsetsDays)
          ReminderPlanner.idFor('bid-1', d),
      }.length,
      3,
    );
    expect(a, greaterThan(ReminderPlanner.digestId));
  });

  test('Monday digest counts deadlines in the coming week', () {
    final digest = ReminderPlanner.weeklyDigest([
      bid('a', deadline: DateTime(2026, 11, 4, 12)),
      bid('b', deadline: DateTime(2026, 11, 6, 12)),
      bid('later', deadline: DateTime(2026, 11, 20)),
    ], now);
    expect(digest!.at, DateTime(2026, 11, 2, 9)); // next Monday
    expect(digest.title, '2 deadlines this week');
    expect(digest.body, 'Tender a · Tender b');
  });

  test('no digest when nothing is due that week', () {
    expect(
      ReminderPlanner.weeklyDigest([
        bid('later', deadline: DateTime(2026, 12, 20)),
      ], now),
      isNull,
    );
  });

  test('on a Monday after 09:00 the digest is for next Monday', () {
    final monday = DateTime(2026, 11, 2, 10);
    final d = ReminderPlanner.weeklyDigest([
      bid('a', deadline: DateTime(2026, 11, 10, 12)),
    ], monday);
    expect(d!.at, DateTime(2026, 11, 9, 9));
  });
}
