import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo/countries.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
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
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tender, required this.rules});
  final Tender tender;
  final RulesResult? rules;

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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  const VerdictChip(verdict: null),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      rules?.passed == false
                          ? 'Not sent to the AI: the hard rules removed it.'
                          : 'Not judged yet. The bid agent will read the '
                                'notice and quote its evidence.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
