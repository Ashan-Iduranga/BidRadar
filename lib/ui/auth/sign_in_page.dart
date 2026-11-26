import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../widgets/brand_mark.dart';
import 'auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _creating = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final vm = ref.read(signInViewModelProvider.notifier);
    final email = _email.text.trim();
    _creating
        ? vm.signUp(email, _password.text)
        : vm.signIn(email, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInViewModelProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = state.isLoading;

    return GradientBackground(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(creating: _creating),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xl,
                      Space.xl,
                      Space.xl,
                      Space.xxl,
                    ),
                    child: Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_creating) ...[
                              const _StepBar(),
                              const SizedBox(height: Space.xl),
                            ],
                            TextFormField(
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter your work email.'
                                  : null,
                            ),
                            const SizedBox(height: Space.lg),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: [
                                _creating
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                helperText: _creating
                                    ? 'At least 6 characters.'
                                    : null,
                                suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Use at least 6 characters.'
                                  : null,
                            ),
                            if (state.hasError) ...[
                              const SizedBox(height: Space.lg),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: IconSizes.sm,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Text(
                                      state.error.toString(),
                                      style: TextStyle(color: scheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: Space.xl),
                            _SubmitRow(
                              label: _creating ? 'Create account' : 'Sign in',
                              busy: busy,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: Space.sm),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: context.brand.actionInk,
                              ),
                              onPressed: busy
                                  ? null
                                  : () =>
                                        setState(() => _creating = !_creating),
                              child: Text(
                                _creating
                                    ? 'I already have an account'
                                    : 'Create a new account',
                              ),
                            ),
                            const SizedBox(height: Space.xl),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: IconSizes.sm,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: Space.sm),
                                Flexible(
                                  child: Text(
                                    'Your company data stays private to your '
                                    'team.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Black hero with the logo, radar arcs and a greeting that follows the
/// mode (Ember Slate sign-in artboard).
class _Hero extends StatelessWidget {
  const _Hero({required this.creating});
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = context.brand;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: b.hero,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            bottom: -70,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(300),
                painter: _HeroArcsPainter(arc: b.heroAccent, dot: b.accent),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, Space.xl, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 44),
                      const SizedBox(width: Space.md),
                      Text(
                        'BidRadar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: b.onHero,
                        ),
                      ),
                    ],
                  ).entrance(context),
                  const SizedBox(height: 44),
                  AnimatedSwitcher(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : Motion.medium,
                    child: Text(
                      creating ? 'Create your\naccount' : 'Welcome\nback',
                      key: ValueKey(creating),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: b.onHero,
                        height: 1.05,
                      ),
                    ),
                  ).entrance(context, index: 1),
                  const SizedBox(height: Space.md),
                  SizedBox(
                    width: 250,
                    child: Text(
                      creating
                          ? 'Use your work email. You can invite a bid '
                                'manager later.'
                          : 'Find public tenders your company can win.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: b.heroMuted,
                        height: 1.5,
                      ),
                    ),
                  ).entrance(context, index: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArcsPainter extends CustomPainter {
  const _HeroArcsPainter({required this.arc, required this.dot});

  final Color arc;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    for (final (r, a) in [(130.0, .35), (86.0, .65), (42.0, 1.0)]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -1.5708,
        1.5708,
        false,
        Paint()
          ..color = arc.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, 12, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_HeroArcsPainter old) => old.arc != arc || old.dot != dot;
}

/// "Sign in" in big type with a round orange arrow button.
class _SubmitRow extends StatelessWidget {
  const _SubmitRow({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final b = context.brand;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Text(
              label,
              style: theme.textTheme.headlineMedium?.copyWith(color: b.ink),
            ),
          ),
        ),
        Pressable(
          haptic: true,
          child: Tooltip(
            message: label,
            child: Semantics(
              button: true,
              enabled: !busy,
              label: label,
              excludeSemantics: true,
              child: Material(
                color: b.action,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: b.action.withValues(alpha: .5),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : onPressed,
                  child: SizedBox.square(
                    dimension: 72,
                    child: Center(
                      child: busy
                          ? SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: b.onAction,
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_rounded,
                              size: 28,
                              color: b.onAction,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Step 1 of 2": sign-up comes first, company setup second.
class _StepBar extends StatelessWidget {
  const _StepBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget seg(Color c) => Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            seg(context.brand.action),
            const SizedBox(width: Space.sm),
            seg(scheme.surfaceContainerHighest),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Step 1 of 2 · Account, then your company',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
