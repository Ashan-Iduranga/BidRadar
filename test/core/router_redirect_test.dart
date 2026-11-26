import 'package:bidradar/core/router/app_router.dart';
import 'package:bidradar/data/models/enums.dart';
import 'package:bidradar/ui/session/session_providers.dart';
import 'package:flutter_test/flutter_test.dart';

String? go(
  String location, {
  bool firebase = true,
  bool signedIn = true,
  Membership membership = Membership.member,
  UserRole? role = UserRole.owner,
  bool introSeen = true,
}) => redirectFor(
  introSeen: introSeen,
  location: location,
  firebaseReady: firebase,
  signedIn: signedIn,
  membership: membership,
  role: role,
);

void main() {
  test('signed-out users go to sign-in', () {
    expect(go(Routes.feed, signedIn: false), Routes.signIn);
    expect(go(Routes.signIn, signedIn: false), isNull);
  });

  test('first launch shows the intro before sign-in', () {
    expect(go(Routes.feed, signedIn: false, introSeen: false), Routes.intro);
    expect(go(Routes.signIn, signedIn: false, introSeen: false), Routes.intro);
    expect(go(Routes.intro, signedIn: false, introSeen: false), isNull);
    // Once seen, the intro is skipped.
    expect(go(Routes.intro, signedIn: false), Routes.signIn);
  });

  test('signed-in members never land on the intro', () {
    expect(go(Routes.intro), Routes.feed);
    expect(go(Routes.intro, introSeen: false), Routes.feed);
    // The replay from Profile is not a gate.
    expect(go(Routes.tour), isNull);
  });

  test('while the company loads, wait on the loading page', () {
    expect(go(Routes.feed, membership: Membership.loading), Routes.loading);
    expect(go(Routes.loading, membership: Membership.loading), isNull);
  });

  test('users without a company are sent to onboarding', () {
    expect(go(Routes.feed, membership: Membership.none), Routes.onboarding);
    expect(go(Routes.onboarding, membership: Membership.none), isNull);
  });

  test('members leave the gate pages for the feed', () {
    for (final gate in [Routes.signIn, Routes.loading, Routes.onboarding]) {
      expect(go(gate), Routes.feed);
    }
    expect(go(Routes.profile), isNull);
  });

  test('approvals are owner-only', () {
    expect(go(Routes.approvals), isNull);
    expect(go(Routes.approvals, role: UserRole.bidManager), Routes.feed);
    expect(go(Routes.approvals, role: null), Routes.feed);
  });

  test('without Firebase, the shell opens unauthenticated', () {
    expect(go(Routes.feed, firebase: false, signedIn: false), isNull);
    expect(go(Routes.onboarding, firebase: false), Routes.feed);
  });
}
