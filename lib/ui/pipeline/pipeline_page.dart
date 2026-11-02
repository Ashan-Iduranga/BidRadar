import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 5: watching, preparing, submitted, won, lost. Owner: Sewmin.
/// Built in Phase 3.
class PipelinePage extends StatelessWidget {
  const PipelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pipeline')),
      body: const EmptyState(
        icon: Icons.view_kanban_outlined,
        title: 'No bids in progress',
        message: 'Open a tender from the feed and tap Watch to add it here.',
      ),
    );
  }
}
