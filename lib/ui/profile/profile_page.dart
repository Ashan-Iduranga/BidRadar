import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/geo/countries.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/models.dart';
import '../onboarding/onboarding_page.dart' show parseAmount;
import '../session/session_providers.dart';
import '../widgets/app_header.dart';
import '../widgets/country_picker.dart';
import '../widgets/state_views.dart';
import 'profile_view_model.dart';

/// Page 3: sectors (CPV), countries, turnover, certifications, past
/// contracts and team. Owners edit; bid managers read. Owner: Dinuja.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(firebaseReadyProvider)) {
      return GradientBackground(
        child: Scaffold(
          appBar: const BrandAppBar(title: 'Company', large: true),
          body: const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Firebase is not configured',
            message: 'The company profile is stored in Firestore.',
          ),
        ),
      );
    }
    final company = ref.watch(currentCompanyProvider);
    final role = ref.watch(currentRoleProvider);
    final edit = ref.watch(profileViewModelProvider);
    final c = company.value;
    final p = edit.draft;

    return GradientBackground(
      child: Scaffold(
        appBar: const BrandAppBar(title: 'Company', large: true),
        body: (c == null || p == null)
            ? company.hasError
                  ? ErrorState(message: 'Could not load the company.')
                  : const Center(child: CircularProgressIndicator())
            : _ProfileBody(
                company: c,
                profile: p,
                canEdit: role == UserRole.owner,
              ),
        bottomNavigationBar: edit.dirty ? _SaveBar(saving: edit.saving) : null,
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.company,
    required this.profile,
    required this.canEdit,
  });

  final Company company;
  final CompanyProfile profile;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(profileViewModelProvider.notifier);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        _CompanyHeader(company: company, canEdit: canEdit),
        if (!canEdit) ...[
          const SizedBox(height: Space.md),
          Row(
            children: [
              Icon(Icons.lock_outline, size: IconSizes.sm, color: muted),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Only the owner can change the profile.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
        _Section(
          title: 'Sectors',
          help:
              'CPV codes. A broad code covers its sub-codes: 72000000 '
              'covers all IT services.',
          child: _ChipList(
            values: profile.cpvCodes,
            label: (v) => v,
            empty: 'No sectors yet. Tenders cannot be matched by sector.',
            onDelete: canEdit ? vm.removeCpv : null,
            addLabel: 'Add sector',
            onAdd: canEdit
                ? () => _askText(
                    context,
                    title: 'Add a CPV code',
                    label: 'CPV code',
                    hint: '72000000',
                    keyboard: TextInputType.number,
                    submit: vm.addCpv,
                  )
                : null,
          ),
        ),
        _Section(
          title: 'Countries you deliver in',
          help: 'Tenders in other countries are removed by the rules.',
          child: _ChipList(
            values: profile.countries,
            label: Countries.nameOf,
            empty: 'No countries yet.',
            onDelete: canEdit ? vm.removeCountry : null,
            addLabel: 'Add country',
            onAdd: canEdit
                ? () async {
                    final code = await showCountryPicker(
                      context,
                      exclude: profile.countries.toSet(),
                    );
                    if (code != null) vm.addCountry(code);
                  }
                : null,
          ),
        ),
        _Section(
          title: 'Certifications',
          child: _ChipList(
            values: profile.certifications,
            label: (v) => v,
            empty: 'None added.',
            onDelete: canEdit ? vm.removeCertification : null,
            addLabel: 'Add certification',
            onAdd: canEdit
                ? () => _askText(
                    context,
                    title: 'Add a certification',
                    label: 'Certification',
                    hint: 'ISO 9001',
                    submit: vm.addCertification,
                  )
                : null,
          ),
        ),
        _Section(
          title: 'Past contracts',
          help: 'The bid agent uses these as evidence of experience.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile.pastContracts.isEmpty)
                Text('None added.', style: TextStyle(color: muted)),
              for (final (i, pc) in profile.pastContracts.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: Space.sm),
                  child: ListTile(
                    title: Text(pc.title),
                    subtitle: Text(
                      '${pc.buyer} · ${pc.year} · '
                      '${NumberFormat.compact().format(pc.value)}',
                    ),
                    trailing: canEdit
                        ? IconButton(
                            tooltip: 'Remove ${pc.title}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => vm.removePastContract(i),
                          )
                        : null,
                  ),
                ),
              if (canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final pc = await showDialog<PastContract>(
                        context: context,
                        builder: (_) => const _PastContractDialog(),
                      );
                      if (pc != null) vm.addPastContract(pc);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add past contract'),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: 'Team',
          child: _TeamList(company: company, canEdit: canEdit),
        ),
        const SizedBox(height: Space.xl),
        OutlinedButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// Text dialog whose [submit] returns an error message or null.
Future<void> _askText(
  BuildContext context, {
  required String title,
  required String label,
  required String hint,
  required String? Function(String) submit,
  TextInputType? keyboard,
}) => showDialog<void>(
  context: context,
  builder: (context) => _TextDialog(
    title: title,
    label: label,
    hint: hint,
    submit: submit,
    keyboard: keyboard,
  ),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.submit,
    this.keyboard,
  });

  final String title;
  final String label;
  final String hint;
  final String? Function(String) submit;
  final TextInputType? keyboard;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final e = widget.submit(_c.text);
    if (e == null) {
      Navigator.pop(context);
    } else {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _c,
      autofocus: true,
      keyboardType: widget.keyboard,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: _error,
      ),
      onSubmitted: (_) => _go(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _go, child: const Text('Add')),
    ],
  );
}

class _CompanyHeader extends ConsumerWidget {
  const _CompanyHeader({required this.company, required this.canEdit});
  final Company company;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final money = company.annualTurnover > 0
        ? NumberFormat.compactCurrency(symbol: '${company.currency} ')
              .format(company.annualTurnover)
        : 'Turnover not set';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    '${Countries.nameOf(company.country)} · $money · '
                    '${company.teamSize} people',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                tooltip: 'Edit company details',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  useSafeArea: true,
                  builder: (_) => _CompanySheet(company: company),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompanySheet extends ConsumerStatefulWidget {
  const _CompanySheet({required this.company});
  final Company company;

  @override
  ConsumerState<_CompanySheet> createState() => _CompanySheetState();
}

class _CompanySheetState extends ConsumerState<_CompanySheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.company.name);
  late final _turnover = TextEditingController(
    text: widget.company.annualTurnover.toStringAsFixed(0),
  );
  late final _team = TextEditingController(text: '${widget.company.teamSize}');
  late String _country = widget.company.country;
  late String _currency = kCurrencies.contains(widget.company.currency)
      ? widget.company.currency
      : kCurrencies.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _turnover.dispose();
    _team.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await ref
        .read(profileViewModelProvider.notifier)
        .updateCompany(
          widget.company.copyWith(
            name: _name.text.trim(),
            country: _country,
            annualTurnover: parseAmount(_turnover.text),
            currency: _currency,
            teamSize: int.parse(_team.text.trim()),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.xl,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Company details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Company name'),
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
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => (parseAmount(v) ?? -1) < 0
                          ? 'Enter an amount.'
                          : null,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(labelText: 'Currency'),
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
                validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 1
                    ? 'Enter the number of people.'
                    : null,
              ),
              const SizedBox(height: Space.xl),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(kMinTouchTarget),
                ),
                child: Text(_saving ? 'Saving…' : 'Save details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastContractDialog extends StatefulWidget {
  const _PastContractDialog();

  @override
  State<_PastContractDialog> createState() => _PastContractDialogState();
}

class _PastContractDialogState extends State<_PastContractDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _buyer = TextEditingController();
  final _year = TextEditingController(text: '${DateTime.now().year}');
  final _value = TextEditingController();

  @override
  void dispose() {
    for (final c in [_title, _buyer, _year, _value]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      PastContract(
        title: _title.text.trim(),
        buyer: _buyer.text.trim(),
        year: int.parse(_year.text.trim()),
        value: parseAmount(_value.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Required.' : null;
    final thisYear = DateTime.now().year;
    return AlertDialog(
      title: const Text('Add past contract'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'What you did'),
                validator: required,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _buyer,
                decoration: const InputDecoration(labelText: 'Client'),
                validator: required,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _year,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final y = int.tryParse(v?.trim() ?? '');
                  return (y == null || y < 1990 || y > thisYear)
                      ? 'Enter a year from 1990 to $thisYear.'
                      : null;
                },
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _value,
                decoration: const InputDecoration(labelText: 'Contract value'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    (parseAmount(v) ?? -1) < 0 ? 'Enter an amount.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _add, child: const Text('Add')),
      ],
    );
  }
}

class _TeamList extends ConsumerWidget {
  const _TeamList({required this.company, required this.canEdit});
  final Company company;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = company.members.entries.toList()
      ..sort((a, b) => a.value.index.compareTo(b.value.index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              m.value == UserRole.owner
                  ? Icons.verified_user_outlined
                  : Icons.person_outline,
            ),
            title: Text(company.memberEmails[m.key] ?? 'Member'),
            subtitle: Text(m.value == UserRole.owner ? 'Owner' : 'Bid manager'),
          ),
        if (canEdit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite a bid manager'),
              onPressed: () {
                final vm = ref.read(profileViewModelProvider.notifier);
                final messenger = ScaffoldMessenger.of(context);
                showDialog<void>(
                  context: context,
                  builder: (_) => _InviteDialog(
                    send: vm.invite,
                    onSent: (email) => messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Invite saved. $email can now sign up and join.',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.send, required this.onSent});
  final Future<String?> Function(String) send;
  final ValueChanged<String> onSent;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    final email = _c.text.trim();
    final e = await widget.send(email);
    if (!mounted) return;
    if (e == null) {
      Navigator.pop(context);
      widget.onSent(email);
    } else {
      setState(() {
        _busy = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite a bid manager'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'They sign in with this email and accept the invite. Bid managers '
          'can manage bids but cannot approve them.',
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'Email', errorText: _error),
          onSubmitted: (_) => _go(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _go,
        child: const Text('Send invite'),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.help});
  final String title;
  final String? help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (help != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              help!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    );
  }
}

/// Wrapping input chips with an "add" chip at the end (Material 3 input
/// chips pattern).
class _ChipList extends StatelessWidget {
  const _ChipList({
    required this.values,
    required this.label,
    required this.empty,
    required this.addLabel,
    this.onDelete,
    this.onAdd,
  });

  final List<String> values;
  final String Function(String) label;
  final String empty;
  final String addLabel;
  final ValueChanged<String>? onDelete;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (values.isEmpty && onAdd == null)
          Text(empty, style: TextStyle(color: muted)),
        for (final v in values)
          InputChip(
            label: Text(label(v)),
            onDeleted: onDelete == null ? null : () => onDelete!(v),
            deleteButtonTooltipMessage: 'Remove ${label(v)}',
          ),
        if (onAdd != null)
          ActionChip(
            avatar: const Icon(Icons.add, size: IconSizes.sm),
            label: Text(addLabel),
            onPressed: onAdd,
          ),
      ],
    );
  }
}

class _SaveBar extends ConsumerWidget {
  const _SaveBar({required this.saving});
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(profileViewModelProvider.notifier);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Unsaved changes')),
              TextButton(
                onPressed: saving ? null : vm.discard,
                child: const Text('Discard'),
              ),
              const SizedBox(width: Space.sm),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final err = await vm.save();
                        messenger.showSnackBar(
                          SnackBar(content: Text(err ?? 'Profile saved.')),
                        );
                      },
                child: Text(saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
