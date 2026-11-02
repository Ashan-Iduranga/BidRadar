import 'dart:developer' as developer;

/// Minimal tagged logger. Every network and AI call logs what was asked,
/// what came back and what was skipped (architecture doc §17).
abstract final class Log {
  static void info(String tag, String message) =>
      developer.log(message, name: 'BidRadar.$tag');

  static void warn(String tag, String message) =>
      developer.log('WARN $message', name: 'BidRadar.$tag', level: 900);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => developer.log(
    message,
    name: 'BidRadar.$tag',
    level: 1000,
    error: error,
    stackTrace: stack,
  );
}
