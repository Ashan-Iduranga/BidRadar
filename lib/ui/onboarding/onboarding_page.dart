import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/geo/countries.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../../data/seed/sample_companies.dart';
import '../auth/auth_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/country_picker.dart';
import '../widgets/state_views.dart';
import 'onboarding_view_model.dart';

/// Shown after sign-in when the user has no company: join through an invite,
/// create a company (the user becomes owner), or start from a sample.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _turnover = TextEditingController();
  final _team = TextEditingController();
  String? _country;
  String _currency = 'EUR';
  bool _busy = false;
  bool _submitted = false;

  /// Coming back from the email app after tapping the link: check again
  /// without asking, so the Join button appears by itself.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _recheckOnResume);
  }

  void _recheckOnResume() {
    final data = ref.read(onboardingViewModelProvider).value;
    if (data == null || data.invite == null || data.emailVerified) return;
    unawaited(ref.read(onboardingViewModelProvider.notifier).confirmVerified());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _name.dispose();
    _turnover.dispose();
    _team.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _decline(Invite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Decline the invite from ${invite.companyName}?'),
        content: const Text(
          'The invite is deleted. The owner can send a new one later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _run(
        () => ref
            .read(onboardingViewModelProvider.notifier)
            .declineInvite(invite),
      );
    }
  }

  void _create() {
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _country == null) return;
    final vm = ref.read(onboardingViewModelProvider.notifier);
    _run(
      () => vm.createCompany(
        name: _name.text.trim(),
        country: _country!,
        annualTurnover: parseAmount(_turnover.text)!,
        currency: _currency,
        teamSize: int.parse(_team.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(onboardingViewModelProvider);
    return GradientBackground(
      child: Scaffold(
        appBar: BrandAppBar(
          title: 'Set up your company',
          showAvatar: false,
          actions: [
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(authServiceProvider).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
        // Keep the last data on screen while the invite listener updates.
        body: switch (data) {
          AsyncValue(:final value?) => _body(context, value),
          AsyncValue(:final error?) => ErrorState(
            message: 'Could not load setup: $error',
            onRetry: () => ref.invalidate(onboardingViewModelProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _body(BuildContext context, OnboardingData data) {
    final theme = Theme.of(context);
    final vm = ref.read(onboardingViewModelProvider.notifier);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          if (data.invite case final invite?) ...[
            _InviteCard(
              invite: invite,
              busy: _busy,
              verified: data.emailVerified,
              email: ref.watch(authStateProvider).value?.email,
              onJoin: () => _run(() => vm.acceptInvite(invite)),
              onDecline: () => _decline(invite),
              onVerified: () => _run(vm.confirmVerified),
              onResend: () => _run(vm.resendVerification),
            ),
            const SizedBox(height: Space.xl),
          ] else ...[
            _WaitingForInvite(email: ref.watch(authStateProvider).value?.email),
            const SizedBox(height: Space.xl),
          ],
          Text('Create a company', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            'You become its owner. You can invite a bid manager later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Company name'),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter the company name.'
                      : null,
                ),
                const SizedBox(height: Space.lg),
                CountryField(
                  label: 'Registered in',
                  value: _country,
                  onChanged: (c) => setState(() => _country = c),
                ),
                if (_country == null && _submitted)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.xs,
                      left: Space.lg,
                    ),
                    child: Text(
                      'Choose a country.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _turnover,
                        decoration: const InputDecoration(
                          labelText: 'Yearly turnover',
                          helperText: 'Used to check minimum turnover rules.',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (parseAmount(v) ?? -1) < 0
                            ? 'Enter an amount, e.g. 850000.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: [
                          for (final c in kCurrencies)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _team,
                  decoration: const InputDecoration(labelText: 'Team size'),
                  keyboardType: TextInputType.number,
                  onFieldSubmitted: (_) => _create(),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    return (n == null || n < 1)
                        ? 'Enter the number of people.'
                        : null;
                  },
                ),
                const SizedBox(height: Space.xl),
                FilledButton(
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(kMinTouchTarget),
                  ),
                  child: const Text('Create company'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xxl),
          Text('Or try a sample company', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            'Synthetic data with sectors and countries filled in. Good for '
            'a demo.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.md),
          for (final s in data.samples)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _SampleTile(
                sample: s,
                enabled: !_busy,
                onTap: () => _run(() => vm.startFromSample(s)),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: Space.lg),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

/// "850,000" or "850000.50" -> 850000.5. Null if not a number.
double? parseAmount(String? s) =>
    double.tryParse((s ?? '').replaceAll(RegExp(r'[,\s]'), ''));

/// Shown when there is no invite yet: it appears here by itself.
class _WaitingForInvite extends StatelessWidget {
  const _WaitingForInvite({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.group_add_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            'Joining a team? Ask the owner to invite '
            '${email ?? 'your email address'}. The invite shows up here '
            'as soon as it is sent.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The invite, with Join and Decline. Until the email is verified it asks
/// for that instead, with "I have verified" and Resend.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.busy,
    required this.verified,
    required this.email,
    required this.onJoin,
    required this.onDecline,
    required this.onVerified,
    required this.onResend,
  });

  final Invite invite;
  final bool busy;
  final bool verified;
  final String? email;
  final VoidCallback onJoin;
  final VoidCallback onDecline;
  final VoidCallback onVerified;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mail_outline, color: theme.colorScheme.primary),
                const SizedBox(width: Space.sm),
                Text('You have an invite', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Space.sm),
            if (verified) ...[
              Text(
                'Join ${invite.companyName} as a bid manager. You can review '
                'tenders and manage bids; the owner approves them.',
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: busy ? null : onJoin,
                child: Text('Join ${invite.companyName}'),
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton(
                onPressed: busy ? null : onDecline,
                child: const Text('Decline'),
              ),
            ] else ...[
              Text(
                'Verify your email to join ${invite.companyName}. We sent a '
                'link to ${email ?? 'your email address'}. Open it, then '
                'come back here.',
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: busy ? null : onVerified,
                child: const Text('I have verified'),
              ),
              const SizedBox(height: Space.sm),
              TextButton(
                onPressed: busy ? null : onResend,
                child: const Text('Resend email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({
    required this.sample,
    required this.enabled,
    required this.onTap,
  });

  final SampleCompany sample;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = sample.company;
    final money = NumberFormat.compactCurrency(symbol: '${c.currency} ')
        .format(c.annualTurnover);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        enabled: enabled,
        title: Text(c.name),
        subtitle: Text(
          '${Countries.nameOf(c.country)} · $money · '
          '${sample.profile.cpvCodes.length} sectors',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
