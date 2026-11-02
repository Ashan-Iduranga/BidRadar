import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// Page 3: sectors (CPV), countries, turnover, certifications, past contracts.
/// Owner: Dinuja. Built in Phase 1.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company')),
      body: const EmptyState(
        icon: Icons.business_outlined,
        title: 'No company profile',
        message:
            'Add your sectors, countries, yearly turnover and '
            'certificates. The rules and the bid agent use them to judge '
            'every tender.',
      ),
    );
  }
}
