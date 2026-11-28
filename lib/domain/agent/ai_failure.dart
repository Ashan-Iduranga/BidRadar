import 'dart:async';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

/// Why an AI call gave no usable answer. The sync uses it to decide whether
/// asking about the next tender is worth it.
enum AiFailure {
  /// The message says the daily request quota is used up.
  dailyQuota,

  /// A request limit was hit: per minute, or the message does not say which.
  rateLimit,

  /// No network connection.
  offline,

  /// The request was refused: App Check, the API key or the API setup.
  auth,

  /// The model did not answer within the timeout.
  timeout,

  /// The service failed (a 5xx or an error we do not recognise).
  service,

  /// Only this notice failed: a malformed answer, a missing field, or an
  /// answer blocked by the safety or recitation filter. Other notices can
  /// still be judged.
  notice;

  /// True when the failure will not clear within one sync, so asking about
  /// the next tender would only fail again.
  bool get stopsSync => this != notice;

  /// Classifies an error thrown by an AI call.
  static AiFailure of(Object e) {
    if (e is TimeoutException) return timeout;
    // Malformed JSON or an unknown enum value (FormatException), or a
    // missing field (TypeError from a cast in fromJson).
    if (e is FormatException || e is TypeError) return notice;
    if (isBlockedAnswer(e)) return notice;
    if (e is SocketException || e is http.ClientException) return offline;
    final lower = '$e'.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed')) {
      return offline;
    }
    if (e is QuotaExceeded ||
        lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('too many requests')) {
      return _isDaily(lower) ? dailyQuota : rateLimit;
    }
    // The App Check token could not be fetched on the device.
    if (e is FirebaseException && e.plugin == 'firebase_app_check') {
      return auth;
    }
    if (e is InvalidApiKey ||
        e is ServiceApiNotEnabled ||
        e is UnsupportedUserLocation ||
        lower.contains('app check') ||
        lower.contains('appcheck') ||
        lower.contains('permission_denied') ||
        lower.contains('permission-denied') ||
        lower.contains('unauthenticated') ||
        lower.contains('api key')) {
      return auth;
    }
    return service;
  }

  /// A response blocked by the safety or recitation filter. firebase_ai
  /// throws these from `GenerateContentResponse.text`.
  static bool isBlockedAnswer(Object e) {
    final lower = '$e'.toLowerCase();
    return lower.contains('response was blocked') ||
        lower.contains('candidate was blocked');
  }

  /// Only an explicit "per day" or "daily" counts as the daily quota. The
  /// free tier also limits requests per minute, and a message that does not
  /// say which limit was hit is reported as a request limit.
  static bool _isDaily(String lower) {
    if (lower.contains('per minute') || lower.contains('perminute')) {
      return false;
    }
    return lower.contains('per day') ||
        lower.contains('perday') ||
        lower.contains('daily');
  }

  /// Short reason for the verdict note.
  static String reason(AiFailure f, Object? e) => switch (f) {
    dailyQuota => 'daily AI quota used up',
    rateLimit => 'AI request limit reached, try again in a minute',
    offline => 'no connection',
    auth => 'AI access refused, check App Check and the API setup',
    timeout => 'timed out',
    service => 'service error',
    notice =>
      e != null && isBlockedAnswer(e)
          ? 'the answer was blocked by the AI safety filter'
          : 'invalid answer',
  };
}
