import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Minimal tagged logger. Every network and AI call logs what was asked,
/// what came back and what was skipped (architecture doc §17). In debug
/// builds lines also go to `adb logcat` (tag `flutter`).
abstract final class Log {
  static void info(String tag, String message) => _out(tag, message, 800);

  static void warn(String tag, String message) =>
      _out(tag, 'WARN $message', 900);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _out(tag, '$message${error == null ? '' : ': $error'}', 1000, stack);

  static void _out(String tag, String message, int level, [StackTrace? st]) {
    developer.log(message, name: 'BidRadar.$tag', level: level, stackTrace: st);
    if (kDebugMode) debugPrint('[BidRadar.$tag] $message');
  }
}
