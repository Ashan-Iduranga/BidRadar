import 'dart:convert';

import '../../core/geo/countries.dart';
import '../../core/geo/local_time.dart';
import '../../core/logging/log.dart';
import '../../core/net/resilient_http.dart';
import '../../core/text/text_utils.dart';
import '../models/models.dart';
import 'deadline_parser.dart';
import 'tender_source.dart';

/// World Bank procurement notices API (public, no key).
/// Notices carry no CPV codes, only a procurement group (goods, works,
/// consulting), so the sector rule can only warn on these tenders.
class WorldBankClient implements TenderSource {
  WorldBankClient(this._http, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const host = 'search.worldbank.org';
  static const path = '/api/v2/procnotices';

  /// Max countries per sync; one small request is made per country, in
  /// parallel. Countries after this are skipped (logged).
  static const maxCountries = 10;

  static const fields = [
    'id',
    'notice_type',
    'noticedate',
    'notice_status',
    'submission_deadline_date',
    'submission_deadline_time',
    'project_ctry_name',
    'project_id',
    'project_name',
    'bid_reference_no',
    'bid_description',
    'procurement_group',
    'procurement_method_name',
    'contact_organization',
    'notice_text',
  ];

  /// Notice types that invite a bid or an expression of interest.
  static bool isBiddable(String? noticeType) {
    final t = (noticeType ?? '').toLowerCase();
    return t.contains('invitation') ||
        t.contains('expression of interest') ||
        t.contains('prequalification') ||
        t.startsWith('request for');
  }

  final ResilientHttp _http;
  final DateTime Function() _clock;

  @override
  TenderSourceType get type => TenderSourceType.worldBank;

  static Uri buildUri(TenderQuery q, {String? countryAlpha3}) =>
      Uri.https(host, path, {
        'format': 'json',
        'rows': '${q.limit.clamp(1, 100)}',
        'os': '0',
        'srt': 'submission_deadline_date',
        'order': 'desc',
        'fl': fields.join(','),
        if (countryAlpha3 != null)
          'project_ctry_name': Countries.worldBankName(countryAlpha3),
      });

  @override
  Future<List<Tender>> search(TenderQuery query) async {
    final countries = query.countries.where(Countries.isAlpha3).toList();
    if (countries.length > maxCountries) {
      Log.warn(
        'worldbank',
        'only the first $maxCountries of ${countries.length} countries '
            'are searched',
      );
      countries.removeRange(maxCountries, countries.length);
    }
    final uris = countries.isEmpty
        ? [buildUri(query)]
        : [for (final c in countries) buildUri(query, countryAlpha3: c)];

    final fetchedAt = _clock().toUtc();
    final results = await Future.wait(
      uris.map((uri) async {
        try {
          final res = await _http.get(uri);
          return parseResponse(
            jsonDecode(utf8.decode(res.bodyBytes)),
            fetchedAt: fetchedAt,
          );
        } on Object catch (e) {
          Log.warn('worldbank', 'request failed for $uri: $e');
          return e;
        }
      }),
    );

    final lists = results.whereType<List<Tender>>().toList();
    if (lists.isEmpty) {
      final first = results.first;
      if (first is Exception) throw first;
      throw NetworkException('World Bank request failed: $first');
    }
    // Countries without recent World Bank activity return notices that
    // closed years ago; they are noise, so only open or undated ones are kept.
    final byId = <String, Tender>{};
    final open = lists
        .expand((l) => l)
        .where((t) => t.deadline == null || t.deadline!.isAfter(fetchedAt));
    for (final t in open) {
      byId.putIfAbsent(t.id, () => t);
    }
    return byId.values.toList();
  }

  static List<Tender> parseResponse(
    Object? json, {
    required DateTime fetchedAt,
  }) {
    if (json is! Map<String, dynamic>) {
      throw SourceFormatException(TenderSourceType.worldBank, 'not an object');
    }
    // The API omits "procnotices" when there are no results.
    final list = json['procnotices'];
    if (list == null) return const [];
    if (list is! List) {
      throw SourceFormatException(
        TenderSourceType.worldBank,
        '"procnotices" is not a list',
      );
    }
    final out = <Tender>[];
    for (final n in list) {
      try {
        final m = n as Map<String, dynamic>;
        if (!isBiddable(m['notice_type'] as String?)) continue;
        out.add(parseNotice(m, fetchedAt: fetchedAt));
      } on Object catch (e) {
        Log.warn('worldbank', 'skipped malformed notice: $e');
      }
    }
    return out;
  }

  static Tender parseNotice(
    Map<String, dynamic> n, {
    required DateTime fetchedAt,
  }) {
    final id = n['id'] as String;
    final project = n['project_name'] as String?;
    final title =
        _clean(n['bid_description']) ?? _clean(project) ?? 'World Bank $id';
    final body = TextUtils.htmlToText((n['notice_text'] as String?) ?? '');
    final group = _groupLabel(n['procurement_group'] as String?);
    final method = n['procurement_method_name'] as String?;

    final countryName = (n['project_ctry_name'] as String?) ?? '';
    final country = Countries.alpha3FromName(countryName) ?? '';
    // The API and the notice give the buyer's local time.
    final wall =
        combine(
          n['submission_deadline_date'] as String?,
          n['submission_deadline_time'] as String?,
        ) ??
        DeadlineParser.fromText(body);
    final local = wall == null ? null : LocalTime.toUtc(wall, country);

    final noticeText = [
      title,
      if (project != null) 'Project: $project',
      if (group != null)
        'Procurement: $group${method == null ? '' : ' ($method)'}',
      if (n['bid_reference_no'] != null) 'Reference: ${n['bid_reference_no']}',
      if (body.isNotEmpty) body,
      if (wall != null && local != null && !local.exact)
        LocalTime.uncertainNote(wall),
    ].join('\n');

    return Tender(
      source: TenderSourceType.worldBank,
      sourceId: id,
      title: title,
      buyer:
          _clean(n['contact_organization']) ?? project ?? 'World Bank project',
      country: country,
      cpvCodes: const [],
      deadline: local?.utc,
      noticeText: noticeText,
      textHash: TextUtils.hash(noticeText),
      url:
          'https://projects.worldbank.org/en/projects-operations/'
          'procurement-detail/$id',
      fetchedAt: fetchedAt,
    );
  }

  /// "2026-11-25T00:00:00Z" + "14:00" -> 25 Nov 2026 14:00 as a local
  /// wall-clock time (fields only; the "Z" on the date means nothing). The
  /// caller converts it with the project country's time zone.
  static DateTime? combine(String? date, String? time) {
    if (date == null || date.length < 10) return null;
    final day = DateTime.tryParse(date.substring(0, 10));
    if (day == null) return null;
    final tm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time?.trim() ?? '');
    final h = int.tryParse(tm?[1] ?? '') ?? 23;
    final m = int.tryParse(tm?[2] ?? '') ?? 59;
    return DateTime.utc(day.year, day.month, day.day, h.clamp(0, 23), m);
  }

  static String? _groupLabel(String? code) => switch (code) {
    'GO' => 'Goods',
    'CW' => 'Civil works',
    'CS' => 'Consulting services',
    'NC' => 'Non-consulting services',
    null => null,
    _ => code,
  };

  static String? _clean(Object? v) {
    if (v is! String) return null;
    final s = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }
}
