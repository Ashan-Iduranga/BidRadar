import 'package:bidradar/core/geo/countries.dart';
import 'package:bidradar/core/text/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Countries', () {
    test('has every ISO country plus Kosovo', () {
      expect(kCountries.length, greaterThanOrEqualTo(250));
      expect(Countries.isAlpha3('LKA'), isTrue);
      expect(Countries.isAlpha3('lka'), isTrue);
      expect(Countries.isAlpha3('XX'), isFalse);
      expect(Countries.nameOf('LVA'), 'Latvia');
      expect(Countries.nameOf('ZZZ'), 'ZZZ');
    });

    // Spellings seen in World Bank notices.
    for (final (name, code) in [
      ('Sri Lanka', 'LKA'),
      ('Nigeria', 'NGA'),
      ('Tanzania', 'TZA'),
      ('Congo, Democratic Republic of', 'COD'),
      ('Congo, Republic of', 'COG'),
      ('Egypt, Arab Republic of', 'EGY'),
      ('Yemen, Republic of', 'YEM'),
      ('Gambia, The', 'GMB'),
      ('Turkiye', 'TUR'),
      ('Kyrgyz Republic', 'KGZ'),
      ("Lao People's Democratic Republic", 'LAO'),
      ("Cote d'Ivoire", 'CIV'),
      ('Viet Nam', 'VNM'),
      ('Vietnam', 'VNM'),
      ('West Bank and Gaza', 'PSE'),
      ('Kosovo', 'XKX'),
      ('St. Lucia', 'LCA'),
      ('Micronesia, Federated States of', 'FSM'),
      ('Moldova', 'MDA'),
      ('Bolivia', 'BOL'),
    ]) {
      test('"$name" -> $code', () {
        expect(Countries.alpha3FromName(name), code);
      });
    }

    test('regions are not countries', () {
      expect(Countries.alpha3FromName('Western and Central Africa'), isNull);
      expect(Countries.alpha3FromName('World'), isNull);
    });

    test('World Bank names round-trip back to the same code', () {
      for (final code in ['LKA', 'IND', 'TUR', 'COD', 'EGY', 'VNM', 'TZA']) {
        expect(
          Countries.alpha3FromName(Countries.worldBankName(code)),
          code,
          reason: Countries.worldBankName(code),
        );
      }
    });
  });

  group('TextUtils', () {
    test('normalise ignores case, punctuation and spacing', () {
      expect(
        TextUtils.normalise('  Minimum  TURNOVER: EUR 1,000,000.  '),
        'minimum turnover eur 1 000 000',
      );
    });

    test('normalise keeps non-Latin letters', () {
      expect(
        TextUtils.normalise('Zajištění konektivity'),
        'zajištění konektivity',
      );
    });

    test('hash is stable across formatting differences', () {
      expect(
        TextUtils.hash('Supply of ICT equipment.'),
        TextUtils.hash('supply  of ICT\nequipment'),
      );
      expect(TextUtils.hash('a'), isNot(TextUtils.hash('b')));
    });

    test('htmlToText strips tags and decodes entities', () {
      const html =
          '<p><strong>Request&nbsp;for Bids</strong></p><ol><li>Item &amp; '
          'one</li><li>PRIME MINISTER&#39;S OFFICE</li></ol>';
      expect(
        TextUtils.htmlToText(html),
        "Request for Bids\n- Item & one\n- PRIME MINISTER'S OFFICE",
      );
    });
  });
}
