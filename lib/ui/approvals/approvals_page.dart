import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../pipeline/approval_dialog.dart';
import '../pipeline/pipeline_page.dart' show BidCard;
import '../pipeline/pipeline_view_model.dart';
import '../widgets/state_views.dart';

/// Page 7: the owner approves or rejects bids with a note. The route is
/// owner-only (router) and so are approval writes (Firestore rules).
/// Owner: Sewmin.
class ApprovalsPage extends ConsumerWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadError = ref.watch(bidsProvider).error;
    if (loadError != null) {
      return GradientBackground(
        child: Scaffold(
          appBar: AppBar(title: const Text('Approvals')),
          body: ErrorState(
            message: 'Could not load bids: $loadError',
            onRetry: () => ref.invalidate(bidsProvider),
          ),
        ),
      );
    }
    final pending = ref.watch(pendingApprovalsProvider);
    final history = ref.watch(approvalsProvider).value ?? const [];
    final bids = {
      for (final b in ref.watch(bidsProvider).value ?? const <Bid>[]) b.id: b,
    };
    final theme = Theme.of(context);

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Approvals')),
        body: pending.isEmpty && history.isEmpty
            ? const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'Nothing to approve',
                message:
                    'When a bid manager asks to prepare a bid, it waits here '
                    "for the owner's decision.",
              )
            : ListView(
                padding: const EdgeInsets.all(Space.gutter),
                children: [
                  Text(
                    pending.isEmpty
                        ? 'Nothing waiting'
                        : '${pending.length} waiting for you',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  for (final b in pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: BidCard(
                        bid: b,
                        trailing: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () =>
                                showApprovalDialog(context, ref, b),
                            child: const Text('Decide'),
                          ),
                        ),
                      ),
                    ),
                  if (history.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    Text('Decisions', style: theme.textTheme.titleMedium),
                    for (final a in history)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          a.decision == ApprovalDecision.approved
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                        ),
                        title: Text(
                          bids[a.bidId]?.title ?? 'Removed bid',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            a.decision == ApprovalDecision.approved
                                ? 'Approved'
                                : 'Rejected',
                            DateFormat.yMMMd().add_jm().format(a.at.toLocal()),
                            if (a.note.isNotEmpty) '"${a.note}"',
                          ].join(' · '),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
