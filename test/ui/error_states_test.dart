import 'package:bidradar/core/theme/app_theme.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/ui/approvals/approvals_page.dart';
import 'package:bidradar/ui/deadlines/deadlines_page.dart';
import 'package:bidradar/ui/feed/feed_view_model.dart';
import 'package:bidradar/ui/insights/insights_page.dart';
import 'package:bidradar/ui/pipeline/pipeline_page.dart';
import 'package:bidradar/ui/pipeline/pipeline_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// When bids cannot load (offline, permission), pages say so and offer a
/// retry instead of pretending there is no data.
void main() {
  for (final (name, page) in [
    ('Pipeline', const PipelinePage()),
    ('Deadlines', const DeadlinesPage()),
    ('Approvals', const ApprovalsPage()),
    ('Insights', const InsightsPage()),
  ]) {
    testWidgets('$name shows an error with a retry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedTendersProvider.overrideWith((ref) => Stream.value([])),
            bidsProvider.overrideWith(
              (ref) => Stream<List<Bid>>.error(Exception('permission-denied')),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: page),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Could not load bids'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  }
}
