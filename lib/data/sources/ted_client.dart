import 'dart:convert';

import '../../core/geo/countries.dart';
import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../core/text/text_utils.dart';
import '../models/models.dart';
import 'deadline_parser.dart';
import 'tender_source.dart';

/// EU TED Search API v3 (anonymous, no key needed).
/// Docs: https://docs.ted.europa.eu/api/latest/search.html
class TedClient implements TenderSource {
  TedClient(this._http, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static final endpoint = Uri.parse(
    'https://api.ted.europa.eu/v3/notices/search',
  );

  /// Contract notices only. Award and prior-information notices are not
  /// biddable.
  static const noticeTypes = ['cn-standard', 'cn-social', 'cn-desg'];

  static const fields = [
    'publication-number',
    'notice-title',
    'title-proc',
    'buyer-name',
    'buyer-country',
    'place-of-performance-country-lot',
    'classification-cpv',
    'deadline-receipt-tender-date-lot',
    'deadline-receipt-tender-time-lot',
    'deadline-receipt-request-date-lot',
    'estimated-value-lot',
    'estimated-value-cur-lot',
    'description-lot',
    'description-proc',
    'notice-type',
    'publication-date',
    'links',
  ];

  final ResilientHttp _http;
  final DateTime Function() _clock;

  @override
  TenderSourceType get type => TenderSourceType.ted;

  /// TED expert query. CPV matching on TED is hierarchical: 72000000 also
  /// returns 72267100. The "ACTIVE" scope alone still returns notices that
  /// closed years ago (oldest first), so open deadlines are filtered here and
  /// the newest are asked for first.
  static String buildQuery(TenderQuery q, {required DateTime today}) {
    final d = today.toUtc();
    final ymd =
        '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}';
    final parts = <String>[
      'notice-type IN (${noticeTypes.join(' ')})',
      '(deadline-receipt-tender-date-lot>=$ymd OR '
          'deadline-receipt-request-date-lot>=$ymd)',
    ];
    final cpv = q.cpvCodes.where((c) => RegExp(r'^\d{8}$').hasMatch(c));
    if (cpv.isNotEmpty) parts.add('classification-cpv IN (${cpv.join(' ')})');
    final countries = q.countries.where(Countries.isAlpha3);
    if (countries.isNotEmpty) {
      parts.add('place-of-performance-country-lot IN (${countries.join(' ')})');
    }
    return '${parts.join(' AND ')} SORT BY publication-date DESC';
  }

  @override
  Future<List<Tender>> search(TenderQuery query) async {
    final body = jsonEncode({
      'query': buildQuery(query, today: _clock()),
      'fields': fields,
      'limit': query.limit.clamp(1, 250),
      'page': 1,
      'scope': 'ACTIVE',
      'paginationMode': 'PAGE_NUMBER',
    });
    final res = await _http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException catch (e) {
      throw SourceFormatException(type, 'invalid JSON: ${e.message}');
    }
    return parseResponse(
      decoded,
      fetchedAt: _clock().toUtc(),
      preferCountries: query.countries,
    );
  }

  /// Maps a search response. Malformed notices are skipped and logged.
  static List<Tender> parseResponse(
    Object? json, {
    required DateTime fetchedAt,
    List<String> preferCountries = const [],
  }) {
    if (json is! Map<String, dynamic> || json['notices'] is! List) {
      throw SourceFormatException(TenderSourceType.ted, 'no "notices" list');
    }
    final out = <Tender>[];
    for (final n in json['notices'] as List) {
      try {
        out.add(
          parseNotice(
            n as Map<String, dynamic>,
            fetchedAt: fetchedAt,
            preferCountries: preferCountries,
          ),
        );
      } on Object catch (e) {
        Log.warn('ted', 'skipped malformed notice: $e');
      }
    }
    return out;
  }

  static Tender parseNotice(
    Map<String, dynamic> n, {
    required DateTime fetchedAt,
    List<String> preferCountries = const [],
  }) {
    final id = n['publication-number'] as String;
    final procTitle = _firstText(n['title-proc']);
    final title =
        _langText(n['notice-title'], prefer: 'eng') ??
        procTitle ??
        'TED notice $id';

    final noticeText = <String>{
      title,
      if (procTitle != null && procTitle != title) procTitle,
      ..._allTexts(n['description-proc']),
      ..._allTexts(n['description-lot']),
    }.join('\n\n');

    final values = _strings(n['estimated-value-lot'])
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    final links = (n['links'] as Map?) ?? const {};
    return Tender(
      source: TenderSourceType.ted,
      sourceId: id,
      title: title,
      buyer: _firstText(n['buyer-name']) ?? 'Unknown buyer',
      country: _country(n, preferCountries),
      cpvCodes: _strings(n['classification-cpv']).toSet().toList(),
      deadline: resolveDeadline(n, noticeText),
      estimatedValue: values.isEmpty ? null : values.reduce((a, b) => a + b),
      currency: _strings(n['estimated-value-cur-lot']).firstOrNull,
      noticeText: noticeText,
      textHash: TextUtils.hash(noticeText),
      url: _link(links['html']),
      documentUrls: [?_link(links['pdf'])],
      fetchedAt: fetchedAt,
    );
  }

  /// Earliest lot deadline (date + time); else the request-to-participate
  /// date; else a date found in the notice text; else null (unknown).
  static DateTime? resolveDeadline(Map<String, dynamic> n, String text) {
    final dates = _strings(n['deadline-receipt-tender-date-lot']);
    final times = _strings(n['deadline-receipt-tender-time-lot']);
    final lots = <DateTime>[];
    for (var i = 0; i < dates.length; i++) {
      final d = combine(dates[i], i < times.length ? times[i] : null);
      if (d != null) lots.add(d);
    }
    if (lots.isEmpty) {
      for (final d in _strings(n['deadline-receipt-request-date-lot'])) {
        final parsed = combine(d, null);
        if (parsed != null) lots.add(parsed);
      }
    }
    if (lots.isNotEmpty) {
      lots.sort();
      return lots.first;
    }
    return DeadlineParser.fromText(text);
  }

  /// "2026-11-06+01:00" + "23:59:00+01:00" -> 2026-11-06T22:59:00Z.
  /// Without a time, the end of that day is used.
  static DateTime? combine(String date, String? time) {
    final dm = RegExp(r'^(\d{4}-\d{2}-\d{2})(Z|[+-]\d{2}:\d{2})?$')
        .firstMatch(date.trim());
    if (dm == null) return null;
    var clock = '23:59:00';
    var offset = dm[2] ?? 'Z';
    if (time != null) {
      final tm = RegExp(r'^(\d{2}:\d{2}(?::\d{2})?)(Z|[+-]\d{2}:\d{2})?$')
          .firstMatch(time.trim());
      if (tm != null) {
        clock = tm[1]!.length == 5 ? '${tm[1]}:00' : tm[1]!;
        offset = tm[2] ?? offset;
      }
    }
    return DateTime.tryParse('${dm[1]}T$clock$offset')?.toUtc();
  }

  /// Lots can be in several countries; one the firm serves wins, so a lot
  /// it can deliver is not vetoed because another lot is elsewhere.
  static String _country(Map<String, dynamic> n, List<String> prefer) {
    final lots = _strings(n['place-of-performance-country-lot']);
    final served = lots.where(prefer.contains).firstOrNull;
    if (served != null) return served;
    for (final key in ['place-of-performance-country-lot', 'buyer-country']) {
      final hit = _strings(n[key]).where(Countries.isAlpha3).firstOrNull;
      if (hit != null) return hit;
    }
    return '';
  }

  static String? _link(Object? byLang) {
    if (byLang is! Map || byLang.isEmpty) return null;
    return (byLang['ENG'] ?? byLang.values.first) as String?;
  }

  static List<String> _strings(Object? v) => switch (v) {
    null => const [],
    final String s => [s],
    final List<Object?> l => l.map((e) => '$e').toList(),
    _ => ['$v'],
  };

  /// Multilingual field: {"eng": "…"} or {"spa": ["…"]}.
  static String? _langText(Object? v, {required String prefer}) {
    if (v is! Map || v.isEmpty) return null;
    final picked = v[prefer] ?? v.values.first;
    return _strings(picked).firstOrNull;
  }

  static String? _firstText(Object? v) => _langText(v, prefer: 'eng');

  static List<String> _allTexts(Object? v) {
    if (v is! Map || v.isEmpty) return const [];
    return _strings(v['eng'] ?? v.values.first);
  }
}
