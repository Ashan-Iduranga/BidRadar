import '../../data/models/models.dart';

/// Raw, unverified verdict exactly as the AI returned it. The BidAgent turns
/// this into a [Verdict] only after validation, quote checking and guards.
class AiVerdictPayload {
  const AiVerdictPayload({
    required this.verdict,
    required this.fitScore,
    required this.confidence,
    required this.criteria,
    required this.missingDocs,
    this.clarificationQuestion,
  });

  final VerdictKind verdict;
  final int fitScore;
  final double confidence;
  final List<Criterion> criteria;
  final List<String> missingDocs;
  final String? clarificationQuestion;

  /// Throws [FormatException] on any malformed field, so the agent can reject
  /// the response and retry once.
  factory AiVerdictPayload.fromJson(Map<String, dynamic> j) {
    final score = j['fitScore'];
    final conf = j['confidence'];
    if (score is! int || score < 0 || score > 100) {
      throw FormatException('fitScore out of range: $score');
    }
    if (conf is! num || conf < 0 || conf > 1) {
      throw FormatException('confidence out of range: $conf');
    }
    return AiVerdictPayload(
      verdict: VerdictKind.fromWire(j['verdict'] as String),
      fitScore: score,
      confidence: conf.toDouble(),
      criteria: (j['criteria'] as List)
          .map((e) => Criterion.fromJson(e as Map<String, dynamic>))
          .toList(),
      missingDocs: List<String>.from(j['missingDocs'] as List),
      clarificationQuestion: j['clarificationQuestion'] as String?,
    );
  }
}

/// The one seam between BidRadar and any language model (architecture doc
/// §20: swappable model). Production uses Gemini via Firebase AI Logic; tests
/// use a fake that can, for example, always answer BID to prove the rules win.
abstract interface class AiModel {
  /// Model identifier stored on every verdict for the audit trail.
  String get modelName;

  /// Judge [tender] for [profile]. Implementations must enforce the 20 s
  /// timeout and throw on failure; retries live in the BidAgent.
  Future<AiVerdictPayload> judgeTender({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
  });
}
