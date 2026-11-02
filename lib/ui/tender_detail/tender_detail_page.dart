import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo/countries.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../widgets/fit_score_badge.dart';
import '../widgets/state_views.dart';
import '../widgets/tender_card.dart' show deadlineLabel;
import '../widgets/verdict_chip.dart';
import 'tender_detail_view_model.dart';

/// Page 2: summary, hard-rule results, notice text, documents and sharing.
/// Owner: Hasitha. The AI verdict section is filled in Phase 3.
class TenderDetailPage extends ConsumerWidget {
  const TenderDetailPage({super.key, required this.tenderId});

  final String tenderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tenderDetailProvider(tenderId));
    final tender = detail.value?.tender;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tender'),
        actions: [
          if (tender != null)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: shareText(tender), subject: tender.title),
              ),
            ),
        ],
      ),
      body: switch (detail) {
        AsyncError(:final error) => ErrorState(
          message: 'Could not read this tender: $error',
          onRetry: () => ref.invalidate(cachedTenderProvider(tenderId)),
        ),
        AsyncData(value: TenderDetail(tender: null)) => EmptyState(
          icon: Icons.description_outlined,
          title: 'Tender not found',
          message:
              'This tender is no longer cached on this device. Closed '
              'tenders are removed after each sync.',
          actionLabel: 'Back to feed',
          onAction: () => Navigator.of(context).maybePop(),
        ),
        AsyncData(:final value) => _Body(
          tender: value.tender!,
          rules: value.rules,
          verdict: value.verdict,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tender, required this.rules, this.verdict});
  final Tender tender;
  final RulesResult? rules;
  final Verdict? verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final t = tender;
    final deadline = t.deadline?.toLocal();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        Text(
          t.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          [
            t.buyer,
            if (t.country.isNotEmpty) Countries.nameOf(t.country),
          ].join(' · '),
          style: theme.textTheme.bodyLarge?.copyWith(color: muted),
        ),
        const SizedBox(height: Space.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Column(
              children: [
                _Fact(
                  icon: Icons.schedule,
                  label: 'Deadline',
                  value: deadline == null
                      ? 'Unknown. Check the notice.'
                      : '${DateFormat.yMMMEd().add_jm().format(deadline)}\n'
                            '${deadlineLabel(t.deadline, DateTime.now())}',
                ),
                _Fact(
                  icon: Icons.payments_outlined,
                  label: 'Estimated value',
                  value: t.estimatedValue == null
                      ? 'Not stated'
                      : NumberFormat.currency(
                          symbol: '${t.currency ?? ''} ',
                          decimalDigits: 0,
                        ).format(t.estimatedValue),
                ),
                _Fact(
                  icon: Icons.source_outlined,
                  label: 'Source',
                  value: switch (t.source) {
                    TenderSourceType.ted => 'EU TED · ${t.sourceId}',
                    TenderSourceType.worldBank => 'World Bank · ${t.sourceId}',
                    TenderSourceType.scan => 'Scanned notice',
                  },
                ),
                _Fact(
                  icon: Icons.category_outlined,
                  label: 'Sectors (CPV)',
                  value: t.cpvCodes.isEmpty
                      ? 'None given by this source'
                      : t.cpvCodes.join(', '),
                ),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Hard rules',
          child: _RulesView(rules: rules),
        ),
        _Section(
          title: 'AI verdict',
          child: _VerdictView(tender: t, rules: rules, verdict: verdict),
        ),
        if (t.url != null || t.documentUrls.isNotEmpty)
          _Section(
            title: 'Documents',
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                if (t.url != null)
                  FilledButton.tonalIcon(
                    onPressed: () => _open(context, t.url!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open notice'),
                  ),
                for (final (i, d) in t.documentUrls.indexed)
                  OutlinedButton.icon(
                    onPressed: () => _open(context, d),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      t.documentUrls.length == 1 ? 'PDF' : 'Document ${i + 1}',
                    ),
                  ),
              ],
            ),
          ),
        _Section(
          title: 'Notice text',
          child: _ExpandableText(text: t.noticeText),
        ),
      ],
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }
}

class _VerdictView extends ConsumerWidget {
  const _VerdictView({
    required this.tender,
    required this.rules,
    required this.verdict,
  });

  final Tender tender;
  final RulesResult? rules;
  final Verdict? verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final running = ref.watch(judgeViewModelProvider(tender.id));
    final v = verdict;
    final vetoed = rules?.passed == false;

    Future<void> judge() async {
      final messenger = ScaffoldMessenger.of(context);
      final err = await ref
          .read(judgeViewModelProvider(tender.id).notifier)
          .judge();
      if (err != null) {
        messenger.showSnackBar(SnackBar(content: Text(err)));
      }
    }

    final button = vetoed || rules == null
        ? null
        : FilledButton.tonalIcon(
            onPressed: running ? null : judge,
            icon: running
                ? const SizedBox.square(
                    dimension: IconSizes.sm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              running
                  ? 'Reading the notice…'
                  : v == null
                  ? 'Judge with AI'
                  : 'Judge again',
            ),
          );

    if (v == null || vetoed) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VerdictChip(verdict: vetoed ? VerdictKind.noBid : null),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      vetoed
                          ? 'Not sent to the AI: the hard rules removed it.'
                          : 'Not judged yet. The bid agent reads the notice '
                                'and must quote its evidence word for word.',
                    ),
                  ),
                ],
              ),
              if (button != null) ...[const SizedBox(height: Space.md), button],
            ],
          ),
        ),
      );
    }

    final verified = v.criteria.where((c) => c.quoteVerified).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VerdictChip(verdict: v.verdict),
                const SizedBox(width: Space.md),
                FitScoreBadge(score: v.fitScore),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    [
                      'Fit ${v.fitScore}/100',
                      if (v.confidence != null)
                        'confidence ${(v.confidence! * 100).round()}%',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (v.note != null) ...[
              const SizedBox(height: Space.md),
              _RuleRow(icon: Icons.info_outline, text: v.note!),
            ],
            if (v.criteria.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(
                'Evidence: $verified of ${v.criteria.length} quotes found in '
                'the notice',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Space.sm),
              for (final c in v.criteria) _CriterionTile(c),
            ],
            if (v.missingDocs.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text('Documents to prepare', style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.xs),
              for (final d in v.missingDocs)
                _RuleRow(icon: Icons.description_outlined, text: d),
            ],
            if (v.clarificationQuestion != null &&
                v.clarificationQuestion!.trim().isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text('Ask the buyer', style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.xs),
              _RuleRow(
                icon: Icons.help_outline,
                text: v.clarificationQuestion!,
              ),
            ],
            const SizedBox(height: Space.sm),
            Text(
              '${v.model} · '
              '${DateFormat.yMMMd().add_jm().format(v.at.toLocal())}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if (button != null) ...[const SizedBox(height: Space.md), button],
          ],
        ),
      ),
    );
  }
}

/// One criterion with its quote. Verified quotes get a check; unverified
/// ones are marked so nobody relies on them.
class _CriterionTile extends StatelessWidget {
  const _CriterionTile(this.c);
  final Criterion c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (metIcon, metText) = switch (c.met) {
      CriterionMet.yes => (Icons.check_circle_outline, 'Met'),
      CriterionMet.no => (Icons.cancel_outlined, 'Not met'),
      CriterionMet.unknown => (Icons.help_outline, 'Unknown'),
    };
    final quoteColor = c.quoteVerified ? muted : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metIcon, size: IconSizes.sm),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  '${c.criterion} · $metText',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: IconSizes.sm + Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${c.quote}”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      c.quoteVerified
                          ? Icons.verified_outlined
                          : Icons.report_outlined,
                      size: 14,
                      color: quoteColor,
                    ),
                    const SizedBox(width: Space.xs),
                    Text(
                      c.quoteVerified
                          ? 'Quote found in the notice'
                          : 'Quote NOT found in the notice',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: quoteColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesView extends StatelessWidget {
  const _RulesView({required this.rules});
  final RulesResult? rules;

  @override
  Widget build(BuildContext context) {
    final r = rules;
    if (r == null) {
      return const Text('Set up your company profile to check this tender.');
    }
    final theme = Theme.of(context);
    final rows = <Widget>[
      for (final v in r.vetoes)
        _RuleRow(
          icon: Icons.block,
          text: v.message,
          color: theme.colorScheme.error,
        ),
      for (final w in r.warnings) _RuleRow(icon: Icons.info_outline, text: w),
    ];
    if (r.passed && r.warnings.isEmpty) {
      rows.add(
        const _RuleRow(
          icon: Icons.check_circle_outline,
          text: 'Passes every hard rule: deadline, country, sector, turnover.',
        ),
      );
    } else if (r.passed) {
      rows.insert(
        0,
        const _RuleRow(
          icon: Icons.check_circle_outline,
          text: 'No rule removes it, but check these:',
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: IconSizes.sm, color: c),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.md),
        child,
      ],
    ),
  );
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;
  static const _lines = 8;

  @override
  Widget build(BuildContext context) {
    final long =
        '\n'.allMatches(widget.text).length >= _lines ||
        widget.text.length > 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          widget.text,
          maxLines: _open || !long ? null : _lines,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? 'Show less' : 'Show full notice'),
          ),
      ],
    );
  }
}
