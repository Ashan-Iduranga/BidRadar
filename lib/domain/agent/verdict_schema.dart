import 'package:firebase_ai/firebase_ai.dart';

/// The Gemini response schema for a bid verdict. This is the agreed AI
/// contract (architecture doc §9). It must stay in sync with
/// `AiVerdictPayload.fromJson` in `ai_model.dart`; the test in
/// `test/domain/verdict_schema_test.dart` checks they agree.
final Schema bidVerdictSchema = Schema.object(
  properties: {
    'verdict': Schema.enumString(
      enumValues: ['BID', 'NO_BID', 'REVIEW'],
      description: 'BID only if every hard requirement is met with evidence.',
    ),
    'fitScore': Schema.integer(
      description: 'How well the tender fits the company, 0 to 100.',
    ),
    'confidence': Schema.number(
      description: 'Your confidence in the verdict, 0.0 to 1.0.',
    ),
    'criteria': Schema.array(
      items: Schema.object(
        properties: {
          'criterion': Schema.string(
            description: 'Short label, e.g. "Minimum 3 years experience".',
          ),
          'quote': Schema.string(
            description:
                'Text copied EXACTLY from the notice. Never paraphrase.',
          ),
          'met': Schema.enumString(enumValues: ['yes', 'no', 'unknown']),
        },
      ),
    ),
    'missingDocs': Schema.array(items: Schema.string()),
    'clarificationQuestion': Schema.string(
      description: 'One question to ask the buyer, if anything is unclear.',
    ),
  },
  optionalProperties: ['clarificationQuestion'],
);

/// The Gemini response schema for reading a scanned notice. Must stay in
/// sync with `ScannedNotice.fromJson`.
final Schema scannedNoticeSchema = Schema.object(
  properties: {
    'title': Schema.string(description: 'What is being bought, in English.'),
    'buyer': Schema.string(description: 'The buying organisation.'),
    'deadline': Schema.string(
      description:
          'Submission deadline as ISO 8601 local date-time without a time '
          'zone, e.g. 2026-11-28T14:00:00. Empty if not stated.',
    ),
    'country': Schema.string(
      description: 'ISO 3166-1 alpha-3 code of the buyer country, or empty.',
    ),
    'requirements': Schema.array(
      items: Schema.string(),
      description: 'Eligibility requirements, copied as printed.',
    ),
    'minTurnover': Schema.number(
      description: 'Minimum annual turnover required, if stated.',
    ),
    'currency': Schema.string(
      description: 'ISO 4217 currency of minTurnover, e.g. LKR.',
    ),
    'cpvCodes': Schema.array(
      items: Schema.string(),
      description: '8-digit CPV codes ONLY if printed on the notice.',
    ),
  },
  optionalProperties: ['minTurnover', 'currency', 'cpvCodes'],
);
