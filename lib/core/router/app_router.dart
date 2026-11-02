import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../ui/approvals/approvals_page.dart';
import '../../ui/auth/auth_providers.dart';
import '../../ui/auth/sign_in_page.dart';
import '../../ui/deadlines/deadlines_page.dart';
import '../../ui/feed/feed_page.dart';
import '../../ui/insights/insights_page.dart';
import '../../ui/onboarding/onboarding_page.dart';
import '../../ui/pipeline/pipeline_page.dart';
import '../../ui/profile/profile_page.dart';
import '../../ui/scan/scan_page.dart';
import '../../ui/session/session_providers.dart';
import '../../ui/shell/app_shell.dart';
import '../../ui/tender_detail/tender_detail_page.dart';
import '../firebase/firebase_bootstrap.dart';

/// Route paths, in one place so pages never hard-code strings.
abstract final class Routes {
  static const signIn = '/sign-in';
  static const loading = '/loading';
  static const onboarding = '/onboarding';
  static const feed = '/feed';
  static const pipeline = '/pipeline';
  static const deadlines = '/deadlines';
  static const insights = '/insights';
  static const profile = '/profile';
  static const scan = '/scan';
  static const approvals = '/approvals';
  static String tender(String id) => '/tender/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  // Re-run redirects whenever sign-in, membership or role changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(membershipProvider, (_, _) => refresh.value++)
    ..listen(currentRoleProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.feed,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.matchedLocation,
      firebaseReady: firebaseReady,
      signedIn: ref.read(authStateProvider).value != null,
      membership: ref.read(membershipProvider),
      role: ref.read(currentRoleProvider),
    ),
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInPage()),
      GoRoute(path: Routes.loading, builder: (_, _) => const _LoadingPage()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _branch(Routes.feed, const FeedPage()),
          _branch(Routes.pipeline, const PipelinePage()),
          _branch(Routes.deadlines, const DeadlinesPage()),
          _branch(Routes.insights, const InsightsPage()),
          _branch(Routes.profile, const ProfilePage()),
        ],
      ),
      GoRoute(
        path: '/tender/:id',
        builder: (_, state) =>
            TenderDetailPage(tenderId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.scan, builder: (_, _) => const ScanPage()),
      GoRoute(path: Routes.approvals, builder: (_, _) => const ApprovalsPage()),
    ],
  );
});

StatefulShellBranch _branch(String path, Widget page) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => page)],
);

/// Pure redirect rules, unit tested in test/core/router_redirect_test.dart.
String? redirectFor({
  required String location,
  required bool firebaseReady,
  required bool signedIn,
  required Membership membership,
  required UserRole? role,
}) {
  const gates = {Routes.signIn, Routes.loading, Routes.onboarding};
  // Without Firebase the shell runs unauthenticated (dev only).
  if (!firebaseReady) return gates.contains(location) ? Routes.feed : null;
  if (!signedIn) return location == Routes.signIn ? null : Routes.signIn;
  switch (membership) {
    case Membership.loading:
      return location == Routes.loading ? null : Routes.loading;
    case Membership.none:
      return location == Routes.onboarding ? null : Routes.onboarding;
    case Membership.member:
      if (gates.contains(location)) return Routes.feed;
      // Only the owner approves bids.
      if (location == Routes.approvals && role != UserRole.owner) {
        return Routes.feed;
      }
      return null;
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading your company'),
    ),
  );
}
