import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// The icon on a warm disc with two radar rings, used by empty and error
/// states so they feel part of the app rather than a blank page.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.fill, required this.ink});

  final IconData icon;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final ring = context.brand.ringLine;
    final badge = SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final d in [132.0, 104.0])
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: 2),
              ),
            ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: ink),
          ),
        ],
      ),
    );
    return ExcludeSemantics(child: badge.entrance(context, dy: .12));
  }
}

/// Empty state that tells the user what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = context.brand;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(icon: icon, fill: b.tint, ink: b.actionInk),
            const SizedBox(height: Space.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(color: b.ink),
            ).entrance(context, index: 1),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: b.ink2,
                  height: 1.5,
                ),
              ),
            ).entrance(context, index: 2),
            if (actionLabel != null) ...[
              const SizedBox(height: Space.xl),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ).entrance(context, index: 3),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a cause and a retry path.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = context.brand;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(
              icon: Icons.error_outline_rounded,
              fill: scheme.errorContainer,
              ink: scheme.onErrorContainer,
            ),
            const SizedBox(height: Space.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(color: b.ink),
            ),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: b.ink2,
                  height: 1.5,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Space.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
