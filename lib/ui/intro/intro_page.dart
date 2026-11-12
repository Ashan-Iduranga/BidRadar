import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/status_colors.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/enums.dart';
import '../settings/settings_providers.dart';
import '../widgets/verdict_chip.dart';

/// The 3-step animated intro shown before sign-in on first launch, and from
/// Profile › Replay the intro. Motion spec: the "Intro" artboard of the
/// BidRadar redesign canvas (direction A).
class IntroPage extends ConsumerStatefulWidget {
  const IntroPage({super.key, this.replay = false});

  /// Opened from Profile: finishing pops back instead of marking the intro
  /// as seen.
  final bool replay;

  @override
  ConsumerState<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends ConsumerState<IntroPage>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    (
      'Find tenders you can win',
      'BidRadar checks EU TED and World Bank notices every 6 hours and keeps '
          'the ones that fit your company.',
    ),
    (
      'Know before you bid',
      'The AI reads each notice, quotes the exact requirements and gives a '
          'fit score you can check.',
    ),
    (
      'Never miss a deadline',
      'Move bids from watching to won with owner approval, and get reminders '
          '7, 3 and 1 days before.',
    ),
  ];

  final _pages = PageController();
  final _nextKey = GlobalKey();
  final _stackKey = GlobalKey();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: Motion.extraLong,
  );
  Offset? _revealCenter;
  int _page = 0;

  bool get _last => _page == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _go(int page) => reduceMotion(context)
      ? _pages.jumpToPage(page)
      : _pages.animateToPage(
          page,
          duration: Motion.long,
          curve: Motion.emphasized,
        );

  Future<void> _finish() async {
    if (_reveal.isAnimating || _reveal.isCompleted) return;
    unawaited(HapticFeedback.mediumImpact());
    if (!reduceMotion(context)) {
      final button = _nextKey.currentContext?.findRenderObject() as RenderBox?;
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      if (button != null && stack != null) {
        _revealCenter = stack.globalToLocal(
          button.localToGlobal(button.size.center(Offset.zero)),
        );
      }
      await _reveal.forward();
    }
    if (!mounted) return;
    if (widget.replay) {
      context.pop();
      return;
    }
    // The router sees the flag and moves on to sign-in.
    await ref.read(settingsProvider.notifier).markIntroSeen();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return GradientBackground(
      child: Scaffold(
        body: Stack(
          key: _stackKey,
          children: [
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(foregroundColor: b.ink2),
                        child: Text(widget.replay ? 'Close' : 'Skip'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => _Slide(
                        key: ValueKey('slide-$i-${i == _page}'),
                        index: i,
                        title: _slides[i].$1,
                        body: _slides[i].$2,
                        active: i == _page,
                      ),
                    ),
                  ),
                  _Dots(count: _slides.length, index: _page),
                  const SizedBox(height: Space.xl),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 24, 24),
                    child: Row(
                      children: [
                        if (_page > 0)
                          TextButton(
                            onPressed: () => _go(_page - 1),
                            style: TextButton.styleFrom(
                              foregroundColor: b.ink2,
                            ),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        _NextButton(
                          key: _nextKey,
                          last: _last,
                          onPressed: _last ? _finish : () => _go(_page + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Circle reveal from the button, in the action colour.
            AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => _reveal.value == 0
                  ? const SizedBox.shrink()
                  : Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _RevealPainter(
                            center: _revealCenter,
                            progress: Motion.emphasizedAccelerate.transform(
                              _reveal.value,
                            ),
                            color: b.action,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    super.key,
    required this.index,
    required this.title,
    required this.body,
    required this.active,
  });

  final int index;
  final String title;
  final String body;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = context.brand;
    final scene = switch (index) {
      0 => const _RadarScene(),
      1 => const _VerdictScene(),
      _ => const _PipelineScene(),
    };
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: b.ink,
            height: 1.15,
          ),
        ).entrance(context, dy: .3),
        const SizedBox(height: Space.md),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: b.ink2,
            height: 1.55,
          ),
        ).entrance(context, index: 2, dy: .3),
      ],
    );
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: ExcludeSemantics(
            child: Center(
              child: FittedBox(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [const _Orbs(), scene],
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: text,
          ),
        ),
      ],
    );
  }
}

/// Small floating circles around each scene, like the reference.
class _Orbs extends StatelessWidget {
  const _Orbs();

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final still = reduceMotion(context);
    Widget orb(double l, double t, double size, Color c, int ms, double dy) {
      final dot = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
      return Positioned(
        left: l,
        top: t,
        child: still
            ? dot
            : dot
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 0,
                    end: dy,
                    duration: Duration(milliseconds: ms),
                    curve: Curves.easeInOut,
                  ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        orb(-6, 36, 22, b.action, 2500, -12),
        orb(296, 6, 12, b.accent, 3200, 10),
        orb(286, 268, 30, b.ink, 3700, -10),
        orb(30, 292, 10, b.ink2.withValues(alpha: .5), 2900, 8),
      ],
    );
  }
}

// ── Slide 1: the radar finds tenders ─────────────────────────────────────

class _RadarScene extends StatefulWidget {
  const _RadarScene();

  @override
  State<_RadarScene> createState() => _RadarSceneState();
}

class _RadarSceneState extends State<_RadarScene>
    with TickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
    value: .15,
  );
  late final _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _sweep.stop();
      _ping.stop();
    } else {
      if (!_sweep.isAnimating) _sweep.repeat();
      if (!_ping.isAnimating) _ping.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final theme = Theme.of(context);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        boxShadow: b.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: b.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'TED',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: b.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New match',
                style: theme.textTheme.labelLarge?.copyWith(color: b.ink),
              ),
              Text(
                'Fit 82 · Bid',
                style: theme.textTheme.labelMedium?.copyWith(color: b.ink2),
              ),
            ],
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RadarPainter(
              sweep: _sweep,
              ping: _ping,
              tint: b.tint,
              ring: b.ringLine,
              action: b.action,
              accent: b.accent,
              ink: b.ink,
              ink2: b.ink2,
            ),
          ),
        ),
        Positioned(
          left: 168,
          top: 4,
          child: reduceMotion(context)
              ? card
              : card
                    .animate()
                    .fadeIn(delay: 250.ms, duration: Motion.medium)
                    .scale(
                      begin: const Offset(.6, .6),
                      delay: 250.ms,
                      duration: 640.ms,
                      curve: Curves.easeOutBack,
                    ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweep,
    required this.ping,
    required this.tint,
    required this.ring,
    required this.action,
    required this.accent,
    required this.ink,
    required this.ink2,
  }) : super(repaint: Listenable.merge([sweep, ping]));

  final Animation<double> sweep;
  final Animation<double> ping;
  final Color tint;
  final Color ring;
  final Color action;
  final Color accent;
  final Color ink;
  final Color ink2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    canvas.drawCircle(c, 150, Paint()..color = tint);
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final r in [120.0, 80.0, 40.0]) {
      canvas.drawCircle(c, r, ringPaint);
    }

    // The sweep: a fading wedge whose bright edge leads the rotation.
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(sweep.value * 2 * math.pi);
    final rect = Rect.fromCircle(center: Offset.zero, radius: 120);
    canvas
      ..drawCircle(
        Offset.zero,
        120,
        Paint()
          ..shader = SweepGradient(
            colors: [
              action.withValues(alpha: 0),
              action.withValues(alpha: .55),
            ],
            stops: const [.78, 1],
          ).createShader(rect),
      )
      ..restore();

    canvas.drawCircle(c, 8, Paint()..color = ink);

    // Blips, two of them pinging.
    for (final (offset, color, radius, phase) in [
      (const Offset(97, -58), action, 7.0, 0.0),
      (const Offset(-56, 62), accent, 6.0, .33),
      (const Offset(52, 82), ink2, 5.0, -1.0),
    ]) {
      final p = c + offset;
      if (phase >= 0) {
        final t = (ping.value + phase) % 1;
        canvas.drawCircle(
          p,
          radius + t * radius * 1.8,
          Paint()..color = color.withValues(alpha: (1 - t) * .7),
        );
      }
      canvas.drawCircle(p, radius, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.tint != tint || old.ring != ring || old.action != action;
}

// ── Slide 2: the AI verdict with verified quotes ──────────────────────────

class _VerdictScene extends StatelessWidget {
  const _VerdictScene();

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final s = context.statusColors;
    final theme = Theme.of(context);
    final still = reduceMotion(context);

    Widget quote(String text, int delayMs) {
      final highlight = Container(
        decoration: BoxDecoration(
          color: b.accent.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(10),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: b.surface2,
          child: Stack(
            children: [
              Positioned.fill(
                child: still
                    ? highlight
                    : highlight.animate().scaleX(
                        begin: 0,
                        alignment: Alignment.centerLeft,
                        delay: Duration(milliseconds: delayMs),
                        duration: 800.ms,
                        curve: Motion.emphasized,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: b.ink,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? .82 : 0, end: .82),
      duration: const Duration(milliseconds: 1300),
      curve: Motion.emphasized,
      builder: (context, v, _) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 76,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: s.bidMark,
              backgroundColor: b.surface2,
            ),
          ),
          Text(
            '${(v * 100).round()}',
            style: theme.textTheme.titleLarge?.copyWith(color: b.ink),
          ),
        ],
      ),
    );

    final card = Container(
      width: 272,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: b.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ring,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const VerdictChip(verdict: VerdictKind.bid),
                    const SizedBox(height: 6),
                    Text(
                      'Fit 82 of 100',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: b.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quotes found in the notice',
            style: theme.textTheme.labelMedium?.copyWith(color: b.ink2),
          ),
          const SizedBox(height: 8),
          quote('“at least 3 years of hospital software support”', 700),
          const SizedBox(height: 6),
          quote('“ISO 27001 certificate”', 1000),
        ],
      ),
    );

    return Positioned(
      left: 24,
      top: 30,
      child: still
          ? card
          : card
                .animate()
                .fadeIn(duration: Motion.long)
                .slideX(
                  begin: .15,
                  end: 0,
                  duration: 560.ms,
                  curve: Motion.emphasizedDecelerate,
                ),
    );
  }
}

// ── Slide 3: the pipeline and a ringing deadline bell ─────────────────────

class _PipelineScene extends StatelessWidget {
  const _PipelineScene();

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final s = context.statusColors;
    final theme = Theme.of(context);
    final still = reduceMotion(context);

    Widget stageCard({
      required String stage,
      required String title,
      required Color bg,
      required Color fg,
      required Color stageColor,
      double? progress,
    }) => Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: b.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stage,
            style: theme.textTheme.labelMedium?.copyWith(color: stageColor),
          ),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: fg,
                backgroundColor: fg.withValues(alpha: .2),
              ),
            ),
          ],
        ],
      ),
    );

    Widget slideIn(Widget w, int i) => still
        ? w
        : w
              .animate()
              .fadeIn(delay: (90 * (i + 1)).ms, duration: Motion.long)
              .slideX(
                begin: .25,
                end: 0,
                delay: (90 * (i + 1)).ms,
                duration: 560.ms,
                curve: Motion.emphasizedDecelerate,
              );

    final bell = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: b.accent,
        shape: BoxShape.circle,
        boxShadow: b.cardShadow,
      ),
      child: Icon(
        Icons.notifications_none_rounded,
        size: 30,
        color: b.onAccent,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 24,
          top: 50,
          child: slideIn(
            stageCard(
              stage: 'Watching',
              title: 'School network equipment',
              bg: b.surface,
              fg: b.ink,
              stageColor: b.ink2,
            ),
            0,
          ),
        ),
        Positioned(
          left: 52,
          top: 128,
          child: slideIn(
            stageCard(
              stage: 'Preparing · 4 of 7 tasks',
              title: 'Hospital information system',
              bg: b.action,
              fg: b.onAction,
              stageColor: b.onAction,
              progress: 4 / 7,
            ),
            1,
          ),
        ),
        Positioned(
          left: 24,
          top: 226,
          child: slideIn(
            stageCard(
              stage: 'Won',
              title: 'Payments platform advice',
              bg: b.surface,
              fg: b.ink,
              stageColor: s.onBid,
            ),
            2,
          ),
        ),
        Positioned(
          left: 252,
          top: 2,
          child: still
              ? bell
              : bell
                    .animate(onPlay: (c) => c.repeat())
                    .shake(
                      delay: 600.ms,
                      duration: 1200.ms,
                      hz: 2.5,
                      rotation: .14,
                      curve: Curves.easeOut,
                    )
                    .then(delay: 1200.ms),
        ),
      ],
    );
  }
}

// ── Controls ─────────────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final off = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? b.action : off,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Round arrow button that grows into a "Get started" pill on the last step.
class _NextButton extends StatelessWidget {
  const _NextButton({super.key, required this.last, required this.onPressed});

  final bool last;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: last ? 'Get started' : 'Next',
      excludeSemantics: true,
      child: Pressable(
        haptic: true,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : Motion.long,
          curve: Motion.emphasized,
          width: last ? 184 : 64,
          height: 64,
          decoration: BoxDecoration(
            color: b.action,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: b.action.withValues(alpha: .35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: 184,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AnimatedSize(
                          duration: Motion.medium,
                          curve: Motion.emphasized,
                          child: last
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    'Get started',
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.fade,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: b.onAction,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: b.onAction),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealPainter extends CustomPainter {
  const _RevealPainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  final Offset? center;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = center ?? Offset(size.width - 56, size.height - 56);
    // Far enough to cover the farthest corner.
    final maxR = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((p) => (p - c).distance).reduce(math.max);
    canvas.drawCircle(c, maxR * progress, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.progress != progress || old.color != color;
}
