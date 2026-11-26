import 'package:shared_preferences/shared_preferences.dart';

/// Device preference keys, shared by the settings screen and the background
/// isolate (which has no Riverpod container).
abstract final class SettingsKeys {
  static const themeMode = 'settings.themeMode';
  static const introSeen = 'settings.introSeen';
  static const deadlineReminders = 'settings.deadlineReminders';
  static const newTenderAlerts = 'settings.newTenderAlerts';
}

/// Whether to show the "N new tenders match" notification after a background
/// sync. On unless the user turned it off in Profile.
Future<bool> newTenderAlertsEnabled() async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(SettingsKeys.newTenderAlerts) ?? true;
}
