import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/agent/ai_model.dart';
import 'package:bidradar/domain/agent/verdict_schema.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _valid() => {
  'verdict': 'BID',
  'fitScore': 82,
  'confidence': 0.9,
  'criteria': [
    {'criterion': 'Experience', 'quote': '3 years', 'met': 'yes'},
  ],
  'missingDocs': <String>[],
};

void main() {
  test('Gemini schema fields match what AiVerdictPayload reads', () {
    final props = (bidVerdictSchema.toJson()['properties'] as Map).keys.toSet();
    expect(props, {
      'verdict',
      'fitScore',
      'confidence',
      'criteria',
      'missingDocs',
      'clarificationQuestion',
    });
  });

  test('a well-formed AI response parses', () {
    final p = AiVerdictPayload.fromJson(_valid());
    expect(p.verdict, VerdictKind.bid);
    expect(p.criteria.single.met, CriterionMet.yes);
    // The AI can never mark its own quotes as verified.
    expect(p.criteria.single.quoteVerified, isFalse);
  });

  group('malformed AI responses are rejected', () {
    test('fitScore above 100', () {
      expect(
        () => AiVerdictPayload.fromJson(_valid()..['fitScore'] = 140),
        throwsFormatException,
      );
    });

    test('confidence outside 0..1', () {
      expect(
        () => AiVerdictPayload.fromJson(_valid()..['confidence'] = 1.5),
        throwsFormatException,
      );
    });

    test('unknown verdict value', () {
      expect(
        () => AiVerdictPayload.fromJson(_valid()..['verdict'] = 'MAYBE'),
        throwsFormatException,
      );
    });
  });
}
