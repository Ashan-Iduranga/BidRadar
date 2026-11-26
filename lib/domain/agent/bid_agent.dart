import 'dart:async';

import '../../core/logging/log.dart';
import '../../data/models/models.dart';
import 'ai_failure.dart';
import 'ai_model.dart';
import 'guards.dart';
import 'quote_verifier.dart';

/// A verdict plus, when the AI gave no usable answer, why not.
class AgentOutcome {
  const AgentOutcome(this.verdict, [this.failure]);
  final Verdict verdict;

  /// Null when the AI answered (accepted or quotes rejected) or the rules
  /// decided without it.
  final AiFailure? failure;
}

/// Turns a tender into an audited [Verdict]:
/// rules veto → NO_BID without calling the AI; otherwise ask the model
/// (20 s timeout, 2 retries on failure), verify every quote (one retry if a
/// quote is not in the notice), then apply the guards.
class BidAgent {
  BidAgent({
    required this.model,
    this.verifier = const QuoteVerifier(),
    this.guards = const VerdictGuards(),
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 2,
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
  }) : _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  final AiModel model;
  final QuoteVerifier verifier;
  final VerdictGuards guards;
  final Duration timeout;
  final int maxRetries;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _sleep;

  Future<Verdict> judge({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    required RulesResult rules,
  }) async => (await assess(
    company: company,
    profile: profile,
    tender: tender,
    rules: rules,
  )).verdict;

  /// Like [judge], and also says why the AI gave no usable answer, so the
  /// sync can tell a problem with one notice from one that affects all.
  Future<AgentOutcome> assess({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    required RulesResult rules,
  }) async {
    final now = _clock().toUtc();
    if (!rules.passed) {
      return AgentOutcome(rulesVerdict(company.id, tender, rules, now));
    }

    var failures = 0;
    var quoteRetried = false;
    var badAnswers = 0;

    while (true) {
      final AiVerdictPayload payload;
      try {
        payload = await model
            .judgeTender(company: company, profile: profile, tender: tender)
            .timeout(timeout);
      } on Object catch (e) {
        final kind = AiFailure.of(e);
        if (kind == AiFailure.notice) {
          // Malformed or blocked answer: ask once more, then give up on this
          // notice only.
          Log.warn('agent', 'unusable AI answer: $e');
          if (++badAnswers > 1) {
            return _unavailable(company, tender, rules, now, kind, e);
          }
          continue;
        }
        Log.warn('agent', 'AI call failed (${failures + 1}): $e');
        if (++failures > maxRetries) {
          return _unavailable(company, tender, rules, now, kind, e);
        }
        await _sleep(Duration(seconds: failures));
        continue;
      }

      final check = verifier.check(payload.criteria, tender.noticeText);
      if (!check.allVerified && !quoteRetried) {
        Log.warn(
          'agent',
          '${check.failed.length} quote(s) not in the notice; retrying once',
        );
        quoteRetried = true;
        continue;
      }

      final base = Verdict(
        id: 'ai_${company.id}_${tender.id}_${now.millisecondsSinceEpoch}',
        tenderId: tender.id,
        companyId: company.id,
        verdict: VerdictKind.review,
        fitScore: payload.fitScore,
        confidence: payload.confidence,
        criteria: check.criteria,
        missingDocs: payload.missingDocs,
        clarificationQuestion: payload.clarificationQuestion,
        rulesResult: rules,
        status: VerdictStatus.accepted,
        model: model.modelName,
        at: now,
      );

      if (!check.allVerified) {
        // Twice unverifiable: a person must read the notice.
        return AgentOutcome(
          _copy(
            base,
            status: VerdictStatus.quotesRejected,
            note:
                '${check.failed.length} quote(s) could not be found in the '
                'notice, so the AI answer is not trusted.',
          ),
        );
      }
      final g = guards.apply(
        aiVerdict: payload.verdict,
        fitScore: payload.fitScore,
        confidence: payload.confidence,
        criteria: check.criteria,
        rules: rules,
      );
      return AgentOutcome(_copy(base, verdict: g.verdict, note: g.reason));
    }
  }

  /// The audit record for a tender the rules removed. Deterministic ID, so
  /// the same tender is never recorded twice.
  static Verdict rulesVerdict(
    String companyId,
    Tender t,
    RulesResult r,
    DateTime at,
  ) => Verdict(
    id: 'rules_${companyId}_${t.id}',
    tenderId: t.id,
    companyId: companyId,
    verdict: VerdictKind.noBid,
    fitScore: 0,
    criteria: const [],
    missingDocs: const [],
    rulesResult: r,
    status: VerdictStatus.rulesVeto,
    model: 'rules',
    at: at,
    note: r.vetoes.first.message,
  );

  AgentOutcome _unavailable(
    Company c,
    Tender t,
    RulesResult r,
    DateTime at,
    AiFailure kind,
    Object error,
  ) => AgentOutcome(
    Verdict(
      id: 'ai_${c.id}_${t.id}_${at.millisecondsSinceEpoch}',
      tenderId: t.id,
      companyId: c.id,
      verdict: VerdictKind.review,
      fitScore: 0,
      criteria: const [],
      missingDocs: const [],
      rulesResult: r,
      status: VerdictStatus.aiUnavailable,
      model: model.modelName,
      at: at,
      note:
          'AI unavailable (${AiFailure.reason(kind, error)}). '
          'Decide manually.',
    ),
    kind,
  );

  static Verdict _copy(
    Verdict v, {
    VerdictKind? verdict,
    VerdictStatus? status,
    String? note,
  }) => Verdict(
    id: v.id,
    tenderId: v.tenderId,
    companyId: v.companyId,
    verdict: verdict ?? v.verdict,
    fitScore: v.fitScore,
    confidence: v.confidence,
    criteria: v.criteria,
    missingDocs: v.missingDocs,
    clarificationQuestion: v.clarificationQuestion,
    rulesResult: v.rulesResult,
    status: status ?? v.status,
    model: v.model,
    at: v.at,
    note: note ?? v.note,
  );
}
