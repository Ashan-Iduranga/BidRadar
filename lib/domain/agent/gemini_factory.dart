import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/logging/log.dart';

/// The one place that builds Gemini models: the bid agent, Scan and
/// Insights all get theirs from here.
///
/// App Check: firebase_ai 5.1 attaches the App Check token by itself.
/// `FirebaseAI.googleAI()` takes the `FirebaseAppCheck` registered on the
/// Firebase app, and `initFirebase()` registers and activates it before any
/// model is used, in the UI and in the background isolate. If fetching the
/// token throws (an unregistered debug token, or Play Integrity refusing a
/// sideloaded build), firebase_ai fails the request before sending it.
/// [GeminiClient] then repeats that request once through a second Firebase
/// app that has no App Check registered. When App Check is enforced for AI
/// Logic the server refuses it, as it would anyway; when it is not enforced,
/// the AI keeps working.
abstract final class GeminiFactory {
  /// Name of the Firebase app used when the App Check token is unavailable.
  static const noAppCheckAppName = 'bidradar-ai-no-app-check';

  static Future<FirebaseApp>? _noAppCheckApp;

  static GeminiClient create({
    required String model,
    Content? systemInstruction,
    GenerationConfig? generationConfig,
  }) {
    GenerativeModel build(FirebaseApp app) =>
        FirebaseAI.googleAI(app: app).generativeModel(
          model: model,
          systemInstruction: systemInstruction,
          generationConfig: generationConfig,
        );
    return GeminiClient(
      primary: () => build(Firebase.app()),
      fallback: () async => build(await _appWithoutAppCheck()),
    );
  }

  static Future<FirebaseApp> _appWithoutAppCheck() {
    return _noAppCheckApp ??= () async {
      try {
        try {
          return Firebase.app(noAppCheckAppName);
        } on FirebaseException {
          return await Firebase.initializeApp(
            name: noAppCheckAppName,
            options: Firebase.app().options,
          );
        }
      } on Object {
        _noAppCheckApp = null; // let a later call try again
        rethrow;
      }
    }();
  }
}

/// A Gemini model that survives a missing App Check token (see
/// [GeminiFactory]). Models are built on first use, so creating a client
/// never needs Firebase.
class GeminiClient {
  GeminiClient({
    required GenerativeModel Function() primary,
    required Future<GenerativeModel> Function() fallback,
  }) : _buildPrimary = primary,
       _buildFallback = fallback;

  final GenerativeModel Function() _buildPrimary;
  final Future<GenerativeModel> Function() _buildFallback;
  GenerativeModel? _primary;
  Future<GenerativeModel>? _fallback;

  Future<GenerateContentResponse> generateContent(List<Content> prompt) =>
      withAppCheckFallback(
        () => (_primary ??= _buildPrimary()).generateContent(prompt),
        () async {
          final m = await (_fallback ??= _buildFallback());
          return m.generateContent(prompt);
        },
      );

  /// Runs [primary]; only if the App Check token could not be fetched on the
  /// device, runs [fallback] instead. Every other error is passed on.
  @visibleForTesting
  static Future<T> withAppCheckFallback<T>(
    Future<T> Function() primary,
    Future<T> Function() fallback,
  ) async {
    try {
      return await primary();
    } on FirebaseException catch (e) {
      if (e.plugin != 'firebase_app_check') rethrow;
      Log.warn(
        'ai',
        'App Check token unavailable (${e.code}); retrying without it',
      );
      return fallback();
    }
  }
}
