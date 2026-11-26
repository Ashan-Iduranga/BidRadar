import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/log.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../domain/scan/scan.dart';
import '../../domain/scan/scan_services.dart';
import '../feed/feed_view_model.dart';
import '../session/session_providers.dart';

final textOcrProvider = Provider<TextOcr>((ref) => MlKitOcr());
final noticeReaderProvider = Provider<NoticeReader>(
  (ref) => GeminiNoticeReader(),
);

sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanWorking extends ScanState {
  const ScanWorking(this.step);
  final String step;
}

class ScanReview extends ScanState {
  const ScanReview({
    required this.read,
    required this.ocrText,
    required this.imagePath,
    this.aiFailed = false,
    this.draft,
    this.error,
  });
  final ScannedNotice read;
  final String ocrText;
  final String imagePath;

  /// The AI could not read it; the user fills the form from the OCR text.
  final bool aiFailed;

  /// What the user had typed when a save did not go through. The form
  /// starts from it instead of from [read].
  final ScanDraft? draft;

  /// Why the last save did not go through.
  final String? error;

  /// Back to the form with everything the user typed, and why.
  ScanReview withDraft(ScanDraft draft, String error) => ScanReview(
    read: read,
    ocrText: ocrText,
    imagePath: imagePath,
    aiFailed: aiFailed,
    draft: draft,
    error: error,
  );
}

class ScanSaved extends ScanState {
  const ScanSaved(this.tenderId);
  final String tenderId;
}

class ScanFailed extends ScanState {
  const ScanFailed(this.message);
  final String message;
}

class ScanViewModel extends Notifier<ScanState> {
  static const sampleAsset = 'assets/samples/sample_notice.png';

  @override
  ScanState build() => const ScanIdle();

  void reset() => state = const ScanIdle();

  /// Debug and demo path: the bundled synthetic notice instead of a photo.
  Future<void> useSample() async {
    state = const ScanWorking('Loading the sample notice…');
    final File file;
    try {
      final bytes = (await rootBundle.load(sampleAsset)).buffer.asUint8List();
      file = File('${(await getTemporaryDirectory()).path}/sample.png');
      await file.writeAsBytes(bytes, flush: true);
    } on Object catch (e, st) {
      Log.error('scan', 'could not load the sample notice', e, st);
      if (ref.mounted) {
        state = const ScanFailed('Could not load the sample notice.');
      }
      return;
    }
    if (!ref.mounted) return;
    await process(file.path, mimeType: 'image/png');
  }

  /// Reads the photo. If the user leaves the page meanwhile, the result is
  /// dropped with the page (`ref.mounted` turns false).
  Future<void> process(
    String imagePath, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      state = const ScanWorking('Reading the text…');
      final ocr = await ref.read(textOcrProvider).read(imagePath);
      if (!ref.mounted) return;
      if (ocr.trim().length < 40) {
        state = const ScanFailed(
          'No readable text found. Use good light, hold the phone flat and '
          'fit the whole notice in the frame.',
        );
        return;
      }
      state = const ScanWorking('Understanding the notice…');
      final Uint8List image = await File(imagePath).readAsBytes();
      if (!ref.mounted) return;
      try {
        final read = await ref
            .read(noticeReaderProvider)
            .read(image: image, mimeType: mimeType, ocrText: ocr);
        if (!ref.mounted) return;
        state = ScanReview(read: read, ocrText: ocr, imagePath: imagePath);
      } on Object catch (e) {
        // The AI is optional here: the user can still type the fields.
        Log.warn('scan', 'AI could not read the notice: $e');
        if (!ref.mounted) return;
        state = ScanReview(
          read: ScannedNotice.empty,
          ocrText: ocr,
          imagePath: imagePath,
          aiFailed: true,
        );
      }
    } on Object catch (e) {
      Log.error('scan', 'scan failed', e);
      if (ref.mounted) state = ScanFailed('Could not read the photo: $e');
    }
  }

  /// Saves the confirmed scan as a tender, applies the hard rules and asks
  /// the bid agent, exactly like a tender from the feed. A draft with
  /// problems, or a failed save, goes back to the form with everything the
  /// user typed. Once the tender is saved on the phone, a failed AI call
  /// still opens it; Tender detail can judge it again.
  ///
  /// The save finishes even if the user leaves the page; the state is then
  /// dropped as soon as it is done, so the next visit starts fresh.
  Future<void> save(ScanDraft draft) async {
    final review = state;
    if (review is! ScanReview) return;
    final problems = draft.problems;
    if (problems.isNotEmpty) {
      state = review.withDraft(draft, problems.first);
      return;
    }
    final link = ref.keepAlive();
    try {
      await _save(review, draft);
    } finally {
      link.close();
    }
  }

  Future<void> _save(ScanReview review, ScanDraft draft) async {
    final tender = draft.toTender(DateTime.now());
    state = const ScanWorking('Saving…');
    try {
      await ref.read(tenderCacheProvider).upsertAll([tender]);
    } on Object catch (e, st) {
      Log.error('scan', 'could not save the scanned tender', e, st);
      state = review.withDraft(
        draft,
        'Could not save the tender on this phone. Try again.',
      );
      return;
    }
    try {
      await ref
          .read(syncStoreProvider)
          .saveTenders([tender])
          .timeout(const Duration(seconds: 15));
    } on Object {
      // Queued offline by Firestore.
    }
    try {
      await _judge(tender);
    } on Object catch (e, st) {
      Log.error('scan', 'could not judge the scanned tender', e, st);
    }
    state = ScanSaved(tender.id);
  }

  Future<void> _judge(Tender tender) async {
    final company = ref.read(currentCompanyProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    if (company == null || profile == null) return;
    final rules = ref
        .read(eligibilityRulesProvider)
        .check(
          company: company,
          profile: profile,
          tender: tender,
          now: DateTime.now(),
        );
    if (!rules.passed) return;
    state = const ScanWorking('Judging with AI…');
    final v = await ref
        .read(bidAgentProvider)
        .judge(
          company: company,
          profile: profile,
          tender: tender,
          rules: rules,
        );
    await ref.read(verdictCacheProvider).put(v, textHash: tender.textHash);
    try {
      await ref
          .read(syncStoreProvider)
          .recordVerdicts([v])
          .timeout(const Duration(seconds: 15));
    } on Object {
      // Queued offline.
    }
  }
}

/// Lives only while the Scan page shows it, so leaving the page drops a
/// half-finished scan instead of showing it on the next visit.
final scanViewModelProvider =
    NotifierProvider.autoDispose<ScanViewModel, ScanState>(ScanViewModel.new);
