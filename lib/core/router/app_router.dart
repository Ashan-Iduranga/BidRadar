import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../../ui/account/account_page.dart';
import '../../ui/approvals/approvals_page.dart';
import '../../ui/auth/auth_providers.dart';
import '../../ui/auth/sign_in_page.dart';
import '../../ui/deadlines/deadlines_page.dart';
import '../../ui/feed/feed_page.dart';
import '../../ui/insights/insights_page.dart';
import '../../ui/intro/intro_page.dart';
import '../../ui/onboarding/onboarding_page.dart';
import '../../ui/pipeline/bid_page.dart';
import '../../ui/pipeline/pipeline_page.dart';
import '../../ui/profile/profile_page.dart';
import '../../ui/scan/scan_page.dart';
import '../../ui/session/session_providers.dart';
import '../../ui/settings/settings_providers.dart';
import '../../ui/shell/app_shell.dart';
import '../../ui/tender_detail/tender_detail_page.dart';
import '../firebase/firebase_bootstrap.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Route paths, in one place so pages never hard-code strings.
abstract final class Routes {
  static const intro = '/intro';

  /// The intro replayed from Profile (not a gate: it pops when done).
  static const tour = '/tour';
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

  /// Personal profile and settings, opened from the avatar.
  static const account = '/account';
  static String tender(String id) => '/tender/$id';
  static String bid(String id) => '/bid/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  // Re-run redirects whenever sign-in, membership, role or the intro flag
  // changes.
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(
      settingsProvider.select((s) => s.introSeen),
      (_, _) => refresh.value++,
    )
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
      introSeen: ref.read(settingsProvider).introSeen,
      membership: ref.read(membershipProvider),
      role: ref.read(currentRoleProvider),
    ),
    routes: [
      GoRoute(path: Routes.intro, builder: (_, _) => const IntroPage()),
      GoRoute(
        path: Routes.tour,
        builder: (_, _) => const IntroPage(replay: true),
      ),
      // Sign-in fades in, so the intro's colour reveal hands over smoothly.
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignInPage(),
          transitionDuration: reduceMotion(context)
              ? Duration.zero
              : Motion.long,
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Motion.emphasizedDecelerate,
            ),
            child: child,
          ),
        ),
      ),
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
      GoRoute(
        path: '/bid/:id',
        builder: (_, state) => BidPage(bidId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.scan, builder: (_, _) => const ScanPage()),
      GoRoute(path: Routes.approvals, builder: (_, _) => const ApprovalsPage()),
      GoRoute(path: Routes.account, builder: (_, _) => const AccountPage()),
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
  bool introSeen = true,
}) {
  const gates = {
    Routes.intro,
    Routes.signIn,
    Routes.loading,
    Routes.onboarding,
  };
  // Without Firebase the shell runs unauthenticated (dev only).
  if (!firebaseReady) return gates.contains(location) ? Routes.feed : null;
  if (!signedIn) {
    // First launch: the intro comes before sign-in.
    final entry = introSeen ? Routes.signIn : Routes.intro;
    return location == entry ? null : entry;
  }
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
  Widget build(BuildContext context) => const GradientBackground(
    child: Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading your company',
        ),
      ),
    ),
  );
}
