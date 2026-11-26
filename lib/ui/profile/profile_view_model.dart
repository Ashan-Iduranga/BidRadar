import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo/countries.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';
import '../session/session_providers.dart';

/// Pure validation for profile fields. Returns (value, error).
abstract final class ProfileInput {
  /// Accepts "72000000", "7200 0000" or "72000000-8" (with check digit).
  static ({String? code, String? error}) cpv(String raw, List<String> have) {
    final s = raw.replaceAll(' ', '').split('-').first;
    if (!RegExp(r'^\d{8}$').hasMatch(s)) {
      return (code: null, error: 'A CPV code has 8 digits, e.g. 72000000.');
    }
    if (have.contains(s)) return (code: null, error: '$s is already added.');
    return (code: s, error: null);
  }

  static ({String? code, String? error}) country(
    String raw,
    List<String> have,
  ) {
    final s = raw.trim().toUpperCase();
    if (!Countries.isAlpha3(s)) {
      return (code: null, error: 'Unknown country code "$raw".');
    }
    if (have.contains(s)) {
      return (code: null, error: '${Countries.nameOf(s)} is already added.');
    }
    return (code: s, error: null);
  }

  static ({String? value, String? error}) certification(
    String raw,
    List<String> have,
  ) {
    final s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return (value: null, error: 'Enter a certification.');
    if (s.length > 60) return (value: null, error: 'Keep it under 60 letters.');
    if (have.any((h) => h.toLowerCase() == s.toLowerCase())) {
      return (value: null, error: '$s is already added.');
    }
    return (value: s, error: null);
  }
}

/// How long a profile or company save waits for Firestore to confirm.
/// Offline, Firestore keeps the write on the phone and never confirms it
/// until the connection is back, so the wait has to end somewhere.
const kSaveWait = Duration(seconds: 10);

/// Shown when the wait ends: the change is saved locally and will sync.
const kSavedOnPhone =
    'Saved on this phone. It will sync when you are back online.';

@immutable
class ProfileEditState {
  const ProfileEditState({
    required this.saved,
    required this.draft,
    this.saving = false,
  });

  /// What is in Firestore. Null while loading or when there is no profile.
  final CompanyProfile? saved;

  /// What the owner is editing.
  final CompanyProfile? draft;
  final bool saving;

  bool get dirty =>
      saved != null &&
      draft != null &&
      jsonEncode(saved!.toJson()) != jsonEncode(draft!.toJson());

  ProfileEditState copyWith({
    CompanyProfile? saved,
    CompanyProfile? draft,
    bool? saving,
  }) => ProfileEditState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    saving: saving ?? this.saving,
  );
}

/// Company page ViewModel. Edits happen on a local draft and are written in
/// one save, so a half-edited profile never reaches the rules.
class ProfileViewModel extends Notifier<ProfileEditState> {
  @override
  ProfileEditState build() {
    ref.listen(currentProfileProvider, (_, next) {
      final p = next.value;
      if (p == null) return;
      // Keep unsaved edits when the stored copy changes underneath.
      state = state.dirty
          ? state.copyWith(saved: p)
          : ProfileEditState(saved: p, draft: p);
    });
    final p = ref.read(currentProfileProvider).value;
    return ProfileEditState(saved: p, draft: p);
  }

  CompanyProfile get _d => state.draft!;

  void _set(CompanyProfile d) => state = state.copyWith(draft: d);

  String? addCpv(String raw) {
    final r = ProfileInput.cpv(raw, _d.cpvCodes);
    if (r.code != null) _set(_d.copyWith(cpvCodes: [..._d.cpvCodes, r.code!]));
    return r.error;
  }

  void removeCpv(String code) =>
      _set(_d.copyWith(cpvCodes: [..._d.cpvCodes]..remove(code)));

  String? addCountry(String raw) {
    final r = ProfileInput.country(raw, _d.countries);
    if (r.code != null) {
      _set(_d.copyWith(countries: [..._d.countries, r.code!]));
    }
    return r.error;
  }

  void removeCountry(String code) =>
      _set(_d.copyWith(countries: [..._d.countries]..remove(code)));

  String? addCertification(String raw) {
    final r = ProfileInput.certification(raw, _d.certifications);
    if (r.value != null) {
      _set(_d.copyWith(certifications: [..._d.certifications, r.value!]));
    }
    return r.error;
  }

  void removeCertification(String c) =>
      _set(_d.copyWith(certifications: [..._d.certifications]..remove(c)));

  void addPastContract(PastContract c) =>
      _set(_d.copyWith(pastContracts: [..._d.pastContracts, c]));

  void removePastContract(int index) =>
      _set(_d.copyWith(pastContracts: [..._d.pastContracts]..removeAt(index)));

  void discard() => state = state.copyWith(draft: state.saved);

  /// Returns null when saved, [kSavedOnPhone] when Firestore has not
  /// confirmed in time (offline), or an error message.
  Future<String?> save() async {
    final d = state.draft;
    if (d == null) return 'Nothing to save.';
    state = state.copyWith(saving: true);
    try {
      await ref.read(profileRepositoryProvider).save(d).timeout(kSaveWait);
      state = ProfileEditState(saved: d, draft: d);
      return null;
    } on TimeoutException {
      state = ProfileEditState(saved: d, draft: d);
      return kSavedOnPhone;
    } on FirebaseException catch (e) {
      state = state.copyWith(saving: false);
      return e.code == 'permission-denied'
          ? 'Only the owner can change the profile.'
          : 'Could not save (${e.code}). Try again.';
    }
  }

  /// Returns null when saved, [kSavedOnPhone] when Firestore has not
  /// confirmed in time (offline), or an error message.
  Future<String?> updateCompany(Company c) async {
    try {
      await ref
          .read(companyRepositoryProvider)
          .updateCompany(c)
          .timeout(kSaveWait);
      return null;
    } on TimeoutException {
      return kSavedOnPhone;
    } on FirebaseException catch (e) {
      return 'Could not save (${e.code}).';
    }
  }

  Future<String?> invite(String email) async {
    final company = ref.read(currentCompanyProvider).value;
    final me = ref.read(authStateProvider).value;
    final e = email.trim().toLowerCase();
    if (company == null || me == null) return 'No company loaded.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return 'Enter a valid email address.';
    }
    if (company.memberEmails.values.map((v) => v.toLowerCase()).contains(e)) {
      return '$e is already in the team.';
    }
    try {
      await ref
          .read(companyRepositoryProvider)
          .invite(company: company, email: e, invitedBy: me.uid);
      return null;
    } on FirebaseException catch (x) {
      return 'Could not send the invite (${x.code}).';
    }
  }
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileEditState>(ProfileViewModel.new);
