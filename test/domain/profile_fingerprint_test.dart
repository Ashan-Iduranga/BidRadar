import 'package:bidradar/data/models/models.dart';
import 'package:bidradar/domain/agent/profile_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

const company = Company(
  id: 'c1',
  name: 'Lanka Code Works',
  country: 'LKA',
  annualTurnover: 850000,
  currency: 'EUR',
  teamSize: 28,
  ownerUid: 'u1',
);

const profile = CompanyProfile(
  companyId: 'c1',
  cpvCodes: ['72000000', '48000000'],
  countries: ['LKA', 'MDV'],
  certifications: ['ISO 9001'],
);

void main() {
  final base = ProfileFingerprint.of(company, profile);

  test('changes when what the AI is told changes', () {
    const moreCerts = CompanyProfile(
      companyId: 'c1',
      cpvCodes: ['72000000', '48000000'],
      countries: ['LKA', 'MDV'],
      certifications: ['ISO 9001', 'ISO 27001'],
    );
    const lessCountries = CompanyProfile(
      companyId: 'c1',
      cpvCodes: ['72000000', '48000000'],
      countries: ['LKA'],
      certifications: ['ISO 9001'],
    );
    const richer = Company(
      id: 'c1',
      name: 'Lanka Code Works',
      country: 'LKA',
      annualTurnover: 2000000,
      currency: 'EUR',
      teamSize: 28,
      ownerUid: 'u1',
    );
    expect(ProfileFingerprint.of(company, moreCerts), isNot(base));
    expect(ProfileFingerprint.of(company, lessCountries), isNot(base));
    expect(ProfileFingerprint.of(richer, profile), isNot(base));
  });

  test('ignores list order and team members', () {
    const reordered = CompanyProfile(
      companyId: 'c1',
      cpvCodes: ['48000000', '72000000'],
      countries: ['MDV', 'LKA'],
      certifications: ['ISO 9001'],
    );
    const withMember = Company(
      id: 'c1',
      name: 'Lanka Code Works',
      country: 'LKA',
      annualTurnover: 850000,
      currency: 'EUR',
      teamSize: 28,
      ownerUid: 'u1',
      members: {'u2': UserRole.bidManager},
    );
    expect(ProfileFingerprint.of(company, reordered), base);
    expect(ProfileFingerprint.of(withMember, profile), base);
  });
}
