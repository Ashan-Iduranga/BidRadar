import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/logging/log.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../domain/scan/scan.dart';
import '../onboarding/onboarding_page.dart' show parseAmount;
import '../widgets/app_header.dart';
import '../widgets/country_picker.dart';
import '../widgets/state_views.dart';
import 'scan_view_model.dart';

/// Page 4: photograph a printed or newspaper tender; ML Kit reads the text
/// on the device, Gemini extracts the fields, the user confirms the buyer
/// and deadline. Owner: Ashan.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _cameraError;

  /// True while a controller is being created, so a resume during the
  /// camera permission dialog does not start a second one.
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  /// Android takes the camera away from a backgrounded app, so release it
  /// as soon as the app stops being in front and start it again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _initCamera();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _releaseCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_starting || _camera != null) return;
    _starting = true;
    CameraController? c;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'No camera found.');
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      // The app may have gone to the background while the camera started
      // (null means Android has not reported a state yet).
      final life = WidgetsBinding.instance.lifecycleState;
      final inFront = life == null || life == AppLifecycleState.resumed;
      if (!mounted || !inFront) {
        await _disposeQuietly(c);
        return;
      }
      setState(() {
        _camera = c;
        _cameraError = null;
      });
    } on Object catch (e) {
      // A controller whose initialize() failed still holds native state.
      if (c != null) await _disposeQuietly(c);
      if (mounted) setState(() => _cameraError = _cameraMessage(e));
    } finally {
      _starting = false;
    }
  }

  void _releaseCamera() {
    final c = _camera;
    if (c == null) return;
    setState(() => _camera = null);
    _disposeQuietly(c);
  }

  static Future<void> _disposeQuietly(CameraController c) async {
    try {
      await c.dispose();
    } on Object catch (e) {
      Log.warn('scan', 'camera dispose failed: $e');
    }
  }

  static String _cameraMessage(Object e) => e is CameraException
      ? (e.code.contains('Denied')
            ? 'Camera permission was denied. Allow it in Settings.'
            : e.description ?? e.code)
      : 'The camera is not available.';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _camera;
    _camera = null;
    if (c != null) _disposeQuietly(c);
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = _camera;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    final XFile file;
    try {
      file = await c.takePicture();
    } on Object catch (e) {
      Log.warn('scan', 'takePicture failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not take the photo (${_cameraMessage(e)}). Try again.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await ref.read(scanViewModelProvider.notifier).process(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanViewModelProvider);
    ref.listen(scanViewModelProvider, (_, next) {
      if (next is ScanSaved) {
        ref.read(scanViewModelProvider.notifier).reset();
        context.pushReplacement(Routes.tender(next.tenderId));
      }
    });
    final vm = ref.read(scanViewModelProvider.notifier);

    return GradientBackground(
      child: Scaffold(
        appBar: const BrandAppBar(title: 'Scan a notice'),
        body: switch (state) {
          ScanWorking(:final step) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: Space.lg),
                Text(step),
              ],
            ),
          ),
          ScanFailed(:final message) => ErrorState(
            title: 'Could not scan',
            message: message,
            onRetry: vm.reset,
          ),
          ScanReview() => _ReviewForm(review: state),
          _ => _capture(vm),
        },
      ),
    );
  }

  Widget _capture(ScanViewModel vm) {
    final c = _camera;
    final sample = kDebugMode
        ? TextButton.icon(
            onPressed: vm.useSample,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Try a sample notice (debug)'),
          )
        : null;
    if (c == null || !c.value.isInitialized) {
      return Column(
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.document_scanner_outlined,
              title: 'Scan a printed tender',
              message:
                  _cameraError ??
                  'Starting the camera… Photograph a newspaper or printed '
                      'notice; you confirm the buyer and deadline after.',
            ),
          ),
          ?sample,
          const SizedBox(height: Space.xl),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(c),
              Positioned(
                left: Space.gutter,
                right: Space.gutter,
                top: Space.gutter,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: const Padding(
                    padding: EdgeInsets.all(Space.md),
                    child: Text(
                      'Fit the whole notice in the frame, in good light.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.large(
                tooltip: 'Take photo',
                onPressed: _shoot,
                child: const Icon(Icons.camera_alt_outlined),
              ),
            ],
          ),
        ),
        ?sample,
      ],
    );
  }
}

/// The dates the deadline picker allows, and where it opens. Wide enough
/// for an old newspaper notice or a long framework, and the start date is
/// always inside the range: a misread year can no longer stop the picker
/// from opening.
@visibleForTesting
({DateTime first, DateTime last, DateTime initial}) deadlinePickerRange(
  DateTime? deadline,
  DateTime now,
) {
  final first = DateTime(now.year - 10);
  final last = DateTime(now.year + 10, 12, 31);
  var initial = deadline ?? now.add(const Duration(days: 14));
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return (first: first, last: last, initial: initial);
}

/// Confirm what the AI read. Buyer and deadline must be checked by a person
/// before the tender is saved.
class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.review});
  final ScanReview review;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  /// What the user typed before a save that did not go through, if any.
  late final ScanDraft? _typed = widget.review.draft;
  late final ScannedNotice _read = widget.review.read;
  late final _title = TextEditingController(text: _typed?.title ?? _read.title);
  late final _buyer = TextEditingController(text: _typed?.buyer ?? _read.buyer);
  late final _turnover = TextEditingController(
    text: (_typed?.minTurnover ?? _read.minTurnover)?.toStringAsFixed(0) ?? '',
  );
  late DateTime? _deadline = _typed?.deadline ?? _read.deadline;
  late String _country = _typed?.country ?? _read.country;
  late String? _currency = _typed?.currency ?? _read.currency;
  late bool _deadlineConfirmed = _typed?.deadline != null;
  bool _showText = false;

  /// Shown under the field they belong to until the user changes it.
  Map<ScanField, String> _problems = const {};

  @override
  void dispose() {
    _title.dispose();
    _buyer.dispose();
    _turnover.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final range = deadlinePickerRange(_deadline, DateTime.now());
    final initial = range.initial;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: range.first,
      lastDate: range.last,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
      _deadlineConfirmed = true;
      _problems = {..._problems}..remove(ScanField.deadline);
    });
  }

  void _clear(ScanField field) {
    if (_problems.containsKey(field)) {
      setState(() => _problems = {..._problems}..remove(field));
    }
  }

  ScanDraft _draft() => ScanDraft(
    title: _title.text,
    buyer: _buyer.text,
    deadline: _deadline,
    country: _country,
    ocrText: widget.review.ocrText,
    requirements: _read.requirements,
    minTurnover: parseAmount(_turnover.text),
    currency: (_currency?.length == 3) ? _currency : null,
    cpvCodes: _read.cpvCodes,
  );

  /// Problems stay on the form, next to their fields, with everything the
  /// user typed. Only a draft without problems is saved.
  void _save() {
    final draft = _draft();
    final problems = {
      if (draft.deadline != null && !_deadlineConfirmed)
        ScanField.deadline: 'Tap to confirm the date and time.',
      ...draft.fieldProblems,
    };
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    ref.read(scanViewModelProvider.notifier).save(draft);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final theme = Theme.of(context);
    final vm = ref.read(scanViewModelProvider.notifier);
    final error = theme.colorScheme.error;

    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        if (r.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              r.error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: error),
            ),
          ),
        if (r.aiFailed)
          const Padding(
            padding: EdgeInsets.only(bottom: Space.md),
            child: Text(
              'The AI could not read this notice. Fill in the fields from '
              'the text below.',
            ),
          ),
        Text('Check what was read', style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.md),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: 'What is being bought',
            errorText: _problems[ScanField.title],
          ),
          maxLines: null,
          onChanged: (_) => _clear(ScanField.title),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _buyer,
          decoration: InputDecoration(
            labelText: 'Buyer',
            helperText: 'Check this against the notice.',
            errorText: _problems[ScanField.buyer],
          ),
          onChanged: (_) => _clear(ScanField.buyer),
        ),
        const SizedBox(height: Space.lg),
        InkWell(
          onTap: _pickDeadline,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Deadline',
              helperText: _deadlineConfirmed
                  ? 'Confirmed.'
                  : 'Tap to confirm the date and time.',
              errorText: _problems[ScanField.deadline],
              suffixIcon: Icon(
                _deadlineConfirmed ? Icons.check_circle : Icons.edit_calendar,
              ),
            ),
            child: Text(
              _deadline == null
                  ? 'Not found'
                  : DateFormat.yMMMEd().add_jm().format(_deadline!),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        CountryField(
          label: 'Country',
          value: _country.isEmpty ? null : _country,
          onChanged: (c) => setState(() => _country = c),
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _turnover,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum turnover',
                  helperText: 'If the notice states one.',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              flex: 2,
              child: TextField(
                controller: TextEditingController(text: _currency ?? ''),
                decoration: const InputDecoration(labelText: 'Currency'),
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => _currency = v.trim().toUpperCase(),
              ),
            ),
          ],
        ),
        if (r.read.requirements.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          Text('Requirements found', style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.xs),
          for (final q in r.read.requirements)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text('• $q'),
            ),
        ],
        const SizedBox(height: Space.lg),
        TextButton(
          onPressed: () => setState(() => _showText = !_showText),
          child: Text(_showText ? 'Hide scanned text' : 'Show scanned text'),
        ),
        if (_showText) SelectableText(r.ocrText),
        const SizedBox(height: Space.xl),
        if (_problems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              _problems[ScanField.text] ?? 'Fix the fields marked above.',
              style: theme.textTheme.bodyMedium?.copyWith(color: error),
            ),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Save and judge'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(kMinTouchTarget),
          ),
          onPressed: _save,
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton(onPressed: vm.reset, child: const Text('Retake')),
      ],
    );
  }
}
