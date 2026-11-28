import 'dart:async';

import 'package:bidradar/core/notifications/notification_service.dart';
import 'package:bidradar/domain/reminders/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each plan applied, and holds the first one until released, like
/// a slow round of plugin calls.
class SlowNotifications extends NotificationService {
  final applied = <String>[];
  final release = Completer<void>();
  int running = 0;
  int mostAtOnce = 0;

  @override
  Future<int> replaceReminders(List<PlannedReminder> planned) async {
    running++;
    if (running > mostAtOnce) mostAtOnce = running;
    if (applied.isEmpty) await release.future;
    applied.add(planned.map((p) => p.title).join(','));
    running--;
    return planned.length;
  }
}

PlannedReminder reminder(String title) =>
    PlannedReminder(id: 1, at: DateTime(2027), title: title, body: '');

void main() {
  test('plans run one at a time and the latest wins', () async {
    final n = SlowNotifications();
    final first = n.scheduleReminders([reminder('old')]);
    // 2 more changes arrive while the first is still being applied.
    final second = n.scheduleReminders([reminder('stale')]);
    final third = n.scheduleReminders([reminder('new'), reminder('new2')]);
    n.release.complete();

    expect(await first, 2);
    expect(await second, 2);
    expect(await third, 2);
    expect(n.applied, ['old', 'new,new2']);
    expect(n.mostAtOnce, 1);
  });

  test('a later call after the queue empties runs again', () async {
    final n = SlowNotifications()..release.complete();
    await n.scheduleReminders([reminder('a')]);
    await n.scheduleReminders([]);
    expect(n.applied, ['a', '']);
  });
}
