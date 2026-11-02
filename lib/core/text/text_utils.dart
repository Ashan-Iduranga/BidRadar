import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Text helpers shared by the source clients, dedup and (in Phase 3) the
/// QuoteVerifier. Keep normalisation in one place so a hash computed at
/// fetch time matches one computed later.
abstract final class TextUtils {
  /// Lower case, punctuation removed, whitespace collapsed. Letters from any
  /// script are kept, so Spanish or Czech notices hash consistently.
  static String normalise(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// SHA-256 of [normalise]d text, hex encoded.
  static String hash(String s) =>
      sha256.convert(utf8.encode(normalise(s))).toString();

  /// Very small HTML to plain text conversion for World Bank notice bodies.
  /// Block tags become line breaks; entities are decoded.
  static String htmlToText(String html) {
    var s = html
        .replaceAll(
          RegExp(
            r'<\s*(br|/p|/div|/li|/h[1-6]|/tr)\s*/?>',
            caseSensitive: false,
          ),
          '\n',
        )
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '\n- ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    s = _decodeEntities(s);
    return s
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  static String _decodeEntities(String s) {
    const named = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&ndash;': '–',
      '&mdash;': '—',
      '&rsquo;': '’',
      '&lsquo;': '‘',
      '&ldquo;': '“',
      '&rdquo;': '”',
    };
    var out = s.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
      return code == null ? m[0]! : String.fromCharCode(code);
    });
    named.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }
}
