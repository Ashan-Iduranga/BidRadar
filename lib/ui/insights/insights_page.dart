import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 8: win and loss reasons, verdict accuracy, best buyers and sectors.
/// Owner: Sewmin. Built in Phase 3.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No results yet',
        message:
            'Mark bids as won or lost in the pipeline. Insights then '
            'shows which buyers and sectors fit you best.',
      ),
    );
  }
}
