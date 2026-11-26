import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminders/reminder_planner.dart';
import '../logging/log.dart';

/// Local notifications. Used by the background sync (any isolate) and,
/// in Phase 3, by deadline reminders.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const newTendersId = 1001;
  static bool _tzReady = false;
  static const _deadlineChannel = AndroidNotificationDetails(
    'deadlines',
    'Deadline reminders',
    channelDescription: 'Reminders 7, 3 and 1 days before bid deadlines.',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _channel = AndroidNotificationDetails(
    'new_tenders',
    'New tenders',
    channelDescription: 'Tenders that match your company after a sync.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for the Android 13+ notification permission. Older Android
  /// versions answer without a dialog. Safe to call more than once; Android
  /// only shows the dialog while it still may. Null when Android cannot be
  /// asked (another platform, or no plugin in tests).
  Future<bool?> requestPermission() async {
    try {
      await init();
      return await _android?.requestNotificationsPermission();
    } on Object catch (e) {
      Log.warn('notify', 'could not ask for permission: $e');
      return null;
    }
  }

  /// Whether Android lets BidRadar post notifications right now. Null when
  /// it cannot tell.
  Future<bool?> areEnabled() async {
    try {
      await init();
      return await _android?.areNotificationsEnabled();
    } on Object catch (e) {
      Log.warn('notify', 'could not read the permission: $e');
      return null;
    }
  }

  /// Opens BidRadar's notification settings in Android. False when no
  /// settings screen could be opened.
  Future<bool> openSettings() async {
    try {
      return await _android?.openAppNotificationSettings() ?? false;
    } on Object catch (e) {
      Log.warn('notify', 'could not open settings: $e');
      return false;
    }
  }

  /// "3 new tenders match". Tapping it opens the app on the Feed.
  Future<void> showNewTenders(int count) async {
    if (count <= 0) return;
    try {
      await init();
      await _plugin.show(
        id: newTendersId,
        title: count == 1 ? '1 new tender matches' : '$count new tenders match',
        body: 'Open BidRadar to review them.',
        notificationDetails: const NotificationDetails(android: _channel),
      );
    } on Object catch (e) {
      Log.warn('notify', 'could not show notification: $e');
    }
  }

  /// The newest plan not yet applied, and the run applying plans.
  List<PlannedReminder>? _nextPlan;
  Future<int>? _applying;

  /// Replaces every scheduled reminder with [planned]. Calls run one at a
  /// time and the latest plan wins: a plan that is replaced before its turn
  /// is skipped, so 2 quick changes can never leave stale reminders behind.
  /// Completes when the latest plan is in place, with its size.
  Future<int> scheduleReminders(List<PlannedReminder> planned) {
    _nextPlan = planned;
    return _applying ??= _applyLatest();
  }

  Future<int> _applyLatest() async {
    var count = 0;
    try {
      while (_nextPlan != null) {
        final plan = _nextPlan!;
        _nextPlan = null;
        count = await replaceReminders(plan);
      }
    } finally {
      _applying = null;
    }
    return count;
  }

  /// Cancels the scheduled reminders and schedules [planned] instead. Times
  /// are scheduled as absolute UTC instants, so the device time zone
  /// database is not needed. Inexact scheduling avoids the exact-alarm
  /// permission; Android may shift a reminder by some minutes.
  @protected
  @visibleForTesting
  Future<int> replaceReminders(List<PlannedReminder> planned) async {
    try {
      await init();
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= ReminderPlanner.digestId) await _plugin.cancel(id: p.id);
      }
      for (final r in planned) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: const NotificationDetails(
            android: _deadlineChannel,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      return planned.length;
    } on Object catch (e) {
      Log.warn('notify', 'could not schedule reminders: $e');
      return 0;
    }
  }
}
