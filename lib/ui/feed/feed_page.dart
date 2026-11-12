import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/sync/background_sync.dart';
import '../session/session_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/skeletons.dart';
import '../widgets/state_views.dart';
import '../widgets/tender_card.dart';
import 'feed_view_model.dart';

/// Page 1: tenders for the company profile, ranked, filtered, offline-first.
/// Owner: Ashan. Phase 3 adds AI verdicts and fit scores.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  Timer? _tick;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(feedFilterProvider).query;
    // Keeps "Updated 5 min ago" current while the page is open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
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
  Widget build(BuildContext context) {
    final all = ref.watch(feedItemsProvider);
    final shown = ref.watch(filteredFeedProvider);
    final syncing = ref.watch(syncViewModelProvider).running;
    final lastRun = ref.watch(lastSyncProvider).value?.ranAt;
    final profile = ref.watch(currentProfileProvider).value;
    final company = ref.watch(currentCompanyProvider).value;
    final isOwner = ref.watch(currentRoleProvider) == UserRole.owner;
    final updated = syncing
        ? 'Syncing…'
        : updatedLabel(lastRun?.toLocal(), DateTime.now());

    return GradientBackground(
      child: Scaffold(
        appBar: BrandAppBar(
          large: true,
          overline: greeting(DateTime.now()),
          title: company?.name ?? 'Feed',
          actions: [
            if (profile != null)
              CircleIconButton(
                icon: Icons.sync_rounded,
                tooltip: 'Sync now',
                busy: syncing,
                onPressed: _sync,
              ),
            if (isOwner)
              CircleIconButton(
                icon: Icons.fact_check_outlined,
                tooltip: 'Approvals',
                onPressed: () => context.push(Routes.approvals),
              ),
            if (kDebugMode && profile != null)
              PopupMenuButton<void>(
                tooltip: 'Debug',
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () {
                      BackgroundSync.runSoonForTesting();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Background sync queued (debug).'),
                        ),
                      );
                    },
                    child: const Text('Run background sync (debug)'),
                  ),
                ],
              ),
          ],
        ),
        body: switch ((all, shown)) {
          (AsyncValue(:final error?), _) when !all.hasValue => ErrorState(
            message: 'Could not read saved tenders: $error',
            onRetry: () => ref.invalidate(cachedTendersProvider),
          ),
          (AsyncData(value: final items), AsyncData(value: final visible)) =>
            items.isEmpty
                ? _empty(profile != null, syncing)
                : _content(items, visible, profile, updated),
          _ => const CardListSkeleton(label: 'Loading tenders'),
        },
        floatingActionButton: Pressable(
          haptic: true,
          child: FloatingActionButton.extended(
            onPressed: () => context.push(Routes.scan),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan notice'),
          ),
        ),
      ),
    );
  }

  Widget _empty(bool hasProfile, bool syncing) {
    if (!hasProfile) {
      return EmptyState(
        icon: Icons.radar,
        title: 'No tenders yet',
        message:
            'Set up your company profile first. BidRadar then pulls '
            'matching tenders from EU TED and the World Bank.',
        actionLabel: 'Set up company profile',
        onAction: () => context.go(Routes.profile),
      );
    }
    return EmptyState(
      icon: Icons.radar,
      title: 'No tenders yet',
      message:
          'Sync to pull tenders that match your sectors and countries from '
          'EU TED and the World Bank. BidRadar also syncs every 6 hours.',
      actionLabel: syncing ? 'Syncing…' : 'Sync now',
      onAction: syncing ? null : _sync,
    );
  }

  Widget _content(
    List<FeedItem> items,
    List<FeedItem> visible,
    CompanyProfile? profile,
    String updated,
  ) {
    final theme = Theme.of(context);
    final b = context.brand;
    const pad = EdgeInsets.symmetric(horizontal: Space.gutter);
    return RefreshIndicator(
      onRefresh: _sync,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: pad.copyWith(top: Space.xs),
              child: _SearchPill(
                controller: _search,
                onChanged: ref.read(feedFilterProvider.notifier).setQuery,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: pad.copyWith(top: Space.lg),
              child: _SummaryHero(
                items: items,
                updated: updated,
              ).entrance(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.lg),
              child: _FilterBar(profile: profile, items: items),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: pad.copyWith(top: Space.lg, bottom: Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Best matches',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: b.ink,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    visible.length == 1
                        ? '1 tender'
                        : '${visible.length} tenders',
                    style: theme.textTheme.labelLarge?.copyWith(color: b.ink2),
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'Nothing matches these filters',
                message: '${items.length} tenders are hidden by the filters.',
                actionLabel: 'Clear filters',
                onAction: () {
                  _search.clear();
                  ref.read(feedFilterProvider.notifier).clear();
                },
              ),
            )
          else
            SliverPadding(
              // Room for the Scan button.
              padding: pad.copyWith(bottom: 104),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                itemBuilder: (context, i) {
                  final item = visible[i];
                  return TenderCard(
                    key: ValueKey(item.tender.id),
                    tender: item.tender,
                    rules: item.rules,
                    verdict: item.verdict,
                    onTap: () => context.push(Routes.tender(item.tender.id)),
                  ).entrance(context, index: i);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// "Good morning" / "Good afternoon" / "Good evening".
String greeting(DateTime now) => now.hour < 12
    ? 'Good morning'
    : now.hour < 17
    ? 'Good afternoon'
    : 'Good evening';

/// Rounded search field, like the reference home screens.
class _SearchPill extends StatefulWidget {
  const _SearchPill({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.pill),
      borderSide: BorderSide.none,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: b.cardShadow,
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: (v) {
          widget.onChanged(v);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search tenders or buyers',
          hintStyle: TextStyle(color: b.ink2),
          prefixIcon: Icon(Icons.search_rounded, color: b.ink2),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: b.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.pill),
            borderSide: BorderSide(color: b.actionInk, width: 2),
          ),
        ),
      ),
    );
  }
}

/// The black hero card: how many tenders the AI says to bid on, how many
/// close soon, and how many are saved offline.
class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.items, required this.updated});

  final List<FeedItem> items;
  final String updated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = context.brand;
    final now = DateTime.now();
    final bid = applyFeedFilter(
      items,
      const FeedFilter(status: FeedStatus.bid),
    ).length;
    final closing = applyFeedFilter(items, const FeedFilter()).where((i) {
      final d = i.tender.deadline;
      return d != null && d.isAfter(now) && d.difference(now).inDays < 7;
    }).length;
    const tabular = [FontFeature.tabularFigures()];

    Widget smallStat(int n, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$n ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: b.onHero,
              fontWeight: FontWeight.w800,
              fontFeatures: tabular,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(color: b.heroMuted),
    );

    return Semantics(
      container: true,
      label:
          '$bid tenders the AI says bid. $closing close in 7 days. '
          '${items.length} saved. $updated.',
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: b.hero,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Bars like the palette reference, growing in.
            Positioned(
              right: 20,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bar(height: 104, color: b.heroAccent, delay: 0),
                  const SizedBox(width: 8),
                  _Bar(height: 70, color: b.accent, delay: 1),
                  const SizedBox(width: 8),
                  _Bar(
                    height: 42,
                    color: b.heroMuted.withValues(alpha: .5),
                    delay: 2,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 140, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week · ${_lowerFirst(updated)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: b.heroMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _CountUp(
                        value: bid,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: b.heroAccent,
                          fontFeatures: tabular,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'tenders the AI says bid',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: b.onHero,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      smallStat(closing, 'close in 7 days'),
                      smallStat(items.length, 'saved'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color, required this.delay});

  final double height;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 30,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
    );
    if (reduceMotion(context)) return bar;
    // Grows up from the bottom, one bar after another.
    final total = Motion.extraLong + Motion.stagger * (delay + 2);
    final start = 1 - Motion.extraLong.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (_, t, child) => Transform.scale(
        alignment: Alignment.bottomCenter,
        scaleY: Interval(
          start,
          1,
          curve: Motion.emphasizedDecelerate,
        ).transform(t),
        child: child,
      ),
      child: bar,
    );
  }
}

/// Counts up to [value] when it first appears.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: reduceMotion(context) ? value.toDouble() : 0,
      end: value.toDouble(),
    ),
    duration: Motion.extraLong,
    curve: Motion.emphasized,
    builder: (_, v, _) => Text('${v.round()}', style: style),
  );
}

/// Status, source and sector filters (Material 3 filter chips).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.profile, required this.items});

  final CompanyProfile? profile;
  final List<FeedItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(feedFilterProvider);
    final vm = ref.read(feedFilterProvider.notifier);
    int count(FeedStatus s) => applyFeedFilter(
      items,
      FeedFilter(sources: f.sources, status: s, sector: f.sector),
    ).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          for (final s in FeedStatus.values) ...[
            ChoiceChip(
              label: Text('${s.label} ${count(s)}'),
              selected: f.status == s,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                vm.setStatus(s);
              },
            ),
            const SizedBox(width: Space.sm),
          ],
          const SizedBox(height: 32, child: VerticalDivider()),
          const SizedBox(width: Space.sm),
          for (final (type, label) in [
            (TenderSourceType.ted, 'EU TED'),
            (TenderSourceType.worldBank, 'World Bank'),
          ]) ...[
            FilterChip(
              label: Text(label),
              selected: f.sources.contains(type),
              onSelected: (_) => vm.toggleSource(type),
            ),
            const SizedBox(width: Space.sm),
          ],
          if (profile != null && profile!.cpvCodes.isNotEmpty)
            FilterChip(
              avatar: const Icon(Icons.category_outlined, size: IconSizes.sm),
              label: Text(f.sector == null ? 'Any sector' : 'CPV ${f.sector}'),
              selected: f.sector != null,
              onSelected: (_) async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  builder: (_) => _SectorSheet(
                    codes: profile!.cpvCodes,
                    selected: f.sector,
                  ),
                );
                if (picked != null) {
                  vm.setSector(picked.isEmpty ? null : picked);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _SectorSheet extends StatelessWidget {
  const _SectorSheet({required this.codes, required this.selected});
  final List<String> codes;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.sm,
            ),
            child: Text(
              'Filter by sector',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: const Text('Any sector'),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final c in codes)
            ListTile(
              title: Text('CPV $c'),
              subtitle: const Text('Includes its sub-codes'),
              trailing: selected == c ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
  }
}
