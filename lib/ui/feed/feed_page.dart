import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/sync/background_sync.dart';
import '../session/session_providers.dart';
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

  @override
  void initState() {
    super.initState();
    // Keeps "Updated 5 min ago" current while the page is open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
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
    final isOwner = ref.watch(currentRoleProvider) == UserRole.owner;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feed'),
            if (profile != null)
              Text(
                syncing
                    ? 'Syncing…'
                    : updatedLabel(lastRun?.toLocal(), DateTime.now()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (profile != null)
            IconButton(
              tooltip: 'Sync now',
              icon: syncing
                  ? const SizedBox.square(
                      dimension: IconSizes.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: syncing ? null : _sync,
            ),
          if (isOwner)
            IconButton(
              tooltip: 'Approvals',
              icon: const Icon(Icons.fact_check_outlined),
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
        (AsyncError(:final error), _) => ErrorState(
          message: 'Could not read saved tenders: $error',
          onRetry: () => ref.invalidate(cachedTendersProvider),
        ),
        (AsyncData(value: final items), AsyncData(value: final visible)) =>
          items.isEmpty
              ? _empty(profile != null, syncing)
              : Column(
                  children: [
                    _FilterBar(profile: profile, items: items),
                    Expanded(child: _list(visible, items.length)),
                  ],
                ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.scan),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan notice'),
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

  Widget _list(List<FeedItem> visible, int total) {
    return RefreshIndicator(
      onRefresh: _sync,
      child: visible.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nothing matches these filters',
                  message: '$total tenders are hidden by the filters.',
                  actionLabel: 'Clear filters',
                  onAction: ref.read(feedFilterProvider.notifier).clear,
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                96, // room for the FAB
              ),
              itemCount: visible.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    visible.length == 1
                        ? '1 tender'
                        : '${visible.length} tenders',
                    style: Theme.of(context).textTheme.titleSmall,
                  );
                }
                final item = visible[i - 1];
                return TenderCard(
                  tender: item.tender,
                  rules: item.rules,
                  verdict: item.verdict,
                  onTap: () => context.push(Routes.tender(item.tender.id)),
                );
              },
            ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xs,
        Space.gutter,
        Space.xs,
      ),
      child: Row(
        children: [
          for (final s in FeedStatus.values) ...[
            ChoiceChip(
              label: Text('${s.label} ${count(s)}'),
              selected: f.status == s,
              onSelected: (_) => vm.setStatus(s),
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
              showCheckmark: false,
              onSelected: (_) async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
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
