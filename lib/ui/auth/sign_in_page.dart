import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
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
                            FilledButton(
                              onPressed: busy ? null : _submit,
                              child: busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _creating ? 'Create account' : 'Sign in',
                                    ),
                            ),
                            const SizedBox(height: Space.sm),
                            TextButton(
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

/// Gradient header with the logo and a greeting that follows the mode.
class _Hero extends StatelessWidget {
  const _Hero({required this.creating});
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(theme.brightness),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Radii.xl + 4),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.xl,
            Space.xl,
            Space.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMark(size: 52),
                  const SizedBox(width: Space.md),
                  Text(
                    'BidRadar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(
                creating ? 'Create your account' : 'Welcome back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                creating
                    ? 'Use your work email. You can invite a bid manager later.'
                    : 'Find public tenders your company can win.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.heroMuted,
                ),
              ),
            ],
          ),
        ),
      ),
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
            seg(scheme.primary),
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

/// The BidRadar logo: radar arcs from a corner on an azure-to-teal tile.
/// Same artwork as the launcher icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'BidRadar logo',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _BrandMarkPainter()),
  );
}

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 108; // the artwork is drawn on a 108 grid
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(30 * s)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.azureDeep, Brand.azure, Color(0xFF0A8F78)],
          stops: [0, .55, 1],
        ).createShader(Offset.zero & size),
    );
    // Each arc starts at the corner dot and bends up to the right, like a
    // signal spreading out (centre one radius to the right of the dot).
    final origin = Offset(30 * s, 78 * s);
    for (final (r, alpha) in [(48.0, .45), (32.0, .75), (16.0, 1.0)]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset((30 + r) * s, 78 * s), radius: r * s),
        math.pi,
        math.pi / 2,
        false,
        Paint()
          ..color = Brand.mint.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * s
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(origin, 6 * s, Paint()..color = Brand.mint);
    canvas.drawCircle(
      Offset(76 * s, 62 * s),
      6.5 * s,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
