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
/// (20 s timeout per call), verify every quote, then apply the guards.
/// A tender gets at most [maxCalls] model calls in total, shared by every
/// kind of retry: a failed call, a malformed answer (one retry) and quotes
/// not found in the notice (one retry that names them).
class BidAgent {
  BidAgent({
    required this.model,
    this.verifier = const QuoteVerifier(),
    this.guards = const VerdictGuards(),
    this.timeout = const Duration(seconds: 20),
    this.maxCalls = 3,
    DateTime Function()? clock,
    Future<void> Function(Duration)? sleep,
  }) : _clock = clock ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  final AiModel model;
  final QuoteVerifier verifier;
  final VerdictGuards guards;

  /// Per call. A timed-out request cannot be cancelled and still counts
  /// against the quota, which is one reason the calls are capped.
  final Duration timeout;

  /// Most model calls for one tender, across all retries.
  final int maxCalls;
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

    var calls = 0;
    var badAnswers = 0;
    var quoteRetried = false;
    var rejected = const <String>[];
    AiFailure? lastKind;
    Object? lastError;
    // The latest answer whose quotes were not all found in the notice.
    (AiVerdictPayload, QuoteCheck)? unverified;

    while (calls < maxCalls) {
      // Back off after a failed call; a malformed answer is retried at once.
      if (lastKind != null && lastKind != AiFailure.notice) {
        await _sleep(Duration(seconds: calls));
      }
      calls++;
      final AiVerdictPayload payload;
      try {
        payload = await model
            .judgeTender(
              company: company,
              profile: profile,
              tender: tender,
              rejectedQuotes: rejected,
            )
            .timeout(timeout);
      } on Object catch (e) {
        final kind = AiFailure.of(e);
        lastKind = kind;
        lastError = e;
        Log.warn('agent', 'AI call $calls failed (${kind.name}): $e');
        // A quota, request limit or refused access will not clear in a few
        // seconds, so retrying now only wastes a call.
        if (kind == AiFailure.dailyQuota ||
            kind == AiFailure.rateLimit ||
            kind == AiFailure.auth) {
          break;
        }
        // A malformed or blocked answer gets one more try.
        if (kind == AiFailure.notice && ++badAnswers > 1) break;
        continue;
      }
      lastKind = null;

      final check = verifier.check(payload.criteria, tender.noticeText);
      if (check.allVerified) {
        final g = guards.apply(
          aiVerdict: payload.verdict,
          fitScore: payload.fitScore,
          confidence: payload.confidence,
          criteria: check.criteria,
          rules: rules,
        );
        final v = _answer(company, tender, rules, now, payload, check);
        return AgentOutcome(_copy(v, verdict: g.verdict, note: g.reason));
      }
      unverified = (payload, check);
      if (quoteRetried) break;
      Log.warn(
        'agent',
        '${check.failed.length} quote(s) not in the notice; retrying once',
      );
      quoteRetried = true;
      rejected = [for (final c in check.failed) c.quote];
    }

    // An answer whose quotes are not in the notice is still an answer: a
    // person must read the notice before trusting it.
    if (unverified case (final payload, final check)) {
      final v = _answer(company, tender, rules, now, payload, check);
      return AgentOutcome(
        _copy(
          v,
          status: VerdictStatus.quotesRejected,
          note:
              '${check.failed.length} quote(s) could not be found in the '
              'notice, so the AI answer is not trusted.',
        ),
      );
    }
    return _unavailable(
      company,
      tender,
      rules,
      now,
      lastKind ?? AiFailure.service,
      lastError ?? 'no answer',
    );
  }

  /// An AI answer as an accepted REVIEW, before the guards decide.
  Verdict _answer(
    Company company,
    Tender tender,
    RulesResult rules,
    DateTime now,
    AiVerdictPayload payload,
    QuoteCheck check,
  ) => Verdict(
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
