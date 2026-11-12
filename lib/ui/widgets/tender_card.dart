import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/geo/countries.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import 'fit_score_badge.dart';
import 'verdict_chip.dart';

/// One tender in the Feed. Shows the verdict, fit score, buyer, deadline and
/// the first veto reason if hard rules removed it.
class TenderCard extends StatelessWidget {
  const TenderCard({
    super.key,
    required this.tender,
    this.verdict,
    this.rules,
    this.onTap,
    this.now,
  });

  final Tender tender;
  final Verdict? verdict;

  /// Hard-rule result, used before a verdict exists (Phase 1 and 2). A
  /// veto shows as "No bid" with its reason.
  final RulesResult? rules;
  final VoidCallback? onTap;

  /// Injected clock for tests; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Live rules win over the rules stored with an older verdict.
    final result = rules ?? verdict?.rulesResult;
    final veto = result?.vetoes.firstOrNull;
    final warning = veto == null
        ? (verdict?.note ?? result?.warnings.firstOrNull)
        : null;
    // Without an AI verdict, the rules decide the chip: a veto is NO_BID,
    // a pass with unchecked facts is REVIEW (always with icon and text).
    final kind = veto != null
        ? VerdictKind.noBid
        : verdict?.verdict ??
              (veto != null
                  ? VerdictKind.noBid
                  : warning != null
                  ? VerdictKind.review
                  : null);

    final b = context.brand;
    return Pressable(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: b.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: b.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SourceTile(source: tender.source),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tender.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: b.ink,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tender.country.isEmpty
                                  ? tender.buyer
                                  : '${tender.buyer} · '
                                        '${Countries.nameOf(tender.country)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kFitScoreGap),
                      FitScoreBadge(score: verdict?.fitScore),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.md,
                    runSpacing: Space.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VerdictChip(verdict: kind, dense: true),
                      _Meta(
                        icon: Icons.schedule_rounded,
                        text: deadlineLabel(
                          tender.deadline,
                          now ?? DateTime.now(),
                        ),
                      ),
                      _Meta(icon: Icons.public_rounded, text: _sourceLabel),
                    ],
                  ),
                  if (veto == null && warning != null) ...[
                    const SizedBox(height: Space.sm),
                    _Note(icon: Icons.info_outline_rounded, text: warning),
                  ],
                  if (veto != null) ...[
                    const SizedBox(height: Space.sm),
                    _Note(icon: Icons.block_rounded, text: veto.message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _sourceLabel => switch (tender.source) {
    TenderSourceType.ted => 'EU TED',
    TenderSourceType.worldBank => 'World Bank',
    TenderSourceType.scan => 'Scanned',
  };
}

/// Rounded tile with the source's short name, like the reference list icons.
class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final TenderSourceType source;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: b.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: source == TenderSourceType.scan
            ? Icon(Icons.document_scanner_outlined, size: 20, color: b.ink)
            : Text(
                source == TenderSourceType.ted ? 'TED' : 'WB',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: b.ink, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}

/// "Closes in 5 days", "Closes today", "Closed", or "Deadline unknown".
String deadlineLabel(DateTime? deadline, DateTime now) {
  if (deadline == null) return 'Deadline unknown';
  final local = deadline.toLocal();
  final days = DateUtils.dateOnly(local)
      .difference(DateUtils.dateOnly(now))
      .inDays;
  if (local.isBefore(now)) return 'Closed';
  if (days == 0) return 'Closes today';
  if (days == 1) return 'Closes tomorrow';
  if (days <= 14) return 'Closes in $days days';
  return 'Closes ${DateFormat.yMMMd().format(local)}';
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: Space.xs),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
