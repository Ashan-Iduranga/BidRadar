import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 2: summary, quoted eligibility checklist, verdict and documents.
/// Owner: Hasitha. Built in Phase 2 (verdict section in Phase 3).
class TenderDetailPage extends StatelessWidget {
  const TenderDetailPage({super.key, required this.tenderId});

  final String tenderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tender')),
      body: EmptyState(
        icon: Icons.description_outlined,
        title: 'Tender not found',
        message:
            'This tender ($tenderId) is not in the local cache. '
            'Go back to the feed and sync again.',
      ),
    );
  }
}
