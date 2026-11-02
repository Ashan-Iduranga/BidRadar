import 'dart:async';

import '../../core/logging/log.dart';
import '../../data/models/models.dart';
import 'ai_model.dart';
import 'guards.dart';
import 'quote_verifier.dart';

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
  }) async {
    final now = _clock().toUtc();
    if (!rules.passed) return rulesVerdict(company.id, tender, rules, now);

    var failures = 0;
    var quoteRetried = false;
    var badAnswers = 0;
    Object? lastError;

    while (true) {
      final AiVerdictPayload payload;
      try {
        payload = await model
            .judgeTender(company: company, profile: profile, tender: tender)
            .timeout(timeout);
      } on FormatException catch (e) {
        // Malformed answer: ask once more, then give up.
        Log.warn('agent', 'bad AI answer: ${e.message}');
        if (++badAnswers > 1) {
          return _unavailable(company, tender, rules, now, 'invalid answer');
        }
        continue;
      } on Object catch (e) {
        lastError = e;
        Log.warn('agent', 'AI call failed (${failures + 1}): $e');
        if (++failures > maxRetries) {
          return _unavailable(company, tender, rules, now, _reason(lastError));
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
        return _copy(
          base,
          status: VerdictStatus.quotesRejected,
          note:
              '${check.failed.length} quote(s) could not be found in the '
              'notice, so the AI answer is not trusted.',
        );
      }
      final g = guards.apply(
        aiVerdict: payload.verdict,
        fitScore: payload.fitScore,
        confidence: payload.confidence,
        criteria: check.criteria,
        rules: rules,
      );
      return _copy(base, verdict: g.verdict, note: g.reason);
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

  Verdict _unavailable(
    Company c,
    Tender t,
    RulesResult r,
    DateTime at,
    String why,
  ) => Verdict(
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
    note: 'AI unavailable ($why). Decide manually.',
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

  static String _reason(Object? e) {
    final s = '$e';
    if (e is TimeoutException) return 'timed out';
    if (s.contains('QuotaExceeded') || s.contains('quota')) {
      return 'daily AI quota used up';
    }
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'no connection';
    }
    return 'service error';
  }
}
