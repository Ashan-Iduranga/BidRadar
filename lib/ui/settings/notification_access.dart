import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../data/providers.dart';
import 'settings_providers.dart';

/// What Android allows for BidRadar's notifications.
enum NotificationAccess {
  /// Allowed, or Android cannot tell (another platform, or tests).
  allowed,

  /// Turned off for BidRadar in Android settings, or the request was denied.
  blocked,
}

/// Set once the app has asked for the notification permission, so it asks
/// only on the first launch that reaches the app shell.
const notificationsAskedKey = 'settings.notificationsAsked';

/// Asks for the notification permission the first time it is read (the app
/// shell reads it before any reminder is scheduled), then reports Android's
/// answer. Reminders and the Profile switches follow it.
final notificationAccessProvider =
    AsyncNotifierProvider<NotificationAccessNotifier, NotificationAccess>(
      NotificationAccessNotifier.new,
    );

class NotificationAccessNotifier extends AsyncNotifier<NotificationAccess> {
  NotificationService get _service => ref.read(notifierProvider);

  @override
  Future<NotificationAccess> build() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (prefs?.getBool(notificationsAskedKey) ?? false) {
      return _from(await _service.areEnabled());
    }
    // Saved before asking, so a second read never shows a second dialog.
    await prefs?.setBool(notificationsAskedKey, true);
    return _from(await _service.requestPermission());
  }

  static NotificationAccess _from(bool? allowed) => allowed == false
      ? NotificationAccess.blocked
      : NotificationAccess.allowed;

  /// Reads Android's answer again, for example after the user comes back
  /// from the settings screen.
  Future<void> refresh() async {
    final next = _from(await _service.areEnabled());
    if (state.value != next) state = AsyncData(next);
  }

  /// Asks again. Android shows the dialog only while it still may; after
  /// that the user has to allow notifications in settings. True if allowed.
  Future<bool> request() async {
    final next = _from(await _service.requestPermission());
    state = AsyncData(next);
    return next == NotificationAccess.allowed;
  }

  Future<bool> openSettings() => _service.openSettings();
}
