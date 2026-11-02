import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../logging/log.dart';

/// Local notifications. Used by the background sync (any isolate) and,
/// in Phase 3, by deadline reminders.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const newTendersId = 1001;
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

  /// Asks for the Android 13+ notification permission. Safe to call more
  /// than once; Android only shows the dialog until the user answers.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
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
}
