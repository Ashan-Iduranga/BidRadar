import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../auth/auth_providers.dart';

/// Two-letter initials from an email's local part ("nadee.perera@x" → "NP").
String initialsFor(String? email) {
  final local = (email ?? '').split('@').first.trim();
  if (local.isEmpty) return 'B';
  final parts = local
      .split(RegExp(r'[._\-+\d]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return local.substring(0, local.length >= 2 ? 2 : 1).toUpperCase();
}

/// The signed-in user's initials in an orange circle. Used at the top right
/// of every page; opens Profile.
class AvatarButton extends ConsumerWidget {
  const AvatarButton({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateProvider).value?.email;
    return Tooltip(
      message: 'Open your profile',
      child: Semantics(
        button: true,
        label: 'Open your profile',
        excludeSemantics: true,
        child: Pressable(
          child: SizedBox.square(
            dimension: kMinTouchTarget,
            child: Center(
              child: Avatar(initials: initialsFor(email), size: size),
            ),
          ),
        ),
      ),
    ).withTap(() {
      HapticFeedback.selectionClick();
      context.push(Routes.account);
    });
  }
}

extension on Widget {
  Widget withTap(VoidCallback onTap) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: this,
    ),
  );
}

/// A plain initials avatar (no tap). [ring] draws a contrasting border.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.ring = true,
  });

  final String initials;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: b.action,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: b.surface, width: size / 15) : null,
        boxShadow: b.cardShadow,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: kFontFamily,
          fontWeight: FontWeight.w800,
          fontSize: size * .36,
          letterSpacing: -.3,
          color: b.onAction,
          // Material ancestors are optional here (Hero flight).
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// Round white icon button with a soft shadow (back, share, sync).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Shows a small spinner instead of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    return Pressable(
      child: Container(
        width: kMinTouchTarget,
        height: kMinTouchTarget,
        decoration: BoxDecoration(
          color: b.surface,
          shape: BoxShape.circle,
          boxShadow: b.cardShadow,
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: busy ? null : onPressed,
          color: b.ink,
          disabledColor: b.ink2,
          icon: busy
              ? SizedBox.square(
                  dimension: IconSizes.sm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: b.ink,
                  ),
                )
              : Icon(icon, size: 22),
        ),
      ),
    );
  }
}

/// The app bar used on every page: big bold title (optionally a small line
/// above it), round action buttons, and the avatar at the top right.
///
/// Top-level tabs pass [large] for the greeting-sized header; pushed pages
/// get a round back button automatically.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
    this.showAvatar = true,
    this.large = false,
    this.bottom,
  });

  final String title;

  /// Small line above the title ("Good morning", "Updated 5 min ago").
  final String? overline;
  final List<Widget> actions;
  final bool showAvatar;
  final bool large;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight((large ? 84 : 68) + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final theme = Theme.of(context);
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context);
    return AppBar(
      toolbarHeight: large ? 84 : 68,
      automaticallyImplyLeading: false,
      titleSpacing: canPop ? 4 : Space.gutter,
      leadingWidth: canPop ? 68 : null,
      leading: canPop
          ? Padding(
              padding: const EdgeInsets.only(left: Space.gutter - 4),
              child: Center(
                child: CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overline != null)
            Text(
              overline!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: b.ink2,
                fontWeight: FontWeight.w600,
              ),
            ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (large
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleLarge)
                    ?.copyWith(color: b.ink),
          ),
        ],
      ),
      actions: [
        for (final a in actions) ...[a, const SizedBox(width: Space.sm)],
        if (showAvatar) const AvatarButton(),
        const SizedBox(width: Space.gutter - 4),
      ],
      bottom: bottom,
    );
  }
}
