import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Companies, membership and invites. The page ViewModels depend on this
/// interface so tests can use a fake.
abstract interface class CompanyRepository {
  /// `users/{uid}.companyId`, or null when the user has no company yet.
  Stream<String?> watchCompanyIdForUser(String uid);

  Stream<Company?> watchCompany(String companyId);

  /// Creates the company with the caller as owner and returns its ID.
  /// [profile] (companyId is replaced) is written as the starting profile.
  Future<String> createCompany({
    required String uid,
    required String email,
    required String name,
    required String country,
    required double annualTurnover,
    required String currency,
    required int teamSize,
    CompanyProfile? profile,
  });

  /// Owner only: name, country, turnover, currency, team size.
  Future<void> updateCompany(Company company);

  /// The invite for [email], live: it appears as soon as the owner sends
  /// it and disappears once it is accepted or declined.
  Stream<Invite?> watchInvite(String email);

  /// The invitee turns the invite down. It is deleted, so the owner can
  /// invite someone else or send it again.
  Future<void> declineInvite(Invite invite);

  Future<void> invite({
    required Company company,
    required String email,
    required String invitedBy,
  });

  Future<void> acceptInvite({
    required Invite invite,
    required String uid,
    required String email,
  });
}

abstract interface class ProfileRepository {
  Stream<CompanyProfile?> watch(String companyId);
  Future<void> save(CompanyProfile profile);
}

class FirestoreCompanyRepository implements CompanyRepository {
  FirestoreCompanyRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _companies =>
      _db.collection('companies');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  static String inviteKey(String email) => email.trim().toLowerCase();

  @override
  Stream<String?> watchCompanyIdForUser(String uid) =>
      _users.doc(uid).snapshots().map((s) => s.data()?['companyId'] as String?);

  @override
  Stream<Company?> watchCompany(String companyId) =>
      _companies.doc(companyId).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Company.fromJson({...data, 'id': s.id});
      });

  @override
  Future<String> createCompany({
    required String uid,
    required String email,
    required String name,
    required String country,
    required double annualTurnover,
    required String currency,
    required int teamSize,
    CompanyProfile? profile,
  }) async {
    final ref = _companies.doc();
    final company = Company(
      id: ref.id,
      name: name,
      country: country,
      annualTurnover: annualTurnover,
      currency: currency,
      teamSize: teamSize,
      ownerUid: uid,
      members: {uid: UserRole.owner},
      memberEmails: {uid: email},
    );
    final batch = _db.batch()
      ..set(ref, company.toJson())
      ..set(_users.doc(uid), {'companyId': ref.id, 'email': email});
    await batch.commit();

    // Separate write: the profile rule reads the committed company doc to
    // check ownership.
    final start =
        (profile ??
                CompanyProfile(
                  companyId: ref.id,
                  cpvCodes: const [],
                  countries: [country],
                ))
            .toJson();
    await _db.collection('profiles').doc(ref.id).set({
      ...start,
      'companyId': ref.id,
    });
    return ref.id;
  }

  @override
  Future<void> updateCompany(Company c) => _companies.doc(c.id).update({
    'name': c.name,
    'country': c.country,
    'annualTurnover': c.annualTurnover,
    'currency': c.currency,
    'teamSize': c.teamSize,
  });

  @override
  Stream<Invite?> watchInvite(String email) =>
      _invites.doc(inviteKey(email)).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : Invite.fromJson(data);
      });

  @override
  Future<void> declineInvite(Invite invite) =>
      _invites.doc(inviteKey(invite.email)).delete();

  @override
  Future<void> invite({
    required Company company,
    required String email,
    required String invitedBy,
  }) {
    final key = inviteKey(email);
    return _invites
        .doc(key)
        .set(
          Invite(
            email: key,
            companyId: company.id,
            companyName: company.name,
            invitedBy: invitedBy,
            createdAt: DateTime.now().toUtc(),
          ).toJson(),
        );
  }

  @override
  Future<void> acceptInvite({
    required Invite invite,
    required String uid,
    required String email,
  }) {
    final batch = _db.batch()
      ..update(_companies.doc(invite.companyId), {
        'members.$uid': invite.role.wire,
        'memberEmails.$uid': email,
      })
      ..set(_users.doc(uid), {'companyId': invite.companyId, 'email': email})
      ..delete(_invites.doc(inviteKey(invite.email)));
    return batch.commit();
  }
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<CompanyProfile?> watch(String companyId) =>
      _db.collection('profiles').doc(companyId).snapshots().map((s) {
        final data = s.data();
        return data == null ? null : CompanyProfile.fromJson(data);
      });

  @override
  Future<void> save(CompanyProfile profile) =>
      _db.collection('profiles').doc(profile.companyId).set(profile.toJson());
}
