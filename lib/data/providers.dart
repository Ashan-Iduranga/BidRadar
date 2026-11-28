import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/resilient_http.dart';
import '../core/notifications/notification_service.dart';
import '../domain/agent/ai_model.dart';
import '../domain/agent/bid_agent.dart';
import '../domain/agent/gemini_model.dart';
import '../domain/sync/feed_sync.dart';
import 'local/app_database.dart';
import 'repositories/bid_repository.dart';
import 'repositories/company_repository.dart';
import 'repositories/sync_store.dart';
import 'sources/ted_client.dart';
import 'sources/tender_source.dart';
import 'sources/worldbank_client.dart';

/// Dependency wiring. Tests override these with fakes.

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final companyRepositoryProvider = Provider<CompanyRepository>(
  (ref) => FirestoreCompanyRepository(ref.watch(firestoreProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(ref.watch(firestoreProvider)),
);

final httpProvider = Provider<ResilientHttp>((ref) {
  final http = ResilientHttp();
  ref.onDispose(http.close);
  return http;
});

final tenderSourcesProvider = Provider<List<TenderSource>>((ref) {
  final http = ref.watch(httpProvider);
  return [TedClient(http), WorldBankClient(http)];
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final tenderCacheProvider = Provider<TenderCache>(
  (ref) => TenderCache(ref.watch(appDatabaseProvider)),
);

final syncLogProvider = Provider<SyncLog>(
  (ref) => SyncLog(ref.watch(appDatabaseProvider)),
);

final syncStoreProvider = Provider<SyncStore>(
  (ref) => FirestoreSyncStore(ref.watch(firestoreProvider)),
);

final verdictCacheProvider = Provider<VerdictCache>(
  (ref) => VerdictCache(ref.watch(appDatabaseProvider)),
);

/// The swappable model (architecture doc §20). Tests override this.
final aiModelProvider = Provider<AiModel>((ref) => GeminiModel());

final bidAgentProvider = Provider<BidAgent>(
  (ref) => BidAgent(model: ref.watch(aiModelProvider)),
);

final feedSyncProvider = Provider<FeedSync>(
  (ref) => FeedSync(
    sources: ref.watch(tenderSourcesProvider),
    cache: ref.watch(tenderCacheProvider),
    log: ref.watch(syncLogProvider),
    store: ref.watch(syncStoreProvider),
    agent: ref.watch(bidAgentProvider),
    verdicts: ref.watch(verdictCacheProvider),
  ),
);

final notifierProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final bidRepositoryProvider = Provider<BidRepository>(
  (ref) => FirestoreBidRepository(ref.watch(firestoreProvider)),
);

final sharedRecordsProvider = Provider<SharedRecords>(
  (ref) => FirestoreSharedRecords(ref.watch(firestoreProvider)),
);
