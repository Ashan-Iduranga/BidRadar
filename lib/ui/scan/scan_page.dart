import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 4: photograph a printed or newspaper tender. Owner: Ashan.
/// Built in Phase 3.
class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a notice')),
      body: const EmptyState(
        icon: Icons.document_scanner_outlined,
        title: 'Scan a printed tender',
        message:
            'Photograph a newspaper or printed notice. BidRadar reads '
            'it into a tender, and you confirm the buyer and deadline.',
      ),
    );
  }
}
