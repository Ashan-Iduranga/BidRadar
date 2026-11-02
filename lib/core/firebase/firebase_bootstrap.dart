import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../logging/log.dart';

/// Initialises Firebase and App Check. Returns false (instead of crashing)
/// when Firebase has not been configured yet, so the UI shell still runs.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError catch (e) {
    Log.warn('firebase', e.message ?? 'Firebase not configured');
    return false;
  } catch (e, st) {
    Log.error('firebase', 'Firebase init failed', e, st);
    return false;
  }

  try {
    // App Check proves requests come from the real app, so no Gemini API key
    // ships inside the APK. Debug builds use the debug provider; register the
    // debug token printed in logcat in the Firebase console.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
    );
  } catch (e, st) {
    Log.error('firebase', 'App Check activation failed', e, st);
  }
  return true;
}

/// Whether Firebase initialised. Overridden in `main.dart`.
final firebaseReadyProvider = Provider<bool>((ref) => false);
