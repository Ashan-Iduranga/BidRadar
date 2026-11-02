import 'package:flutter/foundation.dart';

import 'enums.dart';

/// `companies/{id}`. One company per account in this version.
@immutable
class Company {
  const Company({
    required this.id,
    required this.name,
    required this.country,
    required this.annualTurnover,
    required this.currency,
    required this.teamSize,
    required this.ownerUid,
    this.members = const {},
  });

  final String id;
  final String name;

  /// ISO 3166-1 alpha-3, e.g. "LKA".
  final String country;
  final double annualTurnover;

  /// ISO 4217, e.g. "EUR".
  final String currency;
  final int teamSize;
  final String ownerUid;

  /// uid → role. Security rules read this map.
  final Map<String, UserRole> members;

  factory Company.fromJson(Map<String, dynamic> j) => Company(
    id: j['id'] as String,
    name: j['name'] as String,
    country: j['country'] as String,
    annualTurnover: (j['annualTurnover'] as num).toDouble(),
    currency: j['currency'] as String,
    teamSize: j['teamSize'] as int,
    ownerUid: j['ownerUid'] as String,
    members: ((j['members'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, UserRole.fromWire(v as String)),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'annualTurnover': annualTurnover,
    'currency': currency,
    'teamSize': teamSize,
    'ownerUid': ownerUid,
    'members': members.map((k, v) => MapEntry(k, v.wire)),
  };
}

@immutable
class PastContract {
  const PastContract({
    required this.title,
    required this.buyer,
    required this.year,
    required this.value,
    this.cpvCodes = const [],
  });

  final String title;
  final String buyer;
  final int year;
  final double value;
  final List<String> cpvCodes;

  factory PastContract.fromJson(Map<String, dynamic> j) => PastContract(
    title: j['title'] as String,
    buyer: j['buyer'] as String,
    year: j['year'] as int,
    value: (j['value'] as num).toDouble(),
    cpvCodes: List<String>.from(j['cpvCodes'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'buyer': buyer,
    'year': year,
    'value': value,
    'cpvCodes': cpvCodes,
  };
}

/// `profiles/{companyId}`. Used by EligibilityRules and the BidAgent.
@immutable
class CompanyProfile {
  const CompanyProfile({
    required this.companyId,
    required this.cpvCodes,
    required this.countries,
    this.certifications = const [],
    this.pastContracts = const [],
  });

  final String companyId;

  /// CPV codes (8 digits, no check digit), e.g. "72000000". A tender matches
  /// a profile code when they share the code's non-zero prefix.
  final List<String> cpvCodes;

  /// ISO 3166-1 alpha-3 countries the firm can deliver in.
  final List<String> countries;
  final List<String> certifications;
  final List<PastContract> pastContracts;

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
    companyId: j['companyId'] as String,
    cpvCodes: List<String>.from(j['cpvCodes'] as List),
    countries: List<String>.from(j['countries'] as List),
    certifications: List<String>.from(j['certifications'] as List? ?? const []),
    pastContracts: (j['pastContracts'] as List? ?? const [])
        .map((e) => PastContract.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'companyId': companyId,
    'cpvCodes': cpvCodes,
    'countries': countries,
    'certifications': certifications,
    'pastContracts': pastContracts.map((e) => e.toJson()).toList(),
  };
}
