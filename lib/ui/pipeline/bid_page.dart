import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/pipeline/bid_workflow.dart';
import '../session/session_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/tender_card.dart' show deadlineLabel;
import '../widgets/verdict_chip.dart';
import 'approval_dialog.dart';
import 'pipeline_view_model.dart';

/// One bid: stage actions, approval, document checklist.
class BidPage extends ConsumerWidget {
  const BidPage({super.key, required this.bidId});
  final String bidId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bid = ref.watch(bidProvider(bidId));
    return GradientBackground(
      child: Scaffold(
        appBar: const BrandAppBar(title: 'Bid'),
        body: switch (bid) {
          AsyncValue(:final error?) when !bid.hasValue => ErrorState(
            message: '$error',
          ),
          AsyncData(value: null) => EmptyState(
            icon: Icons.view_kanban_outlined,
            title: 'Bid removed',
            message: 'This bid is no longer in the pipeline.',
            actionLabel: 'Back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
          AsyncData(:final value?) => _BidBody(bid: value),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _BidBody extends ConsumerWidget {
  const _BidBody({required this.bid});
  final Bid bid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final role = ref.watch(currentRoleProvider);
    final isOwner = role == UserRole.owner;
    final actions = ref.read(bidActionsProvider.notifier);

    Future<void> run(Future<String?> Function() f, String done) async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await f();
      messenger.showSnackBar(SnackBar(content: Text(err ?? done)));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        Text(
          bid.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(bid.buyer, style: TextStyle(color: muted)),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(BidWorkflow.stageLabel(bid.stage))),
            VerdictChip(verdict: bid.verdict),
            Text(deadlineLabel(bid.deadline, DateTime.now())),
          ],
        ),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            // A tender scanned on the other phone is fetched first.
            onPressed: () async {
              await actions.loadTender(bid);
              if (!context.mounted) return;
              await context.push(Routes.tender(bid.tenderId));
            },
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open tender'),
          ),
        ),
        const Divider(height: Space.xxl),
        _ApprovalSection(bid: bid, isOwner: isOwner, run: run),
        if (BidWorkflow.nextStages(bid).isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Move to', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final s in BidWorkflow.nextStages(bid))
                FilledButton.tonal(
                  onPressed: () async {
                    if (s == BidStage.lost) {
                      final reasons = await showDialog<List<String>>(
                        context: context,
                        builder: (_) => const _LossDialog(),
                      );
                      if (reasons == null) return;
                      await run(
                        () => actions.move(bid, s, reasons: reasons),
                        'Marked as lost.',
                      );
                    } else {
                      await run(
                        () => actions.move(bid, s),
                        'Moved to ${BidWorkflow.stageLabel(s)}.',
                      );
                    }
                  },
                  child: Text(BidWorkflow.stageLabel(s)),
                ),
            ],
          ),
        ],
        if (bid.lossReasons.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Why it was lost', style: theme.textTheme.titleMedium),
          for (final r in bid.lossReasons) Text('• $r'),
        ],
        if (bid.tasks.isNotEmpty || bid.stage == BidStage.preparing) ...[
          const Divider(height: Space.xxl),
          Text(
            'Checklist · ${bid.tasksDone}/${bid.tasks.length} done',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          for (final t in bid.tasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: t.done,
              title: Text(
                t.title,
                style: t.done
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: muted,
                      )
                    : null,
              ),
              onChanged: (_) => actions.toggleTask(bid, t.id),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
              onPressed: () async {
                final title = await _askTask(context);
                if (title != null) await actions.addTask(bid, title);
              },
            ),
          ),
        ],
        if (isOwner) ...[
          const Divider(height: Space.xxl),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove from pipeline'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Remove this bid?'),
                    content: const Text(
                      'Its tasks are deleted. Approval records are kept.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok ?? false) {
                  await run(() => actions.remove(bid), 'Removed.');
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  static Future<String?> _askTask(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Task'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(c.dispose);
  }
}

class _ApprovalSection extends ConsumerWidget {
  const _ApprovalSection({
    required this.bid,
    required this.isOwner,
    required this.run,
  });

  final Bid bid;
  final bool isOwner;
  final Future<void> Function(Future<String?> Function(), String) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = ref.read(bidActionsProvider.notifier);
    final (icon, text) = switch (bid.approval) {
      ApprovalState.none => (
        Icons.flag_outlined,
        'Not yet approved. The owner must approve before preparing.',
      ),
      ApprovalState.pending => (
        Icons.hourglass_top,
        'Waiting for the owner to approve.',
      ),
      ApprovalState.approved => (Icons.verified_outlined, 'Approved.'),
      ApprovalState.rejected => (Icons.block, 'Rejected by the owner.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Approval', style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Icon(icon, size: IconSizes.sm),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text)),
          ],
        ),
        if (bid.approvalNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'Note: ${bid.approvalNote}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: Space.md),
        if (BidWorkflow.canDecide(bid, isOwner ? UserRole.owner : null))
          FilledButton.icon(
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Decide'),
            onPressed: () => showApprovalDialog(context, ref, bid),
          )
        else if (!isOwner && BidWorkflow.canRequestApproval(bid))
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Ask the owner to approve'),
            onPressed: () => run(
              () => actions.requestApproval(bid),
              'Sent to the owner for approval.',
            ),
          ),
      ],
    );
  }
}

class _LossDialog extends StatefulWidget {
  const _LossDialog();

  @override
  State<_LossDialog> createState() => _LossDialogState();
}

class _LossDialogState extends State<_LossDialog> {
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Why was it lost?'),
    content: Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final r in BidWorkflow.lossReasons)
          FilterChip(
            label: Text(r),
            selected: _picked.contains(r),
            onSelected: (v) =>
                setState(() => v ? _picked.add(r) : _picked.remove(r)),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _picked.isEmpty
            ? null
            : () => Navigator.pop(context, _picked.toList()),
        child: const Text('Mark lost'),
      ),
    ],
  );
}
