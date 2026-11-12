import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/settings_keys.dart';

export '../../core/settings/settings_keys.dart';

/// Device preferences: theme, whether the intro was seen, and which
/// notifications to show. Stored on the device with shared_preferences; they
/// are personal, so they never go to Firestore.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.introSeen = false,
    this.deadlineReminders = true,
    this.newTenderAlerts = true,
  });

  final ThemeMode themeMode;
  final bool introSeen;
  final bool deadlineReminders;
  final bool newTenderAlerts;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? introSeen,
    bool? deadlineReminders,
    bool? newTenderAlerts,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    introSeen: introSeen ?? this.introSeen,
    deadlineReminders: deadlineReminders ?? this.deadlineReminders,
    newTenderAlerts: newTenderAlerts ?? this.newTenderAlerts,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.introSeen == introSeen &&
      other.deadlineReminders == deadlineReminders &&
      other.newTenderAlerts == newTenderAlerts;

  @override
  int get hashCode =>
      Object.hash(themeMode, introSeen, deadlineReminders, newTenderAlerts);
}

/// Loaded once in `main` and overridden there. Null (the default) keeps
/// settings in memory only, which is what widget tests use.
final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => null);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences? get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    if (p == null) return const AppSettings();
    return AppSettings(
      themeMode: _modeFrom(p.getString(SettingsKeys.themeMode)),
      introSeen: p.getBool(SettingsKeys.introSeen) ?? false,
      deadlineReminders: p.getBool(SettingsKeys.deadlineReminders) ?? true,
      newTenderAlerts: p.getBool(SettingsKeys.newTenderAlerts) ?? true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs?.setString(SettingsKeys.themeMode, mode.name);
  }

  Future<void> markIntroSeen() async {
    state = state.copyWith(introSeen: true);
    await _prefs?.setBool(SettingsKeys.introSeen, true);
  }

  Future<void> setDeadlineReminders(bool on) async {
    state = state.copyWith(deadlineReminders: on);
    await _prefs?.setBool(SettingsKeys.deadlineReminders, on);
  }

  Future<void> setNewTenderAlerts(bool on) async {
    state = state.copyWith(newTenderAlerts: on);
    await _prefs?.setBool(SettingsKeys.newTenderAlerts, on);
  }

  static ThemeMode _modeFrom(String? name) => ThemeMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => ThemeMode.system,
  );
}
