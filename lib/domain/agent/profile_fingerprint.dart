import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/models/models.dart';

/// A hash of what the AI is told about the company (see
/// `GeminiModel.buildPrompt`) and of the company facts the rules check. A
/// cached verdict is reused only while the fingerprint matches, so editing
/// the profile gets tenders judged again. Team members and roles are left
/// out: they do not change a verdict.
abstract final class ProfileFingerprint {
  static String of(Company company, CompanyProfile profile) {
    List<String> sorted(List<String> l) => [...l]..sort();
    final facts = {
      'name': company.name,
      'country': company.country,
      'annualTurnover': company.annualTurnover,
      'currency': company.currency,
      'teamSize': company.teamSize,
      'cpvCodes': sorted(profile.cpvCodes),
      'countries': sorted(profile.countries),
      'certifications': sorted(profile.certifications),
      'pastContracts': [for (final p in profile.pastContracts) p.toJson()],
    };
    return sha256.convert(utf8.encode(jsonEncode(facts))).toString();
  }
}
