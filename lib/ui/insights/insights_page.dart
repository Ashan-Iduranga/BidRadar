import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/insights/insights.dart';
import '../../domain/insights/profile_advisor.dart';
import '../pipeline/pipeline_view_model.dart';
import '../session/session_providers.dart';
import '../widgets/state_views.dart';
import 'insights_view_model.dart';

/// Page 8: outcomes, why bids were lost, how often the AI agreed with the
/// outcome, where the firm fits best, and AI profile suggestions the owner
/// can accept. Owner: Sewmin.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadError = ref.watch(bidsProvider).error;
    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: ErrorState(
          message: 'Could not load bids: $loadError',
          onRetry: () => ref.invalidate(bidsProvider),
        ),
      );
    }
    final s = ref.watch(insightsProvider);
    final isOwner = ref.watch(currentRoleProvider) == UserRole.owner;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: s.judged == 0 && s.decided == 0 && s.open == 0
          ? const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No results yet',
              message:
                  'Insights appear once tenders are judged and bids have '
                  'outcomes. Mark bids as won or lost in the pipeline.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                _StatRow(stats: s),
                if (s.judged > 0) ...[
                  const _Heading(
                    'AI verdicts',
                    'Every tender the bid agent has judged.',
                  ),
                  _VerdictMix(mix: s.verdictMix, total: s.judged),
                ],
                if (s.fitBands.any((b) => b > 0)) ...[
                  const _Heading(
                    'Fit scores',
                    'How well judged tenders match your profile.',
                  ),
                  _FitChart(bands: s.fitBands),
                ],
                const _Heading(
                  'Why bids were lost',
                  'Reasons recorded when bids were marked lost.',
                ),
                if (s.lossReasons.isEmpty)
                  const _Muted('No lost bids yet.')
                else
                  _RankedBars(items: s.lossReasons, unit: _Unit.count),
                if (s.topBuyers.isNotEmpty) ...[
                  const _Heading(
                    'Best-fitting buyers',
                    'Average AI fit score of their tenders.',
                  ),
                  _RankedBars(items: s.topBuyers, unit: _Unit.fit),
                ],
                if (s.topSectors.isNotEmpty) ...[
                  const _Heading(
                    'Best-fitting sectors',
                    'Average AI fit score by CPV division.',
                  ),
                  _RankedBars(items: s.topSectors, unit: _Unit.fit),
                ],
                if (s.lost > 0) _Advisor(isOwner: isOwner),
              ],
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});
  final InsightsStats stats;

  @override
  Widget build(BuildContext context) {
    String pct(double? v) => v == null ? '–' : '${(v * 100).round()}%';
    return Row(
      children: [
        Expanded(
          child: _Stat(
            value: pct(stats.winRate),
            label: 'Win rate',
            detail: stats.decided == 0
                ? 'No outcomes yet'
                : '${stats.won} won of ${stats.decided}',
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: _Stat(
            value: '${stats.open}',
            label: 'Open bids',
            detail: 'In the pipeline',
          ),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: _Stat(
            value: pct(stats.agreement),
            label: 'AI agreed',
            detail: stats.judgedDecided == 0
                ? 'Needs outcomes'
                : '${stats.agreed} of ${stats.judgedDecided} outcomes',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.detail});
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: Space.xs),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              detail,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A segmented bar in the status colours, always with an icon, a label and
/// a count, so colour is never the only cue.
class _VerdictMix extends StatelessWidget {
  const _VerdictMix({required this.mix, required this.total});
  final Map<VerdictKind, int> mix;
  final int total;

  @override
  Widget build(BuildContext context) {
    // Validated data-mark colours, not the pale chip backgrounds.
    final c = context.statusColors;
    final parts = [
      (VerdictKind.bid, 'Bid', Icons.check_circle_outline, c.bidMark),
      (VerdictKind.review, 'Review', Icons.rate_review_outlined, c.reviewMark),
      (VerdictKind.noBid, 'No bid', Icons.block, c.noBidMark),
    ];
    final surface = Theme.of(context).colorScheme.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: parts.map((p) => '${p.$2} ${mix[p.$1]}').join(', '),
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  for (final (kind, _, _, color) in parts)
                    if ((mix[kind] ?? 0) > 0)
                      Expanded(
                        flex: mix[kind]!,
                        child: Container(
                          // 2px surface gap between segments.
                          decoration: BoxDecoration(
                            color: color,
                            border: Border(
                              right: BorderSide(color: surface, width: 2),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.xs,
          children: [
            for (final (kind, label, icon, color) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: Space.xs),
                  Text('$label ${mix[kind]}'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Single-series bar chart (fl_chart): one hue, no legend; counts shown on
/// touch and in the axis.
class _FitChart extends StatelessWidget {
  const _FitChart({required this.bands});
  final List<int> bands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxY = (bands.reduce((a, b) => a > b ? a : b) + 1).toDouble();
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      label: [
        for (var i = 0; i < bands.length; i++)
          'fit ${InsightsStats.bandLabels[i]}: ${bands[i]}',
      ].join(', '),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY > 5 ? (maxY / 4).ceilToDouble() : 1,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: maxY > 5 ? (maxY / 4).ceilToDouble() : 1,
                  getTitlesWidget: (v, _) =>
                      Text(v.toInt().toString(), style: axisStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      InsightsStats.bandLabels[v.toInt()],
                      style: axisStyle,
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItem: (g, _, rod, _) => BarTooltipItem(
                  'Fit ${InsightsStats.bandLabels[g.x]}: '
                  '${rod.toY.toInt()} tenders',
                  TextStyle(color: scheme.onInverseSurface),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < bands.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: bands[i].toDouble(),
                      color: scheme.primary,
                      width: 28,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Unit { count, fit }

/// Ranked rows: label, a thin bar, the value as text. Works as the table
/// view of the data and needs no legend.
class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.items, required this.unit});
  final List<Ranked> items;
  final _Unit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = unit == _Unit.fit
        ? 100.0
        : items.map((i) => i.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(
                      unit == _Unit.fit
                          ? '${i.value.round()} · ${i.count} '
                                'tender${i.count == 1 ? '' : 's'}'
                          : '${i.count}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (i.value / max).clamp(0, 1),
                    minHeight: 8,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Advisor extends ConsumerWidget {
  const _Advisor({required this.isOwner});
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(advisorViewModelProvider);
    final vm = ref.read(advisorViewModelProvider.notifier);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading(
          'Profile suggestions',
          'The AI reads your lost bids and suggests profile changes. '
              'Nothing changes unless the owner accepts it.',
        ),
        if (s.loading)
          const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!s.asked || s.suggestions.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.error != null) _Muted(s.error!),
              if (s.asked && s.error == null) const _Muted('No suggestions.'),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(s.asked ? 'Ask again' : 'Suggest profile changes'),
                onPressed: vm.suggest,
              ),
            ],
          ),
        for (final sug in s.suggestions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(sug), style: theme.textTheme.titleSmall),
                  const SizedBox(height: Space.xs),
                  Text(sug.reason),
                  const SizedBox(height: Space.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => vm.dismiss(sug),
                        child: const Text('Dismiss'),
                      ),
                      if (isOwner && sug.applicable) ...[
                        const SizedBox(width: Space.sm),
                        FilledButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final err = await vm.accept(sug);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(err ?? 'Profile updated.'),
                              ),
                            );
                          },
                          child: const Text('Accept'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (!isOwner && s.suggestions.isNotEmpty)
          const _Muted('Only the owner can accept suggestions.'),
      ],
    );
  }

  static String _title(ProfileSuggestion s) => switch (s.kind) {
    SuggestionKind.addSector =>
      'Add sector ${s.value} (${InsightsStats.sectorName(s.value.length >= 2 ? s.value.substring(0, 2) : s.value)})',
    SuggestionKind.addCountry => 'Add country ${s.value}',
    SuggestionKind.addCertification => 'Get certified: ${s.value}',
    SuggestionKind.other => s.value,
  };
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.help);
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            help,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
