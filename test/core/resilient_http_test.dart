import 'dart:async';

import 'package:bidradar/core/net/resilient_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final uri = Uri.parse('https://api.example.test/notices');
  Future<void> noSleep(Duration _) async {}

  test('retries a 503 and then succeeds', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return calls < 3 ? http.Response('busy', 503) : http.Response('ok', 200);
    });
    final net = ResilientHttp(client: client, sleep: noSleep);
    final res = await net.get(uri);
    expect(res.body, 'ok');
    expect(calls, 3);
  });

  test('gives up after maxRetries + 1 attempts', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('down', 500);
    });
    final net = ResilientHttp(client: client, sleep: noSleep, maxRetries: 2);
    await expectLater(net.get(uri), throwsA(isA<NetworkException>()));
    expect(calls, 3);
  });

  test('does not retry a 404', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('missing', 404);
    });
    final net = ResilientHttp(client: client, sleep: noSleep);
    await expectLater(
      net.get(uri),
      throwsA(
        isA<NetworkException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
    expect(calls, 1);
  });

  test('times out a hanging request and retries', () async {
    var calls = 0;
    final client = MockClient((_) {
      calls++;
      return calls == 1
          ? Completer<http.Response>()
                .future // never completes
          : Future.value(http.Response('ok', 200));
    });
    final net = ResilientHttp(
      client: client,
      sleep: noSleep,
      timeout: const Duration(milliseconds: 50),
    );
    expect((await net.get(uri)).body, 'ok');
    expect(calls, 2);
  });
}
