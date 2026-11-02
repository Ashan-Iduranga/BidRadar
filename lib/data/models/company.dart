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
    this.memberEmails = const {},
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

  /// uid → email, for showing the team. Not used by security rules.
  final Map<String, String> memberEmails;

  UserRole? roleOf(String uid) => members[uid];

  Company copyWith({
    String? name,
    String? country,
    double? annualTurnover,
    String? currency,
    int? teamSize,
  }) => Company(
    id: id,
    name: name ?? this.name,
    country: country ?? this.country,
    annualTurnover: annualTurnover ?? this.annualTurnover,
    currency: currency ?? this.currency,
    teamSize: teamSize ?? this.teamSize,
    ownerUid: ownerUid,
    members: members,
    memberEmails: memberEmails,
  );

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
    memberEmails: ((j['memberEmails'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, v as String),
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
    'memberEmails': memberEmails,
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

  CompanyProfile copyWith({
    List<String>? cpvCodes,
    List<String>? countries,
    List<String>? certifications,
    List<PastContract>? pastContracts,
  }) => CompanyProfile(
    companyId: companyId,
    cpvCodes: cpvCodes ?? this.cpvCodes,
    countries: countries ?? this.countries,
    certifications: certifications ?? this.certifications,
    pastContracts: pastContracts ?? this.pastContracts,
  );

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

/// `invites/{email}`: lets the owner add a bid manager. The invited person
/// signs in with that email and accepts. Email is stored lower case.
@immutable
class Invite {
  const Invite({
    required this.email,
    required this.companyId,
    required this.companyName,
    required this.invitedBy,
    required this.createdAt,
    this.role = UserRole.bidManager,
  });

  final String email;
  final String companyId;
  final String companyName;
  final String invitedBy;
  final UserRole role;
  final DateTime createdAt;

  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
    email: j['email'] as String,
    companyId: j['companyId'] as String,
    companyName: j['companyName'] as String,
    invitedBy: j['invitedBy'] as String,
    role: UserRole.fromWire(j['role'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'companyId': companyId,
    'companyName': companyName,
    'invitedBy': invitedBy,
    'role': role.wire,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
