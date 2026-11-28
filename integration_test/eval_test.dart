// O2 evaluation harness. Runs the real pipeline (rules → Gemini → quote
// verification → guards) on the 50 frozen notices, on a device:
//
//   flutter test integration_test/eval_test.dart -d emulator-5554
//
// Each notice prints one `EVAL_RESULT {json}` line; tool/eval/report.py
// turns them (plus the human labels) into eval/REPORT.md.
import 'dart:convert';

import 'package:bidradar/core/firebase/firebase_bootstrap.dart';
import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/data/seed/sample_companies.dart';
import 'package:bidradar/domain/agent/ai_model.dart';
import 'package:bidradar/domain/agent/bid_agent.dart';
import 'package:bidradar/domain/agent/gemini_model.dart';
import 'package:bidradar/domain/agent/quote_verifier.dart';
import 'package:bidradar/domain/rules/eligibility_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'eval_data.dart';

/// Returns a recorded first answer, then asks the real model (retries).
class _FirstThenReal implements AiModel {
  _FirstThenReal(this._first, this._real);
  AiVerdictPayload? _first;
  final AiModel _real;

  @override
  String get modelName => _real.modelName;

  @override
  Future<AiVerdictPayload> judgeTender({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    List<String> rejectedQuotes = const [],
  }) {
    final f = _first;
    if (f != null) {
      _first = null;
      return Future.value(f);
    }
    return _real.judgeTender(
      company: company,
      profile: profile,
      tender: tender,
      rejectedQuotes: rejectedQuotes,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('O2 evaluation on 50 real notices', (tester) async {
    expect(await initFirebase(), isTrue, reason: 'Firebase must be set up');
    final samples = {
      for (final s in await SampleCompanies.load()) s.company.id: s,
    };
    final data = jsonDecode(
      utf8.decode(base64Decode(evalDatasetBase64)),
    ) as Map<String, dynamic>;
    final items = data['items'] as List;
    final model = GeminiModel();
    const rules = EligibilityRules();
    const verifier = QuoteVerifier();
    final now = DateTime.now();

    for (final (i, raw) in items.indexed) {
      final item = raw as Map<String, dynamic>;
      final s = samples[item['profile']]!;
      final t = Tender.fromJson(item['tender'] as Map<String, dynamic>);
      final r = rules.check(
        company: s.company,
        profile: s.profile,
        tender: t,
        now: now,
      );
      final out = <String, Object?>{
        'n': i + 1,
        'profile': s.company.id,
        'tender_id': t.id,
        'rules_passed': r.passed,
        'vetoes': [for (final v in r.vetoes) v.rule.wire],
        'warnings': r.warnings.length,
      };

      if (r.passed) {
        // 1. One raw call: quote accuracy before verification.
        try {
          final watch = Stopwatch()..start();
          final first = await model
              .judgeTender(company: s.company, profile: s.profile, tender: t)
              .timeout(const Duration(seconds: 30));
          out['latency_ms'] = watch.elapsedMilliseconds;
          final check = verifier.check(first.criteria, t.noticeText);
          out['raw_verdict'] = first.verdict.wire;
          out['raw_quotes'] = first.criteria.length;
          out['raw_quotes_verified'] = check.criteria
              .where((c) => c.quoteVerified)
              .length;

          // 2. The full agent, reusing that answer (no extra call unless a
          // retry is needed).
          final v = await BidAgent(
            model: _FirstThenReal(first, model),
          ).judge(company: s.company, profile: s.profile, tender: t, rules: r);
          out['final_verdict'] = v.verdict.wire;
          out['status'] = v.status.wire;
          out['fit'] = v.fitScore;
          out['confidence'] = v.confidence;
          out['final_quotes'] = v.criteria.length;
          out['final_quotes_verified'] = v.criteria
              .where((c) => c.quoteVerified)
              .length;
          out['note'] = v.note;
        } on Object catch (e) {
          out['final_verdict'] = 'REVIEW';
          out['status'] = 'error';
          out['note'] = '$e';
        }
        // Stay well inside the free-tier rate limit.
        await Future<void>.delayed(const Duration(seconds: 2));
      } else {
        out['final_verdict'] = 'NO_BID';
        out['status'] = 'rules_veto';
      }
      // ignore: avoid_print
      print('EVAL_RESULT ${jsonEncode(out)}');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
