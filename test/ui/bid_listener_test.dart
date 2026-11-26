import 'dart:async';

import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/providers.dart';
import 'package:bidradar/data/repositories/bid_repository.dart';
import 'package:bidradar/ui/auth/auth_providers.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'u1';
}

/// Counts open bid listeners, like Firestore snapshot listeners.
class CountingBidRepository extends Fake implements BidRepository {
  var open = 0;

  @override
  Stream<Bid?> watchBid(String bidId) {
    late final StreamController<Bid?> c;
    c = StreamController<Bid?>(onListen: () => open++, onCancel: () => open--);
    return c.stream;
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('leaving the bid page ends its listener', () async {
    final repo = CountingBidRepository();
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(FakeUser())),
        bidRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.listen(authStateProvider, (_, _) {});
    await settle();

    final page = c.listen(bidProvider('c1_ted_1'), (_, _) {});
    await settle();
    expect(repo.open, 1);

    page.close();
    await settle();
    expect(repo.open, 0);
  });

  test('signing out ends the listener even while the page is open', () async {
    final repo = CountingBidRepository();
    final auth = StreamController<User?>.broadcast();
    addTearDown(auth.close);
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        bidRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    c.listen(bidProvider('c1_ted_1'), (_, _) {});
    auth.add(FakeUser());
    await settle();
    expect(repo.open, 1);

    auth.add(null);
    await settle();
    expect(repo.open, 0);
    expect(c.read(bidProvider('c1_ted_1')).value, isNull);
  });
}
