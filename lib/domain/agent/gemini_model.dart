import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../../core/geo/countries.dart';
import '../../data/models/models.dart';
import 'ai_model.dart';
import 'verdict_schema.dart';

/// Gemini through Firebase AI Logic (Gemini Developer API, free tier).
/// App Check protects the calls, so no API key ships in the APK.
class GeminiModel implements AiModel {
  GeminiModel({GenerativeModel? model, this.modelName = defaultModel})
    : _model =
          model ??
          FirebaseAI.googleAI().generativeModel(
            model: modelName,
            systemInstruction: Content.system(systemPrompt),
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              responseSchema: bidVerdictSchema,
              temperature: 0.1,
              // Extraction and matching need little deliberation; low
              // thinking keeps answers well inside the 20 s timeout.
              thinkingConfig: ThinkingConfig.withThinkingLevel(
                ThinkingLevel.low,
              ),
            ),
          );

  /// Free-tier model listed on https://firebase.google.com/docs/ai-logic/models
  /// (checked 2 Nov 2026). gemini-3.8-flash is also free but did not answer
  /// within 90 s on this project's free tier, while 3.5 Flash-Lite answers
  /// structured requests in about 2 s. Change it here only.
  static const defaultModel = 'gemini-3.5-flash-lite';

  /// Long notices are cut to keep requests inside free-tier limits.
  static const maxNoticeChars = 30000;

  @override
  final String modelName;
  final GenerativeModel _model;

  static const systemPrompt = '''
You are BidRadar's bid/no-bid analyst for small firms.
Decide whether the company should bid on the public tender.

Rules:
- Extract the tender's real eligibility and award criteria (experience,
  certifications, turnover, staff, location, deadlines, documents).
- For every criterion, "quote" must be text copied EXACTLY from the NOTICE,
  in the notice's own language, at least a few words long. Never paraphrase,
  translate, summarise or join separate passages. If you cannot quote it,
  leave the criterion out.
- "met" says whether the company meets it from its profile: yes, no, or
  unknown when the profile does not say.
- verdict: BID only if every criterion is "yes" and the work fits the
  company; NO_BID only if at least one criterion is "no"; otherwise REVIEW.
  If the work is outside the company's sectors, add a criterion for it that
  quotes the notice's description of the work, with "met": "no".
- fitScore 0-100: how well the work matches the company's sectors and past
  contracts. confidence 0.0-1.0: how sure you are of the verdict.
- missingDocs: documents the company would need to prepare.
- Write criterion labels, missingDocs and clarificationQuestion in English.
''';

  /// The user message. Pure, so it can be unit tested.
  static String buildPrompt({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
  }) {
    final notice = tender.noticeText.length > maxNoticeChars
        ? tender.noticeText.substring(0, maxNoticeChars)
        : tender.noticeText;
    final companyInfo = {
      'name': company.name,
      'registeredIn': Countries.nameOf(company.country),
      'annualTurnover': '${company.annualTurnover} ${company.currency}',
      'teamSize': company.teamSize,
      'cpvSectors': profile.cpvCodes,
      'deliversIn': profile.countries.map(Countries.nameOf).toList(),
      'certifications': profile.certifications,
      'pastContracts': [
        for (final p in profile.pastContracts)
          '${p.title} for ${p.buyer} (${p.year}, ${p.value})',
      ],
    };
    return [
      'COMPANY PROFILE (JSON):',
      const JsonEncoder.withIndent(' ').convert(companyInfo),
      '',
      'TENDER: ${tender.title}',
      'Buyer: ${tender.buyer}',
      if (tender.country.isNotEmpty)
        'Country: ${Countries.nameOf(tender.country)}',
      if (tender.deadline != null)
        'Deadline (UTC): ${tender.deadline!.toUtc().toIso8601String()}',
      if (tender.estimatedValue != null)
        'Estimated value: ${tender.estimatedValue} ${tender.currency ?? ''}',
      if (tender.cpvCodes.isNotEmpty) 'CPV: ${tender.cpvCodes.join(', ')}',
      '',
      'NOTICE (quote only from here):',
      '<<<',
      notice,
      '>>>',
    ].join('\n');
  }

  @override
  Future<AiVerdictPayload> judgeTender({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
  }) async {
    final res = await _model.generateContent([
      Content.text(
        buildPrompt(company: company, profile: profile, tender: tender),
      ),
    ]);
    final text = res.text;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Empty AI response');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response is not a JSON object');
    }
    return AiVerdictPayload.fromJson(decoded);
  }
}
