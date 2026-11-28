import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/repositories/sync_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

Verdict verdict(String id, VerdictStatus status) => Verdict(
  id: id,
  tenderId: 'ted_1',
  companyId: 'c1',
  verdict: VerdictKind.noBid,
  fitScore: 0,
  criteria: const [],
  missingDocs: const [],
  rulesResult: const RulesResult.pass(),
  status: status,
  model: 'rules',
  at: DateTime.utc(2026, 11, 2),
);

void main() {
  test('rules vetoes are written one by one, AI verdicts in a batch', () {
    final (:batched, :once) = FirestoreSyncStore.splitAppendOnly([
      verdict('rules_c1_ted_1', VerdictStatus.rulesVeto),
      verdict('ai_c1_ted_2_1', VerdictStatus.accepted),
      verdict('ai_c1_ted_3_1', VerdictStatus.aiUnavailable),
    ]);
    expect(once.map((v) => v.id), ['rules_c1_ted_1']);
    expect(batched.map((v) => v.id), ['ai_c1_ted_2_1', 'ai_c1_ted_3_1']);
  });

  test('a veto recorded before (another phone, a reinstall) is fine', () async {
    // The append-only rules refuse to overwrite it.
    await FirestoreSyncStore.recordOnce(
      'rules_c1_ted_1',
      () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );
  });

  test('other write errors still surface', () async {
    await expectLater(
      FirestoreSyncStore.recordOnce(
        'rules_c1_ted_1',
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
}
