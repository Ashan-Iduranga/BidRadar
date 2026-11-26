import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/pipeline/bid_workflow.dart';
import '../widgets/app_header.dart';
import '../widgets/fit_score_badge.dart';
import '../widgets/skeletons.dart';
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
      child: GradientBackground(
        child: Scaffold(
          appBar: BrandAppBar(
            title: 'Pipeline',
            large: true,
            bottom: _StageTabs(
              counts: {
                for (final s in BidStage.values)
                  s: bids.value?.where((b) => b.stage == s).length,
              },
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
            _ => const CardListSkeleton(label: 'Loading bids'),
          },
        ),
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
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        Space.xl,
      ),
      itemCount: bids.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (context, i) => BidCard(
        key: ValueKey(bids[i].id),
        bid: bids[i],
      ).entrance(context, index: i),
    );
  }
}

/// Pill tabs for the 5 stages, each with its count.
class _StageTabs extends StatelessWidget implements PreferredSizeWidget {
  const _StageTabs({required this.counts});

  final Map<BidStage, int?> counts;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final controller = DefaultTabController.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter - 4),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          indicator: const BoxDecoration(),
          dividerHeight: 0,
          splashBorderRadius: BorderRadius.circular(Radii.pill),
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: [
            for (final (i, s) in BidStage.values.indexed)
              _StagePill(
                label: counts[s] == null
                    ? BidWorkflow.stageLabel(s)
                    : '${BidWorkflow.stageLabel(s)} ${counts[s]}',
                selected: controller.index == i,
                ink: b.ink,
                paper: b.surface,
                line: b.line,
              ),
          ],
        ),
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({
    required this.label,
    required this.selected,
    required this.ink,
    required this.paper,
    required this.line,
  });

  final String label;
  final bool selected;
  final Color ink;
  final Color paper;
  final Color line;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: reduceMotion(context) ? Duration.zero : Motion.medium,
    curve: Motion.emphasized,
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: selected ? ink : paper,
      borderRadius: BorderRadius.circular(Radii.pill),
      border: Border.all(color: selected ? ink : line, width: 1.5),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? paper : ink,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// One bid: title, buyer, deadline, verdict, approval and task progress.
/// Bids being prepared are filled orange, like the "on" cards in the smart
/// home reference, so active work stands out.
class BidCard extends StatelessWidget {
  const BidCard({super.key, required this.bid, this.trailing});
  final Bid bid;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = context.brand;
    final active = bid.stage == BidStage.preparing;
    final bg = active ? b.action : b.surface;
    final fg = active ? b.onAction : b.ink;
    final muted = active ? b.onAction : b.ink2;
    final progress = bid.tasks.isEmpty
        ? null
        : bid.tasksDone / bid.tasks.length;
    return Pressable(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: b.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bid.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              bid.buyer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      FitScoreBadge(
                        score: bid.fitScore,
                        textColor: fg,
                        track: active
                            ? b.onAction.withValues(alpha: .15)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.md,
                    runSpacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VerdictChip(verdict: bid.verdict, dense: true),
                      _Meta(
                        Icons.schedule_rounded,
                        deadlineLabel(bid.deadline, DateTime.now()),
                        color: muted,
                      ),
                      if (bid.approval == ApprovalState.pending)
                        _Meta(
                          Icons.hourglass_top_rounded,
                          'Awaiting approval',
                          color: muted,
                        ),
                      if (bid.approval == ApprovalState.rejected)
                        _Meta(
                          Icons.block_rounded,
                          'Approval rejected',
                          color: muted,
                        ),
                      if (bid.tasks.isNotEmpty)
                        _Meta(
                          Icons.checklist_rounded,
                          '${bid.tasksDone}/${bid.tasks.length} tasks',
                          color: muted,
                        ),
                    ],
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: Space.md),
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: reduceMotion(context) ? progress : 0,
                            end: progress,
                          ),
                          duration: Motion.extraLong,
                          curve: Motion.emphasized,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 6,
                            color: active ? b.onAction : b.action,
                            backgroundColor: active
                                ? b.onAction.withValues(alpha: .18)
                                : b.surface2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(height: Space.md),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Space.xs),
        // Wraps at large text sizes instead of running off the card.
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
