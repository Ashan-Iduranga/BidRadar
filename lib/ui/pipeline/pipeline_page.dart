import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/pipeline/bid_workflow.dart';
import '../widgets/fit_score_badge.dart';
import '../widgets/state_views.dart';
import '../widgets/tender_card.dart' show deadlineLabel;
import '../widgets/verdict_chip.dart';
import 'pipeline_view_model.dart';

/// Page 5: bids by stage. Owner: Sewmin.
class PipelinePage extends ConsumerWidget {
  const PipelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bids = ref.watch(bidsProvider);
    return DefaultTabController(
      length: BidStage.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pipeline'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in BidStage.values)
                Tab(
                  text:
                      '${BidWorkflow.stageLabel(s)} '
                      '${bids.value?.where((b) => b.stage == s).length ?? ''}',
                ),
            ],
          ),
        ),
        // Check the error first: while Riverpod retries a failed stream the
        // state is "loading with an error", which would otherwise spin.
        body: switch (bids) {
          AsyncValue(:final error?) when !bids.hasValue => ErrorState(
            message: 'Could not load bids: $error',
            onRetry: () => ref.invalidate(bidsProvider),
          ),
          AsyncData(:final value) => TabBarView(
            children: [
              for (final s in BidStage.values)
                _StageList(
                  stage: s,
                  bids: value.where((b) => b.stage == s).toList()
                    ..sort(_byDeadline),
                ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  static int _byDeadline(Bid a, Bid b) {
    if (a.deadline == null) return b.deadline == null ? 0 : 1;
    if (b.deadline == null) return -1;
    return a.deadline!.compareTo(b.deadline!);
  }
}

class _StageList extends StatelessWidget {
  const _StageList({required this.stage, required this.bids});
  final BidStage stage;
  final List<Bid> bids;

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty) {
      return EmptyState(
        icon: Icons.view_kanban_outlined,
        title: 'No bids ${BidWorkflow.stageLabel(stage).toLowerCase()}',
        message: switch (stage) {
          BidStage.watching =>
            'Open a tender from the feed and tap Watch to add it here.',
          BidStage.preparing => 'Bids move here once the owner approves them.',
          BidStage.submitted => 'Mark a prepared bid as submitted.',
          BidStage.won || BidStage.lost =>
            'Record outcomes of submitted bids to learn from them.',
        },
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(Space.gutter),
      itemCount: bids.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (_, i) => BidCard(bid: bids[i]),
    );
  }
}

/// One bid: title, buyer, deadline, verdict, approval and task progress.
class BidCard extends StatelessWidget {
  const BidCard({super.key, required this.bid, this.trailing});
  final Bid bid;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.bid(bid.id)),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      bid.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  FitScoreBadge(score: bid.fitScore),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                bid.buyer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  VerdictChip(verdict: bid.verdict, dense: true),
                  _Meta(
                    Icons.schedule,
                    deadlineLabel(bid.deadline, DateTime.now()),
                  ),
                  if (bid.approval == ApprovalState.pending)
                    const _Meta(Icons.hourglass_top, 'Awaiting approval'),
                  if (bid.approval == ApprovalState.rejected)
                    const _Meta(Icons.block, 'Approval rejected'),
                  if (bid.tasks.isNotEmpty)
                    _Meta(
                      Icons.checklist,
                      '${bid.tasksDone}/${bid.tasks.length} tasks',
                    ),
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(height: Space.md),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Space.xs),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
