import 'package:bidradar/domain/agent/gemini_factory.dart';
import 'package:bidradar/domain/agent/gemini_model.dart';
import 'package:bidradar/domain/insights/profile_advisor.dart';
import 'package:bidradar/domain/scan/scan_services.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Check fallback', () {
    test('a missing App Check token retries once without it', () async {
      var fallbacks = 0;
      final r = await GeminiClient.withAppCheckFallback(
        () async => throw FirebaseException(
          plugin: 'firebase_app_check',
          code: 'unknown',
          message: 'App attestation failed',
        ),
        () async {
          fallbacks++;
          return 'answer';
        },
      );
      expect(r, 'answer');
      expect(fallbacks, 1);
    });

    test('other errors are passed on, without a second request', () async {
      var fallbacks = 0;
      Future<String> fallback() async {
        fallbacks++;
        return 'answer';
      }

      await expectLater(
        GeminiClient.withAppCheckFallback(
          () async => throw FirebaseAIException('App Check token is invalid'),
          fallback,
        ),
        throwsA(isA<FirebaseAIException>()),
      );
      await expectLater(
        GeminiClient.withAppCheckFallback(
          () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
          fallback,
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(fallbacks, 0);
    });

    test('a working token never uses the fallback', () async {
      final r = await GeminiClient.withAppCheckFallback(
        () async => 'answer',
        () async => fail('fallback used'),
      );
      expect(r, 'answer');
    });
  });

  test('building the 3 Gemini users needs no Firebase until a call', () {
    // Firebase is not initialised in unit tests.
    expect(GeminiModel.new, returnsNormally);
    expect(GeminiProfileAdvisor.new, returnsNormally);
    expect(GeminiNoticeReader.new, returnsNormally);
  });
}
