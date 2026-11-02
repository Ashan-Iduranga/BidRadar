import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import 'pipeline_view_model.dart';

/// Owner's approve/reject dialog with a note. Approving moves the bid to
/// Preparing and builds its document checklist.
Future<void> showApprovalDialog(
  BuildContext context,
  WidgetRef ref,
  Bid bid,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<(ApprovalDecision, String)>(
    context: context,
    builder: (_) => _ApprovalDialog(bid: bid),
  );
  if (result == null) return;
  final (decision, note) = result;
  final err = await ref
      .read(bidActionsProvider.notifier)
      .decide(bid, decision, note);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        err ??
            (decision == ApprovalDecision.approved
                ? 'Approved. The bid is now Preparing with a checklist.'
                : 'Rejected. The bid stays in Watching.'),
      ),
    ),
  );
}

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.bid});
  final Bid bid;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _done(ApprovalDecision d) {
    // A rejection must say why, so the team can learn from it.
    if (d == ApprovalDecision.rejected && _note.text.trim().isEmpty) {
      setState(() => _error = 'Add a note saying why.');
      return;
    }
    Navigator.pop(context, (d, _note.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Approve this bid?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.bid.title, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _note,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Note',
            helperText: 'Required when rejecting.',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      OutlinedButton(
        onPressed: () => _done(ApprovalDecision.rejected),
        child: const Text('Reject'),
      ),
      FilledButton(
        onPressed: () => _done(ApprovalDecision.approved),
        child: const Text('Approve'),
      ),
    ],
  );
}
