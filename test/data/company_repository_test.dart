import 'package:bidradar/data/repositories/company_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite keys ignore case and spaces', () {
    expect(
      FirestoreCompanyRepository.inviteKey(' Bob@Firm.Test '),
      'bob@firm.test',
    );
  });

  test("a refused invite means another company's invite holds it", () {
    final e = FirestoreCompanyRepository.inviteError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      'bob@firm.test',
    );
    expect(e, isA<InviteTakenException>());
    expect(e.code, 'invited-by-another-company');
    expect(e.message, contains('bob@firm.test already has an invite'));
  });

  test('other failures pass through unchanged', () {
    final offline = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    expect(
      FirestoreCompanyRepository.inviteError(offline, 'bob@firm.test'),
      same(offline),
    );
  });
}
