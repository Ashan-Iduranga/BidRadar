import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../auth/auth_providers.dart';
import '../feed/feed_view_model.dart';
import '../insights/insights_view_model.dart';
import '../pipeline/pipeline_view_model.dart';
import '../session/session_providers.dart';
import '../settings/notification_access.dart';
import '../settings/settings_providers.dart';
import '../widgets/app_header.dart';

/// App version shown in About (matches pubspec.yaml).
const kAppVersion = '1.0.0';

/// Profile: who you are, how you are doing, and device settings (theme,
/// notifications, intro). Opened from the avatar at the top right of every
/// page. Company details stay on the Company tab.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Widget section(String title, Widget child, int i) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, Space.xl, 4, Space.sm),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
        ),
        child,
      ],
    ).entrance(context, index: i);

    return GradientBackground(
      child: Scaffold(
        appBar: const BrandAppBar(title: 'Profile', showAvatar: false),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.xxxl,
          ),
          children: [
            const _IdentityCard().entrance(context),
            const SizedBox(height: Space.lg),
            const _ProgressRings().entrance(context, index: 1),
            section(
              'Appearance',
              _ThemePicker(
                mode: settings.themeMode,
                onChanged: (m) {
                  HapticFeedback.selectionClick();
                  vm.setThemeMode(m);
                },
              ),
              2,
            ),
            section('Notifications', const _NotificationSwitches(), 3),
            section('Data and help', const _DataAndHelp(), 4),
            const SizedBox(height: Space.xl),
            const _SignOutButton().entrance(context, index: 5),
          ],
        ),
      ),
    );
  }
}

/// The black hero card: avatar, email, role and company.
class _IdentityCard extends ConsumerWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.brand;
    final theme = Theme.of(context);
    final email = ref.watch(authStateProvider).value?.email;
    final role = ref.watch(currentRoleProvider);
    final company = ref.watch(currentCompanyProvider).value;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: b.hero,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(190),
                painter: _ArcsPainter(b.heroAccent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Center(
              child: Column(
                children: [
                  _PopIn(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: b.onHero, width: 4),
                      ),
                      child: Avatar(
                        initials: initialsFor(email),
                        size: 84,
                        ring: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    email ?? 'Not signed in',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: b.onHero,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      if (role != null)
                        _Badge(
                          icon: role == UserRole.owner
                              ? Icons.verified_user_outlined
                              : Icons.person_outline,
                          text: role == UserRole.owner
                              ? 'Owner'
                              : 'Bid manager',
                          bg: b.heroAccent,
                          fg: b.onAction,
                        ),
                      if (company != null)
                        _Badge(
                          text: company.name,
                          bg: Colors.transparent,
                          fg: b.onHero,
                          border: b.heroMuted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Springs the avatar in when Profile opens.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => reduceMotion(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: .6, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutBack,
          builder: (_, v, c) => Transform.scale(scale: v, child: c),
          child: child,
        );
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    this.border,
  });

  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: border == null ? null : Border.all(color: border!, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
          ),
        ),
      ],
    ),
  );
}

/// Win rate, AI agreement and checklist progress as rings.
class _ProgressRings extends ConsumerWidget {
  const _ProgressRings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.brand;
    final stats = ref.watch(insightsProvider);
    final bids = ref.watch(bidsProvider).value ?? const <Bid>[];
    final tasks = [for (final bid in bids) ...bid.tasks];
    final done = tasks.where((t) => t.done).length;

    String pct(double? v) => v == null ? '–' : '${(v * 100).round()}%';

    final rings = [
      (
        'Win rate',
        stats.winRate,
        stats.decided == 0
            ? 'No outcomes yet'
            : '${stats.won} of ${stats.decided} won',
        b.action,
      ),
      (
        'AI agreed',
        stats.agreement,
        stats.judgedDecided == 0
            ? 'Needs outcomes'
            : '${stats.agreed} of ${stats.judgedDecided}',
        b.accent,
      ),
      (
        'Tasks done',
        tasks.isEmpty ? null : done / tasks.length,
        tasks.isEmpty ? 'No tasks yet' : '$done of ${tasks.length}',
        b.ink,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: Row(
        children: [
          for (final (label, value, sub, color) in rings)
            Expanded(
              child: Semantics(
                label: '$label ${pct(value)}, $sub',
                excludeSemantics: true,
                child: Column(
                  children: [
                    _Ring(value: value, color: color, text: pct(value)),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: b.ink, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: b.ink2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color, required this.text});

  final double? value;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final target = value ?? 0;
    return SizedBox.square(
      dimension: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: reduceMotion(context) ? target : 0,
              end: target,
            ),
            duration: const Duration(milliseconds: 1000),
            curve: Motion.emphasized,
            builder: (_, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: b.surface2,
              constraints: BoxConstraints.tight(const Size.square(70)),
            ),
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: b.ink,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// System / Light / Dark.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            side: WidgetStatePropertyAll(BorderSide.none),
          ),
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

/// A white rounded card holding rows separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 16, endIndent: 16, color: b.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The 2 notification switches. They show off while Android blocks
/// BidRadar's notifications, whatever the saved choice, and explain how to
/// turn them back on.
class _NotificationSwitches extends ConsumerWidget {
  const _NotificationSwitches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);
    final access = ref.read(notificationAccessProvider.notifier);
    final blocked =
        ref.watch(notificationAccessProvider).value ==
        NotificationAccess.blocked;

    Future<void> set(bool on, Future<void> Function(bool) save) async {
      if (on && blocked) {
        final messenger = ScaffoldMessenger.of(context);
        if (!await access.request()) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Allow notifications for BidRadar in Android settings.',
              ),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: access.openSettings,
              ),
            ),
          );
          return;
        }
      }
      await save(on);
    }

    return _Group(
      children: [
        _SwitchRow(
          title: 'Deadline reminders',
          subtitle: '7, 3 and 1 days before, at 9:00, plus a Monday digest',
          value: settings.deadlineReminders && !blocked,
          onChanged: (on) => set(on, vm.setDeadlineReminders),
        ),
        _SwitchRow(
          title: 'New matching tenders',
          subtitle: 'After each background sync',
          value: settings.newTenderAlerts && !blocked,
          onChanged: (on) => set(on, vm.setNewTenderAlerts),
        ),
        if (blocked)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const Icon(Icons.notifications_off_outlined),
            title: const Text(
              'Notifications are off for BidRadar in Android settings, so '
              'reminders and alerts cannot appear.',
            ),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: access.openSettings,
                child: const Text('Open settings'),
              ),
            ),
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    value: value,
    onChanged: (v) {
      HapticFeedback.selectionClick();
      onChanged(v);
    },
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: b.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: b.ink),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: b.ink2),
      onTap: onTap,
    );
  }
}

class _DataAndHelp extends ConsumerWidget {
  const _DataAndHelp();

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await ref.read(syncViewModelProvider.notifier).syncNow();
      if (report == null) return;
      messenger.showSnackBar(SnackBar(content: Text(syncSummary(report))));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(syncViewModelProvider).running;
    final lastRun = ref.watch(lastSyncProvider).value?.ranAt;
    final hasProfile = ref.watch(currentProfileProvider).value != null;
    return _Group(
      children: [
        _NavRow(
          icon: Icons.sync_rounded,
          title: syncing ? 'Syncing…' : 'Sync now',
          subtitle: updatedLabel(lastRun?.toLocal(), DateTime.now()),
          onTap: syncing || !hasProfile ? null : () => _sync(context, ref),
          trailing: syncing
              ? const SizedBox.square(
                  dimension: IconSizes.sm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        _NavRow(
          icon: Icons.slideshow_rounded,
          title: 'Replay the intro',
          subtitle: 'See the 3-step tour again',
          onTap: () => context.push(Routes.tour),
        ),
        _NavRow(
          icon: Icons.info_outline_rounded,
          title: 'About BidRadar',
          subtitle: 'Version $kAppVersion · Data from EU TED and World Bank',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'BidRadar',
            applicationVersion: kAppVersion,
            children: const [
              Text(
                'BidRadar finds public tenders your company can win. Tender '
                'data comes from EU TED and the World Bank. Your company '
                'data stays private to your team.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danger = Theme.of(context).colorScheme.error;
    final firebaseReady = ref.watch(firebaseReadyProvider);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger,
        side: BorderSide(color: danger, width: 1.5),
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Sign out'),
      onPressed: !firebaseReady
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'Your tenders stay saved on this phone. Sign in again to '
                    'keep working.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) await ref.read(authServiceProvider).signOut();
            },
    );
  }
}

/// Three radar arcs for the hero card corner.
class _ArcsPainter extends CustomPainter {
  const _ArcsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 190;
    for (final (r, a) in [(130.0, .3), (86.0, .6)]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(150 * s, 40 * s), radius: r * s),
        1.5708,
        1.5708,
        false,
        Paint()
          ..color = color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12 * s
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcsPainter old) => old.color != color;
}
