/// Shared enums. `wire` is the exact string stored in Firestore and JSON,
/// so renaming a Dart value never breaks stored data.
library;

T _byWire<T extends Enum>(List<T> values, String wire, String Function(T) w) {
  return values.firstWhere(
    (v) => w(v) == wire,
    orElse: () => throw FormatException('Unknown ${T.toString()}: "$wire"'),
  );
}

enum TenderSourceType {
  ted('ted'),
  worldBank('worldbank'),
  scan('scan');

  const TenderSourceType(this.wire);
  final String wire;
  static TenderSourceType fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

/// The agent's decision. Matches the Gemini response schema exactly.
enum VerdictKind {
  bid('BID'),
  noBid('NO_BID'),
  review('REVIEW');

  const VerdictKind(this.wire);
  final String wire;
  static VerdictKind fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

/// Whether the firm meets one extracted criterion.
enum CriterionMet {
  yes('yes'),
  no('no'),
  unknown('unknown');

  const CriterionMet(this.wire);
  final String wire;
  static CriterionMet fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

/// How a verdict was produced. Anything other than [accepted] means a person
/// must look at it.
enum VerdictStatus {
  /// AI answered, every quote was found in the notice text.
  accepted('accepted'),

  /// Hard rules vetoed the tender; the AI was never called.
  rulesVeto('rules_veto'),

  /// Quotes failed verification twice, so the verdict was forced to REVIEW.
  quotesRejected('quotes_rejected'),

  /// AI timed out or failed; a person decides manually.
  aiUnavailable('ai_unavailable');

  const VerdictStatus(this.wire);
  final String wire;
  static VerdictStatus fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum BidStage {
  watching('watching'),
  preparing('preparing'),
  submitted('submitted'),
  won('won'),
  lost('lost');

  const BidStage(this.wire);
  final String wire;
  static BidStage fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum UserRole {
  owner('owner'),
  bidManager('bid_manager');

  const UserRole(this.wire);
  final String wire;
  static UserRole fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

enum ApprovalDecision {
  approved('approved'),
  rejected('rejected');

  const ApprovalDecision(this.wire);
  final String wire;
  static ApprovalDecision fromWire(String w) =>
      _byWire(values, w, (v) => v.wire);
}

/// Hard eligibility rules applied in code before any AI call.
enum VetoRule {
  deadlinePassed('deadline_passed'),
  countryNotServed('country_not_served'),
  sectorMismatch('sector_mismatch'),
  turnoverBelowMinimum('turnover_below_minimum');

  const VetoRule(this.wire);
  final String wire;
  static VetoRule fromWire(String w) => _byWire(values, w, (v) => v.wire);
}

/// Where a bid is in the owner-approval step before preparing it.
enum ApprovalState {
  none('none'),
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const ApprovalState(this.wire);
  final String wire;
  static ApprovalState fromWire(String w) => _byWire(values, w, (v) => v.wire);
}
