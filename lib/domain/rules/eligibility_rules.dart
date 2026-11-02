import 'package:intl/intl.dart';

import '../../core/geo/countries.dart';
import '../../data/models/models.dart';
import 'fx_rates.dart';

/// Hard eligibility rules, checked in plain Dart before any AI call.
/// Pure: same inputs, same result. A veto means the tender can never be
/// won, so it becomes NO_BID and the AI is never asked. Missing data never
/// vetoes; it adds a warning so the tender goes to REVIEW instead.
class EligibilityRules {
  const EligibilityRules({
    this.fx = const FxRates(),
    this.fxTolerance = 0.10,
    this.closingSoon = const Duration(hours: 72),
  });

  final FxRates fx;

  /// When currencies differ, veto only if turnover is short by more than
  /// this fraction, because [FxRates] are approximate.
  final double fxTolerance;

  /// Deadlines closer than this add a warning.
  final Duration closingSoon;

  RulesResult check({
    required Company company,
    required CompanyProfile profile,
    required Tender tender,
    required DateTime now,
  }) {
    final vetoes = <RuleVeto>[];
    final warnings = <String>[];
    _deadline(tender, now.toUtc(), vetoes, warnings);
    _country(profile, tender, vetoes, warnings);
    _sector(profile, tender, vetoes, warnings);
    _turnover(company, tender, vetoes, warnings);
    return RulesResult(vetoes: vetoes, warnings: warnings);
  }

  void _deadline(
    Tender t,
    DateTime now,
    List<RuleVeto> vetoes,
    List<String> warnings,
  ) {
    final d = t.deadline?.toUtc();
    if (d == null) {
      warnings.add('Deadline unknown. Check the notice before bidding.');
      return;
    }
    // A bid cannot be submitted at or after the deadline instant.
    if (!d.isAfter(now)) {
      vetoes.add(
        RuleVeto(
          rule: VetoRule.deadlinePassed,
          message: 'Deadline passed on ${DateFormat.yMMMd().format(d)}.',
        ),
      );
      return;
    }
    if (d.difference(now) < closingSoon) {
      warnings.add('Closes in less than ${closingSoon.inHours} hours.');
    }
  }

  void _country(
    CompanyProfile p,
    Tender t,
    List<RuleVeto> vetoes,
    List<String> warnings,
  ) {
    if (t.country.isEmpty) {
      warnings.add('Country not stated, so it was not checked.');
      return;
    }
    if (p.countries.isEmpty) {
      warnings.add(
        'Your profile lists no countries, so country was not '
        'checked.',
      );
      return;
    }
    if (!p.countries.contains(t.country)) {
      vetoes.add(
        RuleVeto(
          rule: VetoRule.countryNotServed,
          message:
              'You do not deliver in ${Countries.nameOf(t.country)} '
              '(${t.country}).',
        ),
      );
    }
  }

  void _sector(
    CompanyProfile p,
    Tender t,
    List<RuleVeto> vetoes,
    List<String> warnings,
  ) {
    if (t.cpvCodes.isEmpty) {
      warnings.add('No CPV codes on this notice, so sector was not checked.');
      return;
    }
    if (p.cpvCodes.isEmpty) {
      warnings.add('Your profile lists no sectors, so sector was not checked.');
      return;
    }
    final match = t.cpvCodes.any(
      (tc) => p.cpvCodes.any((pc) => cpvOverlap(tc, pc)),
    );
    if (!match) {
      final shown = t.cpvCodes.take(3).join(', ');
      vetoes.add(
        RuleVeto(
          rule: VetoRule.sectorMismatch,
          message: 'Sector (CPV $shown) is outside your sectors.',
        ),
      );
    }
  }

  void _turnover(
    Company c,
    Tender t,
    List<RuleVeto> vetoes,
    List<String> warnings,
  ) {
    final min = t.minTurnover;
    if (min == null) return;
    if (c.annualTurnover <= 0) {
      warnings.add(
        'Add your yearly turnover to check the minimum of '
        '${_money(min, t.currency)}.',
      );
      return;
    }
    final currency = t.currency;
    if (currency == null) {
      warnings.add(
        'Minimum turnover has no currency, so it was not '
        'checked.',
      );
      return;
    }
    final have = fx.convert(c.annualTurnover, c.currency, currency);
    if (have == null) {
      warnings.add('Cannot compare ${c.currency} with $currency turnover.');
      return;
    }
    final sameCurrency = c.currency.toUpperCase() == currency.toUpperCase();
    final threshold = sameCurrency ? min : min * (1 - fxTolerance);
    if (have < threshold) {
      vetoes.add(
        RuleVeto(
          rule: VetoRule.turnoverBelowMinimum,
          message:
              'Needs yearly turnover of ${_money(min, currency)}; '
              'yours is about ${_money(have, currency)}.',
        ),
      );
    } else if (have < min) {
      warnings.add(
        'Turnover is close to the minimum of '
        '${_money(min, currency)}.',
      );
    }
  }

  /// Two CPV codes overlap when one's significant prefix (the code without
  /// trailing zeros, at least the 2-digit division) starts the other.
  /// 72000000 (IT services) overlaps 72267100; 72260000 overlaps 72000000.
  static bool cpvOverlap(String a, String b) {
    final pa = cpvPrefix(a);
    final pb = cpvPrefix(b);
    return pa.startsWith(pb) || pb.startsWith(pa);
  }

  static String cpvPrefix(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    var p = digits.replaceFirst(RegExp(r'0+$'), '');
    if (p.length < 2) p = digits.padRight(2, '0').substring(0, 2);
    return p;
  }

  static String _money(double v, String? currency) =>
      NumberFormat.compactCurrency(
        symbol: currency == null ? '' : '$currency ',
        decimalDigits: 1,
      ).format(v);
}
