import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/sync_store.dart';
import '../../data/sources/ted_client.dart';
import '../../data/sources/worldbank_client.dart';
import 'feed_sync.dart';

/// Runs FeedSync every 6 hours with WorkManager, even when the app is
/// closed. Android may delay jobs (Doze, battery saver) and never runs them
/// more often than every 15 minutes; "Sync now" covers demos.
abstract final class BackgroundSync {
  static const uniqueName = 'feed-sync';
  static const taskName = 'feedSync';
  static const frequency = Duration(hours: 6);

  static Future<void> schedule() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: frequency,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } on Object catch (e) {
      Log.warn('bgsync', 'could not schedule background sync: $e');
    }
  }

  /// Debug builds only: queue the same task once, now. WorkManager will not
  /// run periodic work early, even when JobScheduler forces it.
  static Future<void> runSoonForTesting() => Workmanager().registerOneOffTask(
    '$uniqueName-now',
    taskName,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );

  /// One background run. Returns true when finished (including "nothing to
  /// do"), false to let WorkManager retry later.
  static Future<bool> runOnce() async {
    if (!await initFirebase()) return true;
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return true;

    final firestore = FirebaseFirestore.instance;
    final companies = FirestoreCompanyRepository(firestore);
    final companyId = await companies.watchCompanyIdForUser(user.uid).first;
    if (companyId == null) return true;
    final company = await companies.watchCompany(companyId).first;
    final profile = await FirestoreProfileRepository(firestore)
        .watch(companyId)
        .first;
    if (company == null || profile == null) return true;

    final http = ResilientHttp();
    final db = AppDatabase();
    try {
      final report = await FeedSync(
        sources: [TedClient(http), WorldBankClient(http)],
        cache: TenderCache(db),
        log: SyncLog(db),
        store: FirestoreSyncStore(firestore),
      ).run(company: company, profile: profile, background: true);
      Log.info(
        'bgsync',
        'added ${report.added}, matched ${report.matched}, '
            'errors ${report.errors}',
      );
      await NotificationService().showNewTenders(report.matched);
      return true;
    } finally {
      http.close();
      await db.close();
    }
  }
}

/// WorkManager entry point. Must be top level and kept by the compiler.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      return await BackgroundSync.runOnce();
    } on Object catch (e, st) {
      Log.error('bgsync', 'background sync failed', e, st);
      return false;
    }
  });
}
