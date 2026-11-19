// Ported from apps/web/src/lib/anilist/humanize.ts.

import '../anilist/types.dart';

const _formatLabels = {
  'TV': 'TV',
  'TV_SHORT': 'TV Short',
  'MOVIE': 'Movie',
  'SPECIAL': 'Special',
  'OVA': 'OVA',
  'ONA': 'ONA',
  'MUSIC': 'Music',
  'MANGA': 'Manga',
  'NOVEL': 'Novel',
  'ONE_SHOT': 'One-shot',
};

String humanizeFormat(String? format) {
  if (format == null || format.isEmpty) return 'Unknown';
  return _formatLabels[format] ?? format;
}

const _statusLabels = {
  'FINISHED': 'Finished',
  'RELEASING': 'Releasing',
  'NOT_YET_RELEASED': 'Not yet released',
  'CANCELLED': 'Cancelled',
  'HIATUS': 'Hiatus',
};

String humanizeStatus(String? status) {
  if (status == null || status.isEmpty) return 'Unknown';
  return _statusLabels[status] ?? status;
}

String humanizeSeason(MediaSeason season) => season.api[0] + season.api.substring(1).toLowerCase();

/// The compact countdown style ("2d 4h", "19h 12m", "5m").
String formatTimeUntil(int totalSeconds) {
  if (totalSeconds <= 0) return 'now';
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;

  if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  return '${minutes}m';
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
};

final _br = RegExp(r'<br\s*/?>', caseSensitive: false);
final _tag = RegExp(r'<[^>]*>');
final _entity = RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);', caseSensitive: false);

/// AniList descriptions contain tags (<br>, <i>) and HTML entities even with
/// asHtml: false. Drop the tags (keeping line breaks as whitespace so words
/// don't run together) and decode the entities.
String stripHtml(String html) {
  return html.replaceAll(_br, '\n').replaceAll(_tag, '').replaceAllMapped(_entity, (m) {
    final code = m.group(1)!;
    if (code.startsWith('#')) {
      final hex = code.length > 1 && (code[1] == 'x' || code[1] == 'X');
      final n = hex ? int.tryParse(code.substring(2), radix: 16) : int.tryParse(code.substring(1));
      // out-of-range code points (&#99999999;) would throw a RangeError
      return n == null || n < 0 || n > 0x10ffff ? m.group(0)! : String.fromCharCode(n);
    }
    return _namedEntities[code.toLowerCase()] ?? m.group(0)!;
  }).trim();
}
