import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 7: the owner approves or rejects bid decisions with a note.
/// Owner: Sewmin. Built in Phase 3.
class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'Nothing to approve',
        message:
            'When a bid manager proposes a bid, it waits here for the '
            "owner's decision.",
      ),
    );
  }
}
