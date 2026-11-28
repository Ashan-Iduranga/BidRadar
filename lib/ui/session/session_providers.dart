import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';

/// `users/{uid}.companyId` for the signed-in user.
final currentCompanyIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(companyRepositoryProvider).watchCompanyIdForUser(user.uid);
});

final currentCompanyProvider = StreamProvider<Company?>((ref) {
  final id = ref.watch(currentCompanyIdProvider).value;
  if (id == null) return Stream.value(null);
  return ref.watch(companyRepositoryProvider).watchCompany(id);
});

final currentProfileProvider = StreamProvider<CompanyProfile?>((ref) {
  final id = ref.watch(currentCompanyIdProvider).value;
  if (id == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(id);
});

/// The signed-in user's role in their company, or null.
final currentRoleProvider = Provider<UserRole?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  final company = ref.watch(currentCompanyProvider).value;
  if (uid == null || company == null) return null;
  return company.roleOf(uid);
});

enum Membership { loading, none, member }

/// Drives the router: wait while loading, onboard when there is no company.
final membershipProvider = Provider<Membership>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading && !auth.hasValue) return Membership.loading;
  final user = auth.value;
  if (user == null) return Membership.none;

  // isLoading, not hasValue: after sign-in these providers reload but keep
  // the signed-out value (null) until the new one arrives, which would
  // read as "no company" and flash onboarding.
  final id = ref.watch(currentCompanyIdProvider);
  if (id.hasError) return Membership.none;
  if (id.isLoading) return Membership.loading;
  if (id.value == null) return Membership.none;

  final company = ref.watch(currentCompanyProvider);
  // A permission error means the user doc points at a company they are not
  // a member of; treat it as no company.
  if (company.hasError) return Membership.none;
  if (company.isLoading) return Membership.loading;
  final c = company.value;
  return c != null && c.members.containsKey(user.uid)
      ? Membership.member
      : Membership.none;
});
