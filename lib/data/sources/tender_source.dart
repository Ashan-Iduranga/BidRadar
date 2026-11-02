import '../models/models.dart';

/// What to ask a source for. Built from the company profile.
class TenderQuery {
  const TenderQuery({
    required this.cpvCodes,
    required this.countries,
    this.limit = 50,
  });

  factory TenderQuery.fromProfile(CompanyProfile p, {int limit = 50}) =>
      TenderQuery(cpvCodes: p.cpvCodes, countries: p.countries, limit: limit);

  /// 8-digit CPV codes.
  final List<String> cpvCodes;

  /// ISO 3166-1 alpha-3 codes.
  final List<String> countries;
  final int limit;
}

/// A public tender feed. Implementations map the source's JSON to [Tender]
/// and never throw on a single malformed notice: they skip it and log.
abstract interface class TenderSource {
  TenderSourceType get type;

  /// Throws NetworkException when the source cannot be reached.
  Future<List<Tender>> search(TenderQuery query);
}

/// Thrown when a source answers but the payload is not what we expect.
class SourceFormatException implements Exception {
  SourceFormatException(this.source, this.message);
  final TenderSourceType source;
  final String message;
  @override
  String toString() => 'SourceFormatException(${source.wire}): $message';
}
