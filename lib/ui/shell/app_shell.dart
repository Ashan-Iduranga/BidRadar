import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../deadlines/deadlines_view_model.dart';

/// Bottom navigation for the 5 top-level pages. Tender detail, Scan and
/// Approvals are pushed on top of the shell.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar),
      label: 'Feed',
    ),
    NavigationDestination(
      icon: Icon(Icons.view_kanban_outlined),
      selectedIcon: Icon(Icons.view_kanban),
      label: 'Pipeline',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'Deadlines',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Insights',
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: 'Company',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    // Deadline reminders follow the pipeline while the app is open.
    if (firebaseReady) ref.watch(reminderSyncProvider);
    return Scaffold(
      body: Column(
        children: [
          if (!firebaseReady) const _FirebaseMissingBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

class _FirebaseMissingBanner extends StatelessWidget {
  const _FirebaseMissingBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Firebase not configured. Sign-in and sync are off. '
                  'Run flutterfire configure.',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
