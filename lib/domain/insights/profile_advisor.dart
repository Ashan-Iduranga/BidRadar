import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../agent/gemini_factory.dart';
import '../agent/gemini_model.dart';

enum SuggestionKind {
  addSector('add_sector'),
  addCountry('add_country'),
  addCertification('add_certification'),
  other('other');

  const SuggestionKind(this.wire);
  final String wire;
  static SuggestionKind fromWire(String w) =>
      values.firstWhere((v) => v.wire == w, orElse: () => SuggestionKind.other);
}

/// One proposed profile change. The owner decides; nothing is applied
/// automatically.
@immutable
class ProfileSuggestion {
  const ProfileSuggestion({
    required this.kind,
    required this.value,
    required this.reason,
  });

  final SuggestionKind kind;

  /// CPV code, alpha-3 country, certification name, or free text.
  final String value;
  final String reason;

  bool get applicable => kind != SuggestionKind.other;

  /// True when the profile already has what this suggests (models sometimes
  /// propose what is already there).
  bool alreadyIn(CompanyProfile p) => switch (kind) {
    SuggestionKind.addSector => p.cpvCodes.contains(
      value.replaceAll(' ', '').split('-').first,
    ),
    SuggestionKind.addCountry => p.countries.contains(value.toUpperCase()),
    SuggestionKind.addCertification => p.certifications.any(
      (c) => c.toLowerCase() == value.toLowerCase(),
    ),
    SuggestionKind.other => false,
  };

  factory ProfileSuggestion.fromJson(Map<String, dynamic> j) =>
      ProfileSuggestion(
        kind: SuggestionKind.fromWire(j['kind'] as String? ?? ''),
        value: (j['value'] as String? ?? '').trim(),
        reason: (j['reason'] as String? ?? '').trim(),
      );
}

/// Suggests profile changes from lost bids (swappable, like AiModel).
abstract interface class ProfileAdvisor {
  Future<List<ProfileSuggestion>> suggest({
    required Company company,
    required CompanyProfile profile,
    required List<Bid> lostBids,
  });
}

final Schema profileSuggestionsSchema = Schema.object(
  properties: {
    'suggestions': Schema.array(
      items: Schema.object(
        properties: {
          'kind': Schema.enumString(
            enumValues: [for (final k in SuggestionKind.values) k.wire],
          ),
          'value': Schema.string(
            description:
                'add_sector: 8-digit CPV code. add_country: ISO 3166-1 '
                'alpha-3. add_certification: certificate name. other: the '
                'advice.',
          ),
          'reason': Schema.string(
            description: 'One sentence linking it to the lost bids.',
          ),
        },
      ),
    ),
  },
);

class GeminiProfileAdvisor implements ProfileAdvisor {
  GeminiProfileAdvisor({GeminiClient? client})
    : _model =
          client ??
          GeminiFactory.create(
            model: GeminiModel.defaultModel,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              responseSchema: profileSuggestionsSchema,
              temperature: 0.2,
            ),
          );

  final GeminiClient _model;

  static String buildPrompt(
    Company company,
    CompanyProfile profile,
    List<Bid> lost,
  ) => [
    'A small firm lost these public tenders. Suggest at most 4 concrete '
        'changes to its profile that would have helped, or that would stop '
        'it chasing tenders it cannot win. Do not invent facts about the '
        'firm; suggest, do not assume.',
    '',
    'PROFILE: sectors ${profile.cpvCodes}, countries ${profile.countries}, '
        'certifications ${profile.certifications}, turnover '
        '${company.annualTurnover} ${company.currency}, team ${company.teamSize}.',
    '',
    'LOST BIDS:',
    for (final b in lost)
      '- ${b.title} (buyer ${b.buyer}); reasons: '
          '${b.lossReasons.isEmpty ? 'not given' : b.lossReasons.join(', ')}',
  ].join('\n');

  @override
  Future<List<ProfileSuggestion>> suggest({
    required Company company,
    required CompanyProfile profile,
    required List<Bid> lostBids,
  }) async {
    final res = await _model
        .generateContent([
          Content.text(buildPrompt(company, profile, lostBids)),
        ])
        .timeout(const Duration(seconds: 30));
    final j = jsonDecode(res.text ?? '{}') as Map<String, dynamic>;
    return [
      for (final s in (j['suggestions'] as List? ?? const []))
        if (s is Map<String, dynamic>) ProfileSuggestion.fromJson(s),
    ].where((s) => s.value.isNotEmpty).take(4).toList();
  }
}
