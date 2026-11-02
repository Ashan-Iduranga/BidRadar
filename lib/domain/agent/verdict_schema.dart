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

/// The Gemini response schema for reading a scanned notice.
final Schema scannedNoticeSchema = Schema.object(
  properties: {
    'title': Schema.string(),
    'buyer': Schema.string(),
    'deadline': Schema.string(
      description: 'ISO 8601 date-time, or empty if not stated.',
    ),
    'country': Schema.string(description: 'ISO 3166-1 alpha-3 code.'),
    'requirements': Schema.array(items: Schema.string()),
  },
);
