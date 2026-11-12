import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'domain/sync/background_sync.dart';
import 'ui/settings/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final firebaseReady = await initFirebase();
  // Background sync needs Firebase; without it there is nothing to sync.
  if (firebaseReady) await BackgroundSync.schedule();
  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const BidRadarApp(),
    ),
  );
}
