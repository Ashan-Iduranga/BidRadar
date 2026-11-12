import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion tokens, following Material 3 emphasized and standard timings.
/// Every animation in the app uses these, so screens share one rhythm.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 450);
  static const extraLong = Duration(milliseconds: 600);

  /// Delay between items in a list entrance.
  static const stagger = Duration(milliseconds: 45);

  /// Lists stop staggering after this many items so long lists don't lag.
  static const maxStaggered = 8;

  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
}

/// True when the user turned animations off (Android "Remove animations").
/// Every decorative animation checks this.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

extension EntranceMotion on Widget {
  /// Fades and lifts the widget in, staggered by [index] in a list.
  /// No-op when animations are off.
  Widget entrance(BuildContext context, {int index = 0, double dy = .08}) =>
      Entrance(index: index, dy: dy, child: this);
}

/// Fade-and-rise entrance. The stagger delay is part of the controller's
/// own timeline (no timers), so it is safe in widget tests and cheap.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.dy = .08,
  });

  final Widget child;
  final int index;

  /// Start offset as a fraction of the child's height.
  final double dy;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final delay = Motion.stagger * widget.index.clamp(0, Motion.maxStaggered);
    final total = delay + Motion.long;
    _c = AnimationController(vsync: this, duration: total);
    final start = delay.inMicroseconds / total.inMicroseconds;
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: Motion.emphasizedDecelerate),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _t.value,
      child: FractionalTranslation(
        translation: Offset(0, widget.dy * (1 - _t.value)),
        child: child,
      ),
    ),
  );
}

/// Shrinks its child slightly while pressed, like the reference cards.
/// Pointer-only: it never adds semantics or swallows taps, so the child keeps
/// its own button or InkWell behaviour.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.scale = .97,
    this.haptic = false,
  });

  final Widget child;
  final double scale;

  /// Light haptic tick on press, for important actions only.
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    if (down && widget.haptic) HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.fast,
        curve: Motion.emphasized,
        child: widget.child,
      ),
    );
  }
}
