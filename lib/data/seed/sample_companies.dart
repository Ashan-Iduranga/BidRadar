import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// One of the 3 synthetic companies in `assets/seed/sample_companies.json`.
class SampleCompany {
  const SampleCompany(this.company, this.profile);
  final Company company;
  final CompanyProfile profile;
}

abstract final class SampleCompanies {
  static const asset = 'assets/seed/sample_companies.json';

  static List<SampleCompany> parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return [
      for (final e in json['companies'] as List)
        SampleCompany(
          Company.fromJson(
            (e as Map<String, dynamic>)['company'] as Map<String, dynamic>,
          ),
          CompanyProfile.fromJson(e['profile'] as Map<String, dynamic>),
        ),
    ];
  }

  static Future<List<SampleCompany>> load([AssetBundle? bundle]) async =>
      parse(await (bundle ?? rootBundle).loadString(asset));
}
