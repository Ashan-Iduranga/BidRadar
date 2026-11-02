import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 6: calendar and reminders 7, 3 and 1 days before closing.
/// Owner: Dinuja. Built in Phase 3.
class DeadlinesPage extends StatelessWidget {
  const DeadlinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deadlines')),
      body: const EmptyState(
        icon: Icons.event_outlined,
        title: 'No upcoming deadlines',
        message:
            'Deadlines appear here when you watch a tender. You get '
            'reminders 7, 3 and 1 days before each one closes.',
      ),
    );
  }
}
