import 'package:flutter/foundation.dart';

import 'enums.dart';

/// One hard-rule failure.
@immutable
class RuleVeto {
  const RuleVeto({required this.rule, required this.message});

  final VetoRule rule;

  /// Human-readable reason shown on the tender card, e.g.
  /// "Deadline passed on 12 Oct 2026".
  final String message;

  factory RuleVeto.fromJson(Map<String, dynamic> j) => RuleVeto(
    rule: VetoRule.fromWire(j['rule'] as String),
    message: j['message'] as String,
  );

  Map<String, dynamic> toJson() => {'rule': rule.wire, 'message': message};
}

/// Output of EligibilityRules: pure facts checked in Dart before any AI call.
@immutable
class RulesResult {
  const RulesResult({required this.vetoes, this.warnings = const []});

  const RulesResult.pass() : vetoes = const [], warnings = const [];

  /// Any veto forces NO_BID. The AI is never asked.
  final List<RuleVeto> vetoes;

  /// Soft issues that do not veto but should push the verdict to REVIEW,
  /// e.g. "deadline unknown".
  final List<String> warnings;

  bool get passed => vetoes.isEmpty;

  factory RulesResult.fromJson(Map<String, dynamic> j) => RulesResult(
    vetoes: (j['vetoes'] as List)
        .map((e) => RuleVeto.fromJson(e as Map<String, dynamic>))
        .toList(),
    warnings: List<String>.from(j['warnings'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'passed': passed,
    'vetoes': vetoes.map((e) => e.toJson()).toList(),
    'warnings': warnings,
  };
}

/// One eligibility criterion the agent extracted, with its evidence.
@immutable
class Criterion {
  const Criterion({
    required this.criterion,
    required this.quote,
    required this.met,
    this.quoteVerified = false,
  });

  /// Short label, e.g. "Minimum 3 years' experience".
  final String criterion;

  /// Exact text copied from the notice.
  final String quote;
  final CriterionMet met;

  /// Set by QuoteVerifier, never by the AI.
  final bool quoteVerified;

  Criterion copyWith({bool? quoteVerified}) => Criterion(
    criterion: criterion,
    quote: quote,
    met: met,
    quoteVerified: quoteVerified ?? this.quoteVerified,
  );

  factory Criterion.fromJson(Map<String, dynamic> j) => Criterion(
    criterion: j['criterion'] as String,
    quote: j['quote'] as String,
    met: CriterionMet.fromWire(j['met'] as String),
    quoteVerified: j['quoteVerified'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'criterion': criterion,
    'quote': quote,
    'met': met.wire,
    'quoteVerified': quoteVerified,
  };
}

/// `verdicts/{id}`: a full audit record of one decision.
@immutable
class Verdict {
  const Verdict({
    required this.id,
    required this.tenderId,
    required this.companyId,
    required this.verdict,
    required this.fitScore,
    required this.criteria,
    required this.missingDocs,
    required this.rulesResult,
    required this.status,
    required this.model,
    required this.at,
    this.confidence,
    this.clarificationQuestion,
    this.note,
  });

  final String id;
  final String tenderId;
  final String companyId;
  final VerdictKind verdict;

  /// 0 to 100.
  final int fitScore;
  final List<Criterion> criteria;
  final List<String> missingDocs;
  final String? clarificationQuestion;

  /// 0.0 to 1.0, as reported by the AI. Low values force REVIEW.
  final double? confidence;
  final RulesResult rulesResult;
  final VerdictStatus status;

  /// Why the code changed or could not produce the AI's answer, e.g.
  /// "AI confidence is low (40%)." Shown next to the verdict.
  final String? note;

  /// Model name, or "rules" when the AI was never called.
  final String model;
  final DateTime at;

  factory Verdict.fromJson(Map<String, dynamic> j) => Verdict(
    id: j['id'] as String,
    tenderId: j['tenderId'] as String,
    companyId: j['companyId'] as String,
    verdict: VerdictKind.fromWire(j['verdict'] as String),
    fitScore: j['fitScore'] as int,
    criteria: (j['criteria'] as List)
        .map((e) => Criterion.fromJson(e as Map<String, dynamic>))
        .toList(),
    missingDocs: List<String>.from(j['missingDocs'] as List),
    clarificationQuestion: j['clarificationQuestion'] as String?,
    confidence: (j['confidence'] as num?)?.toDouble(),
    rulesResult: RulesResult.fromJson(j['rulesResult'] as Map<String, dynamic>),
    status: VerdictStatus.fromWire(j['status'] as String),
    model: j['model'] as String,
    at: DateTime.parse(j['at'] as String),
    note: j['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenderId': tenderId,
    'companyId': companyId,
    'verdict': verdict.wire,
    'fitScore': fitScore,
    'criteria': criteria.map((e) => e.toJson()).toList(),
    'missingDocs': missingDocs,
    'clarificationQuestion': clarificationQuestion,
    'confidence': confidence,
    'rulesResult': rulesResult.toJson(),
    'status': status.wire,
    'model': model,
    'at': at.toUtc().toIso8601String(),
    'note': note,
  };
}
