import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../widgets/state_views.dart';

/// Page 1: tenders ranked by fit. Owner: Ashan. Built in Phase 2.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            tooltip: 'Approvals',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => context.push(Routes.approvals),
          ),
        ],
      ),
      body: EmptyState(
        icon: Icons.radar,
        title: 'No tenders yet',
        message:
            'Set up your company profile first. BidRadar then pulls '
            'matching tenders from EU TED and the World Bank.',
        actionLabel: 'Set up company profile',
        onAction: () => context.go(Routes.profile),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.scan),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scan notice'),
      ),
    );
  }
}
