/// Approximate currency rates to EUR, used only to compare a company's
/// turnover with a tender's minimum. Updated by hand (last: Nov 2026).
/// Because they are approximate, cross-currency vetoes allow a margin
/// (see EligibilityRules.fxTolerance).
class FxRates {
  const FxRates([this.toEur = defaultToEur]);

  static const Map<String, double> defaultToEur = {
    'EUR': 1.0,
    'USD': 0.92,
    'GBP': 1.17,
    'CHF': 1.05,
    'SEK': 0.087,
    'NOK': 0.085,
    'DKK': 0.134,
    'PLN': 0.23,
    'CZK': 0.040,
    'HUF': 0.0025,
    'RON': 0.20,
    'BGN': 0.51,
    'LKR': 0.0031,
    'INR': 0.011,
    'BDT': 0.0077,
    'NPR': 0.0069,
    'PKR': 0.0033,
    'KES': 0.0071,
    'NGN': 0.00060,
  };

  final Map<String, double> toEur;

  /// Converts [amount] from [from] to [to], or null if either is unknown.
  double? convert(double amount, String from, String to) {
    if (from == to) return amount;
    final a = toEur[from.toUpperCase()];
    final b = toEur[to.toUpperCase()];
    if (a == null || b == null) return null;
    return amount * a / b;
  }
}
