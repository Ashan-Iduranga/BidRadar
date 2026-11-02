import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/approvals/approvals_page.dart';
import '../../ui/auth/auth_providers.dart';
import '../../ui/auth/sign_in_page.dart';
import '../../ui/deadlines/deadlines_page.dart';
import '../../ui/feed/feed_page.dart';
import '../../ui/insights/insights_page.dart';
import '../../ui/pipeline/pipeline_page.dart';
import '../../ui/profile/profile_page.dart';
import '../../ui/scan/scan_page.dart';
import '../../ui/shell/app_shell.dart';
import '../../ui/tender_detail/tender_detail_page.dart';
import '../firebase/firebase_bootstrap.dart';

/// Route paths, in one place so pages never hard-code strings.
abstract final class Routes {
  static const signIn = '/sign-in';
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
  // Re-run redirects whenever sign-in state changes.
  final authListenable = ValueNotifier<bool>(false);
  ref.listen(authStateProvider, (_, next) {
    authListenable.value = next.value != null;
  });
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: Routes.feed,
    refreshListenable: authListenable,
    redirect: (context, state) {
      // Without Firebase the shell runs unauthenticated (dev only).
      if (!firebaseReady) {
        return state.matchedLocation == Routes.signIn ? Routes.feed : null;
      }
      final signedIn = ref.read(authStateProvider).value != null;
      final atSignIn = state.matchedLocation == Routes.signIn;
      if (!signedIn) return atSignIn ? null : Routes.signIn;
      if (atSignIn) return Routes.feed;
      // Phase 1: owner-only redirect for /approvals once roles exist.
      return null;
    },
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInPage()),
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
