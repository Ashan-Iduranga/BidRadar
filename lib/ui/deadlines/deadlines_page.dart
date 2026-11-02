import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../pipeline/pipeline_page.dart' show BidCard;
import '../pipeline/pipeline_view_model.dart';
import '../widgets/state_views.dart';
import 'deadlines_view_model.dart';

/// Page 6: deadlines of active bids on a month calendar, with reminders
/// 7, 3 and 1 days before and a Monday digest. Owner: Dinuja.
class DeadlinesPage extends ConsumerWidget {
  const DeadlinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadError = ref.watch(bidsProvider).error;
    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deadlines')),
        body: ErrorState(
          message: 'Could not load bids: $loadError',
          onRetry: () => ref.invalidate(bidsProvider),
        ),
      );
    }
    final bids = ref.watch(deadlineBidsProvider);
    final cal = ref.watch(calendarProvider);
    final theme = Theme.of(context);
    final shown = cal.day == null
        ? bids
        : bids
              .where((b) => DateUtils.isSameDay(b.deadline!.toLocal(), cal.day))
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Deadlines')),
      body: bids.isEmpty
          ? const EmptyState(
              icon: Icons.event_outlined,
              title: 'No upcoming deadlines',
              message:
                  'Watch a tender to track its deadline. BidRadar reminds '
                  'you 7, 3 and 1 days before, and sends a digest on Mondays.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                _MonthGrid(bids: bids, state: cal),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: IconSizes.sm,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'Reminders 7, 3 and 1 days before, at 9:00. '
                        'Weekly digest on Mondays.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Text(
                  cal.day == null
                      ? 'All upcoming'
                      : DateFormat.yMMMMEEEEd().format(cal.day!),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: Space.sm),
                if (shown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Space.lg),
                    child: Text('No deadlines on this day.'),
                  ),
                for (final b in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: BidCard(bid: b),
                  ),
              ],
            ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.bids, required this.state});
  final List<Bid> bids;
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vm = ref.read(calendarProvider.notifier);
    final m = state.month;
    final first = DateTime(m.year, m.month);
    final daysInMonth = DateUtils.getDaysInMonth(m.year, m.month);
    final lead = (first.weekday - DateTime.monday) % 7;
    final today = DateTime.now();

    final counts = <int, int>{};
    for (final b in bids) {
      final d = b.deadline!.toLocal();
      if (d.year == m.year && d.month == m.month) {
        counts[d.day] = (counts[d.day] ?? 0) + 1;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => vm.shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(m),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => vm.shiftMonth(1),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    date: DateTime(m.year, m.month, day),
                    count: counts[day] ?? 0,
                    selected: DateUtils.isSameDay(
                      state.day,
                      DateTime(m.year, m.month, day),
                    ),
                    today: DateUtils.isSameDay(
                      today,
                      DateTime(m.year, m.month, day),
                    ),
                    onTap: () => vm.pick(DateTime(m.year, m.month, day)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.count,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final int count;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = DateFormat.MMMd().format(date);
    return Semantics(
      button: true,
      selected: selected,
      label: count == 0
          ? label
          : '$label, $count deadline${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : null,
            border: today && !selected
                ? Border.all(color: scheme.primary)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: selected ? scheme.onPrimary : null,
                  fontWeight: count > 0 ? FontWeight.w700 : null,
                ),
              ),
              if (count > 0)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
