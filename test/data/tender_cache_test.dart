import 'package:bidradar/data/local/app_database.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Tender t(
  String id, {
  String hash = '',
  DateTime? deadline,
  TenderSourceType source = TenderSourceType.ted,
  String title = 'T',
}) => Tender(
  source: source,
  sourceId: id,
  title: title,
  buyer: 'B',
  country: 'LKA',
  cpvCodes: const ['72000000'],
  deadline: deadline,
  noticeText: 'text $id',
  textHash: hash.isEmpty ? 'hash-$id' : hash,
  fetchedAt: DateTime.utc(2026, 11, 2),
);

void main() {
  late AppDatabase db;
  late TenderCache cache;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cache = TenderCache(db);
  });
  tearDown(() => db.close());

  test('stores new tenders and reads them back intact', () async {
    final a = t('1', deadline: DateTime.utc(2026, 12, 1));
    final r = await cache.upsertAll([a]);
    expect(r.added.map((e) => e.id), ['ted_1']);
    expect((await cache.byId('ted_1'))!.toJson(), a.toJson());
  });

  test('same source+sourceId again is an update, not new', () async {
    await cache.upsertAll([t('1')]);
    final r = await cache.upsertAll([t('1', title: 'Renamed')]);
    expect(r.added, isEmpty);
    expect(r.updated, hasLength(1));
    expect((await cache.byId('ted_1'))!.title, 'Renamed');
  });

  test('same text under another ID is a duplicate and not stored', () async {
    await cache.upsertAll([t('1', hash: 'same')]);
    final r = await cache.upsertAll([
      t('X9', hash: 'same', source: TenderSourceType.worldBank),
    ]);
    expect(r.duplicates.map((e) => e.id), ['worldbank_X9']);
    expect(await cache.all(), hasLength(1));
  });

  test('duplicates inside one batch are caught too', () async {
    final r = await cache.upsertAll([t('1', hash: 'h'), t('2', hash: 'h')]);
    expect(r.added, hasLength(1));
    expect(r.duplicates, hasLength(1));
  });

  test('lists by soonest deadline, unknown deadlines last', () async {
    await cache.upsertAll([
      t('late', deadline: DateTime.utc(2026, 12, 20)),
      t('none'),
      t('soon', deadline: DateTime.utc(2026, 11, 10)),
    ]);
    expect((await cache.all()).map((e) => e.sourceId), [
      'soon',
      'late',
      'none',
    ]);
  });

  test('prunes tenders that closed before the cutoff', () async {
    await cache.upsertAll([
      t('old', deadline: DateTime.utc(2026, 9, 1)),
      t('open', deadline: DateTime.utc(2026, 12, 1)),
      t('unknown'),
    ]);
    expect(await cache.pruneClosedBefore(DateTime.utc(2026, 10, 1)), 1);
    expect((await cache.all()).map((e) => e.sourceId), ['open', 'unknown']);
  });

  test('watchById emits updates and null after pruning', () async {
    final titles = cache.watchById('ted_w').map((t) => t?.title);
    final expectation = expectLater(titles, emitsInOrder([null, 'T', null]));
    await pumpEventQueue();
    await cache.upsertAll([t('w', deadline: DateTime.utc(2026, 9, 1))]);
    await pumpEventQueue();
    await cache.pruneClosedBefore(DateTime.utc(2026, 10, 1));
    await expectation;
  });
}
