import 'package:flutter/foundation.dart';

import 'enums.dart';

/// `tenders/{source}_{sourceId}`. Also cached locally in drift.
@immutable
class Tender {
  const Tender({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.buyer,
    required this.country,
    required this.cpvCodes,
    required this.noticeText,
    required this.textHash,
    required this.fetchedAt,
    this.deadline,
    this.estimatedValue,
    this.currency,
    this.minTurnover,
    this.url,
    this.documentUrls = const [],
  });

  final TenderSourceType source;

  /// The ID used by the source, e.g. TED publication number "612345-2026".
  final String sourceId;
  final String title;
  final String buyer;

  /// ISO 3166-1 alpha-3.
  final String country;
  final List<String> cpvCodes;

  /// Null means "deadline unknown"; rules then route the tender to REVIEW.
  final DateTime? deadline;
  final double? estimatedValue;
  final String? currency;

  /// Minimum annual turnover stated in the notice, if any.
  final double? minTurnover;

  /// Plain notice text. The QuoteVerifier checks every AI quote against it.
  final String noticeText;

  /// SHA-256 of the normalised notice text, for dedup and verdict caching.
  final String textHash;
  final String? url;
  final List<String> documentUrls;
  final DateTime fetchedAt;

  /// Stable document ID, unique across sources.
  String get id => '${source.wire}_$sourceId';

  factory Tender.fromJson(Map<String, dynamic> j) => Tender(
    source: TenderSourceType.fromWire(j['source'] as String),
    sourceId: j['sourceId'] as String,
    title: j['title'] as String,
    buyer: j['buyer'] as String,
    country: j['country'] as String,
    cpvCodes: List<String>.from(j['cpvCodes'] as List),
    deadline: _date(j['deadline']),
    estimatedValue: (j['estimatedValue'] as num?)?.toDouble(),
    currency: j['currency'] as String?,
    minTurnover: (j['minTurnover'] as num?)?.toDouble(),
    noticeText: j['noticeText'] as String,
    textHash: j['textHash'] as String,
    url: j['url'] as String?,
    documentUrls: List<String>.from(j['documentUrls'] as List? ?? const []),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'source': source.wire,
    'sourceId': sourceId,
    'title': title,
    'buyer': buyer,
    'country': country,
    'cpvCodes': cpvCodes,
    'deadline': deadline?.toUtc().toIso8601String(),
    'estimatedValue': estimatedValue,
    'currency': currency,
    'minTurnover': minTurnover,
    'noticeText': noticeText,
    'textHash': textHash,
    'url': url,
    'documentUrls': documentUrls,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
