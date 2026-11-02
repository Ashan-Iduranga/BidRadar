import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/log.dart';
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
  });
  final ScannedNotice read;
  final String ocrText;
  final String imagePath;

  /// The AI could not read it; the user fills the form from the OCR text.
  final bool aiFailed;
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
    final bytes = (await rootBundle.load(sampleAsset)).buffer.asUint8List();
    final file = File('${(await getTemporaryDirectory()).path}/sample.png');
    await file.writeAsBytes(bytes, flush: true);
    await process(file.path, mimeType: 'image/png');
  }

  Future<void> process(
    String imagePath, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      state = const ScanWorking('Reading the text…');
      final ocr = await ref.read(textOcrProvider).read(imagePath);
      if (ocr.trim().length < 40) {
        state = const ScanFailed(
          'No readable text found. Use good light, hold the phone flat and '
          'fit the whole notice in the frame.',
        );
        return;
      }
      state = const ScanWorking('Understanding the notice…');
      final Uint8List image = await File(imagePath).readAsBytes();
      try {
        final read = await ref
            .read(noticeReaderProvider)
            .read(image: image, mimeType: mimeType, ocrText: ocr);
        state = ScanReview(read: read, ocrText: ocr, imagePath: imagePath);
      } on Object catch (e) {
        // The AI is optional here: the user can still type the fields.
        Log.warn('scan', 'AI could not read the notice: $e');
        state = ScanReview(
          read: ScannedNotice.empty,
          ocrText: ocr,
          imagePath: imagePath,
          aiFailed: true,
        );
      }
    } on Object catch (e) {
      Log.error('scan', 'scan failed', e);
      state = ScanFailed('Could not read the photo: $e');
    }
  }

  /// Saves the confirmed scan as a tender, applies the hard rules and asks
  /// the bid agent, exactly like a tender from the feed.
  Future<void> save(ScanDraft draft) async {
    final problems = draft.problems;
    if (problems.isNotEmpty) {
      state = ScanFailed(problems.first);
      return;
    }
    final company = ref.read(currentCompanyProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    final tender = draft.toTender(DateTime.now());
    state = const ScanWorking('Saving…');
    await ref.read(tenderCacheProvider).upsertAll([tender]);
    try {
      await ref
          .read(syncStoreProvider)
          .saveTenders([tender])
          .timeout(const Duration(seconds: 15));
    } on Object {
      // Queued offline by Firestore.
    }
    if (company != null && profile != null) {
      final rules = ref
          .read(eligibilityRulesProvider)
          .check(
            company: company,
            profile: profile,
            tender: tender,
            now: DateTime.now(),
          );
      if (rules.passed) {
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
    state = ScanSaved(tender.id);
  }
}

final scanViewModelProvider = NotifierProvider<ScanViewModel, ScanState>(
  ScanViewModel.new,
);
