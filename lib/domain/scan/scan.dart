import 'package:flutter/foundation.dart';

import '../../core/geo/countries.dart';
import '../../core/text/text_utils.dart';
import '../../data/models/models.dart';

/// What the AI read from a photographed notice. Unverified until the user
/// confirms it on the Scan page.
@immutable
class ScannedNotice {
  const ScannedNotice({
    required this.title,
    required this.buyer,
    required this.deadline,
    required this.country,
    required this.requirements,
    this.minTurnover,
    this.currency,
    this.cpvCodes = const [],
  });

  /// Nothing extracted: the user fills the form from the OCR text.
  static const empty = ScannedNotice(
    title: '',
    buyer: '',
    deadline: null,
    country: '',
    requirements: [],
  );

  final String title;
  final String buyer;

  /// Local wall-clock time as printed; null if not found.
  final DateTime? deadline;

  /// Alpha-3, or empty when unknown or invalid.
  final String country;
  final List<String> requirements;
  final double? minTurnover;
  final String? currency;
  final List<String> cpvCodes;

  /// Lenient parsing: a bad field becomes empty instead of failing the scan,
  /// because the user reviews everything before saving.
  factory ScannedNotice.fromJson(Map<String, dynamic> j) {
    String str(String k) => (j[k] is String) ? (j[k] as String).trim() : '';
    final country = str('country').toUpperCase();
    final currency = str('currency').toUpperCase();
    final turnover = j['minTurnover'];
    return ScannedNotice(
      title: str('title'),
      buyer: str('buyer'),
      deadline: DateTime.tryParse(str('deadline')),
      country: Countries.isAlpha3(country) ? country : '',
      requirements: [
        for (final r in (j['requirements'] as List? ?? const []))
          if (r is String && r.trim().isNotEmpty) r.trim(),
      ],
      minTurnover: turnover is num && turnover > 0 ? turnover.toDouble() : null,
      currency: RegExp(r'^[A-Z]{3}$').hasMatch(currency) ? currency : null,
      cpvCodes: [
        for (final c in (j['cpvCodes'] as List? ?? const []))
          if (c is String && RegExp(r'^\d{8}').hasMatch(c)) c.substring(0, 8),
      ],
    );
  }
}

/// On-device text recognition (ML Kit in the app, a fake in tests).
abstract interface class TextOcr {
  Future<String> read(String imagePath);
}

/// Reads structure out of a notice photo plus its OCR text (Gemini).
abstract interface class NoticeReader {
  Future<ScannedNotice> read({
    required Uint8List image,
    required String mimeType,
    required String ocrText,
  });
}

/// The parts of the scan review form a problem can belong to.
enum ScanField { title, buyer, deadline, text }

/// The confirmed scan, ready to become a tender.
@immutable
class ScanDraft {
  const ScanDraft({
    required this.title,
    required this.buyer,
    required this.deadline,
    required this.country,
    required this.ocrText,
    this.requirements = const [],
    this.minTurnover,
    this.currency,
    this.cpvCodes = const [],
  });

  final String title;
  final String buyer;
  final DateTime? deadline;
  final String country;
  final String ocrText;
  final List<String> requirements;
  final double? minTurnover;
  final String? currency;
  final List<String> cpvCodes;

  /// What still blocks saving, by the field the form shows it under.
  Map<ScanField, String> get fieldProblems => {
    if (title.trim().isEmpty) ScanField.title: 'Add a title.',
    if (buyer.trim().isEmpty) ScanField.buyer: 'Confirm the buyer.',
    if (deadline == null) ScanField.deadline: 'Confirm the deadline.',
    if (ocrText.trim().length < 40)
      ScanField.text: 'No readable text. Retake the photo.',
  };

  /// What still blocks saving, in the order the form shows it.
  List<String> get problems => fieldProblems.values.toList();

  /// The scanned notice as a [Tender]. The OCR text is the notice text, so
  /// the AI's quotes are checked against what was actually printed. The id
  /// comes from the text, so scanning the same page twice is a duplicate.
  Tender toTender(DateTime now) {
    final hash = TextUtils.hash(ocrText);
    return Tender(
      source: TenderSourceType.scan,
      sourceId: hash.substring(0, 16),
      title: title.trim(),
      buyer: buyer.trim(),
      country: country,
      cpvCodes: cpvCodes,
      deadline: deadline?.toUtc(),
      minTurnover: minTurnover,
      currency: currency,
      noticeText: ocrText,
      textHash: hash,
      fetchedAt: now.toUtc(),
    );
  }
}
