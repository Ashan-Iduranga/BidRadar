import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../logging/log.dart';

/// Thrown when a request fails after every retry.
class NetworkException implements Exception {
  NetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'NetworkException($statusCode): $message';
}

/// Wraps [http.Client] with the project's network policy:
/// a per-attempt timeout, a bounded number of retries with exponential
/// backoff, and a log line per attempt. Used by the TED and World Bank clients.
class ResilientHttp {
  ResilientHttp({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 500),
    Future<void> Function(Duration)? sleep,
  }) : _client = client ?? http.Client(),
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _client;
  final Duration timeout;
  final int maxRetries;
  final Duration baseDelay;
  final Future<void> Function(Duration) _sleep;

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) =>
      _send('GET', uri, () => _client.get(uri, headers: headers));

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send('POST', uri, () => _client.post(uri, headers: headers, body: body));

  Future<http.Response> _send(
    String method,
    Uri uri,
    Future<http.Response> Function() request,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = baseDelay * pow(2, attempt - 1).toInt();
        Log.info('http', 'retry $attempt for $method $uri in ${delay.inMs}ms');
        await _sleep(delay);
      }
      try {
        final res = await request().timeout(timeout);
        Log.info(
          'http',
          '$method $uri -> ${res.statusCode} '
              '(${res.bodyBytes.length} bytes, attempt ${attempt + 1})',
        );
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
        // Client errors other than 429 will not get better with retries.
        if (res.statusCode >= 400 &&
            res.statusCode < 500 &&
            res.statusCode != 429) {
          throw NetworkException(
            'HTTP ${res.statusCode}',
            statusCode: res.statusCode,
          );
        }
        lastError = NetworkException(
          'HTTP ${res.statusCode}',
          statusCode: res.statusCode,
        );
      } on NetworkException {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
        Log.warn('http', '$method $uri timed out after ${timeout.inSeconds}s');
      } on SocketException catch (e) {
        lastError = e;
        Log.warn('http', '$method $uri socket error: ${e.message}');
      } on http.ClientException catch (e) {
        lastError = e;
        Log.warn('http', '$method $uri client error: ${e.message}');
      }
    }
    throw NetworkException(
      'Gave up on $method $uri after ${maxRetries + 1} attempts: $lastError',
    );
  }

  void close() => _client.close();
}

extension on Duration {
  int get inMs => inMilliseconds;
}
