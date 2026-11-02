import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/resilient_http.dart';
import 'local/app_database.dart';
import 'repositories/company_repository.dart';
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
