import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../deadlines/deadlines_view_model.dart';

/// Bottom navigation for the 5 top-level pages: a floating black bar with an
/// orange pill on the current tab. Tender detail, Scan, Approvals and
/// Profile are pushed on top of the shell.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const destinations = [
    (Icons.radar_outlined, Icons.radar, 'Feed'),
    (Icons.view_kanban_outlined, Icons.view_kanban, 'Pipeline'),
    (Icons.event_outlined, Icons.event, 'Deadlines'),
    (Icons.insights_outlined, Icons.insights, 'Insights'),
    (Icons.business_outlined, Icons.business, 'Company'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    // Deadline reminders follow the pipeline while the app is open.
    if (firebaseReady) ref.watch(reminderSyncProvider);
    return GradientBackground(
      child: Scaffold(
        body: Column(
          children: [
            if (!firebaseReady) const _FirebaseMissingBanner(),
            Expanded(child: shell),
          ],
        ),
        bottomNavigationBar: FloatingNavBar(
          index: shell.currentIndex,
          onSelected: (i) {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
        ),
      ),
    );
  }
}

/// The floating rounded nav bar (Trantor / Ultro references): every tab has
/// an icon and a label; the current one sits in an orange pill.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: b.nav,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Main navigation',
            child: Row(
              children: [
                for (var i = 0; i < AppShell.destinations.length; i++)
                  Expanded(
                    flex: i == index ? 15 : 10,
                    child: _NavItem(
                      icon: AppShell.destinations[i].$1,
                      selectedIcon: AppShell.destinations[i].$2,
                      label: AppShell.destinations[i].$3,
                      selected: i == index,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final duration = reduceMotion(context) ? Duration.zero : Motion.medium;
    final fg = selected ? b.onNavActive : b.navInk;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: fg,
      fontWeight: FontWeight.w800,
      fontSize: selected ? 12.5 : 11,
    );
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? b.navActive : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
              child: AnimatedSwitcher(
                duration: duration,
                child: selected
                    ? FittedBox(
                        key: const ValueKey(true),
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(selectedIcon, size: 22, color: fg),
                              const SizedBox(width: 6),
                              Text(label, style: style),
                            ],
                          ),
                        ),
                      )
                    : FittedBox(
                        key: const ValueKey(false),
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 22, color: fg),
                            const SizedBox(height: 2),
                            Text(label, style: style),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
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
