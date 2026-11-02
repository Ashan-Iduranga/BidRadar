import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../session/session_providers.dart';
import '../widgets/state_views.dart';
import '../widgets/tender_card.dart';
import 'feed_view_model.dart';

/// Page 1: tenders for the company profile. Owner: Ashan.
/// Phase 1: live fetch, offline cache, hard rules. Phase 2 adds FeedSync,
/// filters and background sync; Phase 3 adds AI verdicts and fit scores.
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  bool _showRemoved = false;

  Future<void> _fetch() async {
    final vm = ref.read(fetchViewModelProvider.notifier);
    await vm.fetch();
    if (!mounted) return;
    final s = ref.read(fetchViewModelProvider);
    final parts = [
      '${s.added} new',
      if (s.duplicates > 0) '${s.duplicates} duplicates skipped',
      ...s.errors,
    ];
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(parts.join(' · '))));
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(feedItemsProvider);
    final fetching = ref.watch(fetchViewModelProvider).running;
    final hasProfile = ref.watch(currentProfileProvider).value != null;
    final isOwner = ref.watch(currentRoleProvider) == UserRole.owner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          if (hasProfile)
            IconButton(
              tooltip: 'Fetch tenders now',
              icon: fetching
                  ? const SizedBox.square(
                      dimension: IconSizes.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: fetching ? null : _fetch,
            ),
          if (isOwner)
            IconButton(
              tooltip: 'Approvals',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => context.push(Routes.approvals),
            ),
        ],
      ),
      body: switch (items) {
        AsyncError(:final error) => ErrorState(
          message: 'Could not read saved tenders: $error',
          onRetry: () => ref.invalidate(cachedTendersProvider),
        ),
        AsyncData(:final value) => _list(value, hasProfile, fetching),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.scan),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan notice'),
      ),
    );
  }

  Widget _list(List<FeedItem> all, bool hasProfile, bool fetching) {
    if (all.isEmpty) {
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
            'Fetch tenders that match your sectors and countries from EU '
            'TED and the World Bank.',
        actionLabel: fetching ? 'Fetching…' : 'Fetch tenders',
        onAction: fetching ? null : _fetch,
      );
    }

    final removed = all.where((i) => i.rules?.passed == false).length;
    final shown = _showRemoved
        ? all
        : all.where((i) => i.rules?.passed != false).toList();

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.sm,
          Space.gutter,
          96, // room for the FAB
        ),
        itemCount: shown.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Summary(
              eligible: all.length - removed,
              removed: removed,
              showRemoved: _showRemoved,
              onToggle: (v) => setState(() => _showRemoved = v),
            );
          }
          final item = shown[i - 1];
          return TenderCard(
            tender: item.tender,
            rules: item.rules,
            onTap: () => context.push(Routes.tender(item.tender.id)),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.eligible,
    required this.removed,
    required this.showRemoved,
    required this.onToggle,
  });

  final int eligible;
  final int removed;
  final bool showRemoved;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text('$eligible eligible', style: theme.textTheme.titleSmall),
        ),
        if (removed > 0)
          FilterChip(
            label: Text('Show $removed removed by rules'),
            selected: showRemoved,
            onSelected: onToggle,
          ),
      ],
    );
  }
}
