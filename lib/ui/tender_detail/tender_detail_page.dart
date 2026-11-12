import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo/countries.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../domain/pipeline/bid_workflow.dart';
import '../pipeline/pipeline_view_model.dart';
import '../widgets/app_header.dart';
import '../widgets/fit_score_badge.dart';
import '../widgets/skeletons.dart';
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
    return GradientBackground(
      child: Scaffold(
        appBar: BrandAppBar(
          title: 'Tender',
          actions: [
            if (tender != null)
              CircleIconButton(
                tooltip: 'Share',
                icon: Icons.ios_share_rounded,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: shareText(tender), subject: tender.title),
                ),
              ),
          ],
        ),
        body: switch (detail) {
          AsyncValue(:final error?) when !detail.hasValue => ErrorState(
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
          _ => const DetailSkeleton(),
        },
      ),
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
    final b = context.brand;
    final t = tender;
    final deadline = t.deadline?.toLocal();
    final vetoed = rules?.passed == false;
    var i = 0;
    Widget step(Widget w) => w.entrance(context, index: i++);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xs,
        Space.gutter,
        Space.xxxl,
      ),
      children: [
        step(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: b.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                [
                  t.buyer,
                  if (t.country.isNotEmpty) Countries.nameOf(t.country),
                ].join(' · '),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: b.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        step(_VerdictHero(tender: t, rules: rules, verdict: verdict)),
        const SizedBox(height: Space.md),
        step(
          _FactGrid(
            facts: [
              (
                Icons.schedule_rounded,
                'Deadline',
                deadline == null
                    ? 'Unknown. Check the notice.'
                    : DateFormat.yMMMEd().add_jm().format(deadline),
                deadline == null
                    ? null
                    : deadlineLabel(t.deadline, DateTime.now()),
              ),
              (
                Icons.payments_outlined,
                'Estimated value',
                t.estimatedValue == null
                    ? 'Not stated'
                    : NumberFormat.currency(
                        symbol: '${t.currency ?? ''} ',
                        decimalDigits: 0,
                      ).format(t.estimatedValue),
                null,
              ),
              (
                Icons.public_rounded,
                'Source',
                switch (t.source) {
                  TenderSourceType.ted => 'EU TED · ${t.sourceId}',
                  TenderSourceType.worldBank => 'World Bank · ${t.sourceId}',
                  TenderSourceType.scan => 'Scanned notice',
                },
                null,
              ),
              (
                Icons.category_outlined,
                'Sectors (CPV)',
                t.cpvCodes.isEmpty
                    ? 'None given by this source'
                    : t.cpvCodes.join(', '),
                null,
              ),
            ],
          ),
        ),
        step(
          _Section(
            title: 'Hard rules',
            child: _CardBox(child: _RulesView(rules: rules)),
          ),
        ),
        if (verdict != null && !vetoed)
          step(
            _Section(
              title: 'Evidence from the notice',
              child: _CardBox(child: _VerdictDetails(verdict: verdict!)),
            ),
          ),
        step(
          _Section(
            title: 'Pipeline',
            child: _PipelineSection(tender: t, verdict: verdict),
          ),
        ),
        if (t.url != null || t.documentUrls.isNotEmpty)
          step(
            _Section(
              title: 'Documents',
              child: Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  if (t.url != null)
                    OutlinedButton.icon(
                      onPressed: () => _open(context, t.url!),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open notice'),
                    ),
                  for (final (i, d) in t.documentUrls.indexed)
                    OutlinedButton.icon(
                      onPressed: () => _open(context, d),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        t.documentUrls.length == 1
                            ? 'PDF'
                            : 'Document ${i + 1}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        _Section(
          title: 'Notice text',
          child: _CardBox(child: _ExpandableText(text: t.noticeText)),
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

/// The black hero card: the AI's verdict with a big fit ring, or why there
/// is none yet, plus the "Judge with AI" action.
class _VerdictHero extends ConsumerWidget {
  const _VerdictHero({
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
    final b = context.brand;
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
        : Pressable(
            haptic: true,
            child: FilledButton.icon(
              onPressed: running ? null : judge,
              icon: running
                  ? SizedBox.square(
                      dimension: IconSizes.sm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: b.onAction,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                running
                    ? 'Reading the notice…'
                    : v == null
                    ? 'Judge with AI'
                    : 'Judge again',
              ),
            ),
          );

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: b.heroMuted,
      height: 1.4,
    );

    final Widget content;
    if (v == null || vetoed) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI verdict',
            style: theme.textTheme.labelLarge?.copyWith(color: b.heroMuted),
          ),
          const SizedBox(height: Space.sm),
          VerdictChip(verdict: vetoed ? VerdictKind.noBid : null),
          const SizedBox(height: Space.md),
          Text(
            vetoed
                ? 'Not sent to the AI: the hard rules removed it.'
                : 'Not judged yet. The bid agent reads the notice and must '
                      'quote its evidence word for word.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: b.onHero,
              height: 1.4,
            ),
          ),
          if (button != null) ...[const SizedBox(height: Space.lg), button],
        ],
      );
    } else {
      final verified = v.criteria.where((c) => c.quoteVerified).length;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FitScoreBadge(
                score: v.fitScore,
                size: 108,
                stroke: 11,
                track: b.heroTrack,
                textColor: b.onHero,
                label: 'fit',
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VerdictChip(verdict: v.verdict),
                    const SizedBox(height: Space.sm),
                    Text(
                      [
                        'Fit ${v.fitScore}/100',
                        if (v.confidence != null)
                          'confidence ${(v.confidence! * 100).round()}%',
                      ].join(' · '),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: b.onHero,
                      ),
                    ),
                    if (v.criteria.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: b.heroMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$verified of ${v.criteria.length} quotes found',
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (v.note != null) ...[
            const SizedBox(height: Space.md),
            Text(v.note!, style: muted),
          ],
          const SizedBox(height: Space.md),
          Text(
            '${v.model} · '
            '${DateFormat.yMMMd().add_jm().format(v.at.toLocal())}',
            style: theme.textTheme.bodySmall?.copyWith(color: b.heroMuted),
          ),
          if (button != null) ...[const SizedBox(height: Space.lg), button],
        ],
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: b.hero,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -40,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(150),
                painter: _CornerArcs(b.heroAccent),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: content),
        ],
      ),
    );
  }
}

class _CornerArcs extends CustomPainter {
  const _CornerArcs(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * .2, size.height * .87);
    for (final (r, a) in [(100.0, .28), (60.0, .55)]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -1.5708,
        1.5708,
        false,
        Paint()
          ..color = color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CornerArcs old) => old.color != color;
}

/// Evidence, documents to prepare and the question for the buyer.
class _VerdictDetails extends StatelessWidget {
  const _VerdictDetails({required this.verdict});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = verdict;
    final verified = v.criteria.where((c) => c.quoteVerified).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (v.criteria.isEmpty)
          const _RuleRow(
            icon: Icons.info_outline_rounded,
            text: 'The AI quoted no criteria for this notice.',
          )
        else ...[
          Text(
            'Evidence: $verified of ${v.criteria.length} quotes found in '
            'the notice',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Space.md),
          for (final c in v.criteria) _CriterionTile(c),
        ],
        if (v.missingDocs.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text('Documents to prepare', style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          for (final d in v.missingDocs)
            _RuleRow(icon: Icons.description_outlined, text: d),
        ],
        if (v.clarificationQuestion != null &&
            v.clarificationQuestion!.trim().isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Text('Ask the buyer', style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          _RuleRow(
            icon: Icons.help_outline_rounded,
            text: v.clarificationQuestion!,
          ),
        ],
      ],
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
    final b = context.brand;
    final s = context.statusColors;
    final (metIcon, metText, metBg, metFg) = switch (c.met) {
      CriterionMet.yes => (Icons.check_rounded, 'Met', s.bid, s.onBid),
      CriterionMet.no => (Icons.close_rounded, 'Not met', s.noBid, s.onNoBid),
      CriterionMet.unknown => (
        Icons.question_mark_rounded,
        'Unknown',
        s.neutral,
        s.onNeutral,
      ),
    };
    final quoteColor = c.quoteVerified ? s.onBid : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.criterion,
                  style: theme.textTheme.titleSmall?.copyWith(color: b.ink),
                ),
              ),
              const SizedBox(width: Space.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: metBg,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(metIcon, size: 13, color: metFg),
                    const SizedBox(width: 3),
                    Text(
                      metText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: metFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: b.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '“${c.quote}”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: b.ink,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                c.quoteVerified
                    ? Icons.verified_outlined
                    : Icons.report_outlined,
                size: 15,
                color: quoteColor,
              ),
              const SizedBox(width: Space.xs),
              Text(
                c.quoteVerified
                    ? 'Quote found in the notice'
                    : 'Quote NOT found in the notice',
                style: theme.textTheme.labelMedium?.copyWith(color: quoteColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PipelineSection extends ConsumerWidget {
  const _PipelineSection({required this.tender, required this.verdict});
  final Tender tender;
  final Verdict? verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.brand;
    final bid = ref.watch(bidForTenderProvider(tender.id));
    if (bid != null) {
      return _CardBox(
        child: Row(
          children: [
            Icon(Icons.view_kanban_outlined, size: IconSizes.md, color: b.ink),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                'In the pipeline: ${BidWorkflow.stageLabel(bid.stage)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: b.actionInk),
              onPressed: () => context.push(Routes.bid(bid.id)),
              child: const Text('Open bid'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: Pressable(
        haptic: true,
        child: FilledButton.icon(
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Watch this tender'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final err = await ref
                .read(bidActionsProvider.notifier)
                .watch(tender, verdict);
            messenger.showSnackBar(
              SnackBar(
                content: Text(err ?? 'Added to the pipeline (Watching).'),
              ),
            );
          },
        ),
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
    final ok = context.statusColors.bidMark;
    final rows = <Widget>[
      for (final v in r.vetoes)
        _RuleRow(
          icon: Icons.block_rounded,
          text: v.message,
          color: theme.colorScheme.error,
        ),
      for (final w in r.warnings)
        _RuleRow(
          icon: Icons.info_outline_rounded,
          text: w,
          color: context.statusColors.reviewMark,
        ),
    ];
    if (r.passed && r.warnings.isEmpty) {
      rows.add(
        _RuleRow(
          icon: Icons.check_circle_outline_rounded,
          text: 'Passes every hard rule: deadline, country, sector, turnover.',
          color: ok,
        ),
      );
    } else if (r.passed) {
      rows.insert(
        0,
        _RuleRow(
          icon: Icons.check_circle_outline_rounded,
          text: 'No rule removes it, but check these:',
          color: ok,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2-column grid of small fact cards.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.facts});

  final List<(IconData, String, String, String?)> facts;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final theme = Theme.of(context);
    Widget card((IconData, String, String, String?) f) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md - 4),
        boxShadow: b.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(f.$1, size: 16, color: b.ink2),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  f.$2,
                  style: theme.textTheme.labelMedium?.copyWith(color: b.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            f.$3,
            style: theme.textTheme.titleSmall?.copyWith(
              color: b.ink,
              height: 1.3,
            ),
          ),
          if (f.$4 != null) ...[
            const SizedBox(height: 2),
            Text(
              f.$4!,
              style: theme.textTheme.labelMedium?.copyWith(color: b.actionInk),
            ),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        final half = (c.maxWidth - Space.sm) / 2;
        return Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final f in facts)
              SizedBox(width: half < 150 ? c.maxWidth : half, child: card(f)),
          ],
        );
      },
    );
  }
}

/// White rounded card around a section's content.
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: child,
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
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
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
    return AnimatedSize(
      duration: reduceMotion(context) ? Duration.zero : Motion.medium,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.text,
            maxLines: _open || !long ? null : _lines,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.55),
          ),
          if (long)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.brand.actionInk,
              ),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Show less' : 'Show full notice'),
            ),
        ],
      ),
    );
  }
}
