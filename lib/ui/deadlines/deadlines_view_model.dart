import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/reminders/reminder_planner.dart';
import '../pipeline/pipeline_view_model.dart';
import '../settings/notification_access.dart';
import '../settings/settings_providers.dart';

/// Active bids with a deadline, soonest first.
final deadlineBidsProvider = Provider<List<Bid>>((ref) {
  final bids = ref.watch(bidsProvider).value ?? const [];
  return bids
      .where((b) => ReminderPlanner.isActive(b) && b.deadline != null)
      .toList()
    ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
});

/// Keeps local reminders in step with the pipeline: whenever bids change,
/// re-plan and reschedule (only if the plan actually changed). When the user
/// turns reminders off in Profile, or Android blocks notifications, the plan
/// is empty, which cancels them all.
final reminderSyncProvider = Provider<void>((ref) {
  final wanted = ref.watch(settingsProvider.select((s) => s.deadlineReminders));
  // Reading this asks for the permission on first launch. Nothing is
  // scheduled until Android has answered.
  final access = ref.watch(notificationAccessProvider).value;
  if (access == null) return;
  final enabled = wanted && access == NotificationAccess.allowed;
  String? last;
  ref.listen<AsyncValue<List<Bid>>>(bidsProvider, (_, next) {
    final bids = next.value;
    if (bids == null) return;
    final plan = enabled
        ? ReminderPlanner.plan(bids, DateTime.now())
        : const <PlannedReminder>[];
    final signature = plan.map((p) => '${p.id}@${p.at}:${p.title}').join('|');
    if (signature == last) return;
    last = signature;
    ref.read(notifierProvider).scheduleReminders(plan);
  }, fireImmediately: true);
});

/// The month the calendar shows, and the day picked in it (null = all).
class CalendarState {
  const CalendarState({required this.month, this.day});
  final DateTime month;
  final DateTime? day;
}

class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final now = DateTime.now();
    return CalendarState(month: DateTime(now.year, now.month));
  }

  void shiftMonth(int by) => state = CalendarState(
    month: DateTime(state.month.year, state.month.month + by),
  );

  void pick(DateTime day) => state = CalendarState(
    month: state.month,
    day: DateUtils.isSameDay(state.day, day) ? null : day,
  );
}

final calendarProvider = NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);
