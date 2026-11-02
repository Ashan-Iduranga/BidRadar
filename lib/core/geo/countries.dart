/// ISO 3166-1 alpha-3 countries, with lookup by the names that tender sources
/// use. TED already sends alpha-3 codes; the World Bank sends English names
/// such as "Congo, Democratic Republic of" or "Turkiye".
library;

part 'countries_data.dart';

class Country {
  const Country(this.alpha3, this.name, this.names);

  /// ISO 3166-1 alpha-3, e.g. "LKA".
  final String alpha3;

  /// Short display name, e.g. "Sri Lanka".
  final String name;

  /// Every known spelling (ISO name, common name, official name).
  final List<String> names;
}

/// Spellings used by the World Bank that the ISO names do not cover.
/// Keys are already normalised (see [Countries.normaliseName]).
const Map<String, String> kCountryAliases = {
  'vietnam': 'VNM',
  'west bank and gaza': 'PSE',
  'hong kong sar china': 'HKG',
  'macao sar china': 'MAC',
  'taiwan china': 'TWN',
  'venezuela republica bolivariana de': 'VEN',
  'republica bolivariana de venezuela': 'VEN',
  'korea democratic peoples republic of': 'PRK',
  'czech republic': 'CZE',
  'swaziland': 'SWZ',
  'macedonia': 'MKD',
  'cape verde': 'CPV',
  'ivory coast': 'CIV',
  'burma': 'MMR',
  'east timor': 'TLS',
  'kosovo': 'XKX',
  'congo republic of': 'COG',
  'republic of congo': 'COG',
  'congo': 'COG',
  'russia': 'RUS',
  'laos': 'LAO',
  'lao pdr': 'LAO',
  'syria': 'SYR',
  'iran': 'IRN',
  'south korea': 'KOR',
  'north korea': 'PRK',
  'uk': 'GBR',
  'usa': 'USA',
  'united states of america': 'USA',
};

abstract final class Countries {
  static final Map<String, Country> _byCode = {
    for (final c in kCountries) c.alpha3: c,
  };

  static final Map<String, String> _byName = () {
    final map = <String, String>{};
    for (final c in kCountries) {
      for (final n in c.names) {
        for (final variant in _variants(n)) {
          map.putIfAbsent(variant, () => c.alpha3);
        }
      }
    }
    map.addAll(kCountryAliases);
    return map;
  }();

  static Country? byAlpha3(String code) => _byCode[code.toUpperCase()];

  static bool isAlpha3(String code) => _byCode.containsKey(code.toUpperCase());

  /// Display name for a code, or the code itself if it is unknown.
  static String nameOf(String code) => byAlpha3(code)?.name ?? code;

  /// Maps a country name to alpha-3. Returns null for regions such as
  /// "Western and Central Africa" or "World".
  static String? alpha3FromName(String name) {
    for (final variant in _variants(name)) {
      final hit = _byName[variant];
      if (hit != null) return hit;
    }
    return null;
  }

  /// Name to send to the World Bank API for a code.
  static String worldBankName(String alpha3) {
    const overrides = {
      'VNM': 'Viet Nam',
      'TUR': 'Turkiye',
      'COD': 'Congo, Democratic Republic of',
      'COG': 'Congo, Republic of',
      'EGY': 'Egypt, Arab Republic of',
      'YEM': 'Yemen, Republic of',
      'GMB': 'Gambia, The',
      'KGZ': 'Kyrgyz Republic',
      'LAO': "Lao People's Democratic Republic",
      'PSE': 'West Bank and Gaza',
      'XKX': 'Kosovo',
      'TZA': 'Tanzania',
      'BOL': 'Bolivia',
      'MDA': 'Moldova',
    };
    final o = overrides[alpha3];
    if (o != null) return o;
    final c = byAlpha3(alpha3);
    if (c == null) return alpha3;
    // "Tanzania, United Republic of" -> "Tanzania".
    return c.name.split(',').first.trim();
  }

  /// Lower case, no accents, no punctuation, no "the", single spaces.
  static String normaliseName(String s) {
    var out = s.toLowerCase();
    _accents.forEach((from, to) => out = out.replaceAll(from, to));
    out = out
        .replaceAll(RegExp(r"['’`.]"), '')
        .replaceAll(RegExp(r'[^a-z ]'), ' ')
        .replaceAll(RegExp(r'\bthe\b'), ' ')
        .replaceAll(RegExp(r'\bst\b'), 'saint')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return out;
  }

  /// "Korea, Republic of" -> {"korea republic of", "republic of korea",
  /// "korea"}.
  static Iterable<String> _variants(String name) sync* {
    yield normaliseName(name);
    final comma = name.indexOf(',');
    if (comma > 0) {
      final head = name.substring(0, comma);
      final tail = name.substring(comma + 1);
      yield normaliseName('$tail $head');
      yield normaliseName(head);
    }
  }

  static const _accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  };
}
