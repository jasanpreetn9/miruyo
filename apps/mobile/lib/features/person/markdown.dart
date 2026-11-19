// AniList's descriptions for characters and staff, ported from
// apps/web/src/lib/page-data/markdown.ts. They're AniList's own markdown:
// __bold__, _italic_, [links](…), ~!spoilers!~, plus images, videos and
// centring. They're turned into plain segments here, so a page renders them
// as text and nothing in a description becomes markup.

import '../../core/catalog/humanize.dart';
import '../../core/catalog/links.dart';

class Segment {
  const Segment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.href,
    this.external = false,
    this.spoiler = false,
  });

  final String text;
  final bool bold;
  final bool italic;

  /// A miruyo path (/character/12) or an http(s) URL.
  final String? href;

  /// Opens outside the app: a link to another site.
  final bool external;

  /// Gives away the story: hidden until asked for.
  final bool spoiler;

  Segment copyWith({String? text, bool? bold, bool? italic, String? href, bool? external, bool? spoiler}) => Segment(
    text ?? this.text,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    href: href ?? this.href,
    external: external ?? this.external,
    spoiler: spoiler ?? this.spoiler,
  );

  bool _looksLike(Segment o) => o.bold == bold && o.italic == italic && o.href == href && o.spoiler == spoiler;

  @override
  bool operator ==(Object other) =>
      other is Segment && other.text == text && other.external == external && _looksLike(other);

  @override
  int get hashCode => Object.hash(text, bold, italic, href, external, spoiler);

  @override
  String toString() =>
      'Segment(${['"$text"', if (bold) 'bold', if (italic) 'italic', if (href != null) 'href: $href', if (external) 'external', if (spoiler) 'spoiler'].join(', ')})';
}

/// One paragraph; a single line break inside it stays a '\n' in the text.
typedef Paragraph = List<Segment>;

typedef Fact = ({String label, String value});

final _own = RegExp(r'^https?://anilist\.co/(character|staff|anime|manga)/(\d+)');

/// AniList links to its own characters, staff and titles open in miruyo;
/// other http(s) links open outside it; anything else is plain text.
Segment _linkTo(Segment base, String url) {
  if (_own.firstMatch(url) case final own?) {
    final kind = own[1] == 'anime' || own[1] == 'manga' ? 'title' : own[1];
    return base.copyWith(href: '/$kind/${own[2]}');
  }
  final safe = externalUrl(url);
  return safe == null ? base : base.copyWith(href: url, external: true);
}

/// Links, bold and italic, in that order, so a link's text keeps its own markup.
final _inline = RegExp(
  r'\[([^\]]+)\]\(([^)\s]+)\)|__(.+?)__|\*\*(.+?)\*\*|(?<![\w*])_(?!_)(.+?)_(?!\w)|(?<![\w*])\*(?![*\s])(.+?)\*(?![\w*])',
  dotAll: true,
);

List<Segment> _inlineOf(String text, Segment base) {
  final out = <Segment>[];
  var at = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > at) out.add(base.copyWith(text: text.substring(at, m.start)));
    final linkText = m[1];
    final bold = m[3] ?? m[4];
    if (linkText != null) {
      out.addAll(_inlineOf(linkText, _linkTo(base, m[2]!)));
    } else if (bold != null) {
      out.addAll(_inlineOf(bold, base.copyWith(bold: true)));
    } else {
      out.addAll(_inlineOf((m[5] ?? m[6])!, base.copyWith(italic: true)));
    }
    at = m.end;
  }
  if (at < text.length) out.add(base.copyWith(text: text.substring(at)));
  return out;
}

/// Joins neighbours that look the same, so a spoiler or a bold run is one piece.
List<Segment> _merge(List<Segment> segments) {
  final out = <Segment>[];
  for (final s in segments) {
    if (out.isNotEmpty && out.last._looksLike(s)) {
      out.last = out.last.copyWith(text: out.last.text + s.text);
    } else {
      out.add(s);
    }
  }
  return out;
}

/// Drops what can't be shown as text (images, videos, centring) and any HTML.
String _clean(String markdown) => stripHtml(
  markdown
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'(?:img|webm|youtube)\d*%?\s*\([^)]*\)', caseSensitive: false), '')
      .replaceAll('~~~', '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), ''),
);

final _factLine = RegExp(r'^(?:__|\*\*)([^_*]+?):?(?:__|\*\*):?\s*(.+)$');

/// The leading "__Height:__ 157 cm" lines AniList puts at the top of a
/// description, which its own pages show as facts. Lines with a spoiler stay
/// in the text, where they can be hidden.
({List<Fact> facts, String rest}) _leadingFacts(String text) {
  final facts = <Fact>[];
  final lines = text.split('\n');
  var i = 0;
  for (; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final m = _factLine.firstMatch(line);
    if (m == null || m[2]!.contains('~!')) break;
    final value = _inlineOf(m[2]!, const Segment('')).map((s) => s.text).join().trim();
    if (value.isEmpty) break;
    facts.add((label: m[1]!.trim(), value: value));
  }
  return (facts: facts, rest: lines.sublist(i).join('\n'));
}

final _spoilerMark = RegExp('(~!|!~)');
final _paragraphBreak = RegExp(r'\n[ \t]*\n+');

/// A character's or staff member's description, as facts and paragraphs.
({List<Fact> facts, List<Paragraph> paragraphs}) parseDescription(String? markdown) {
  if (markdown == null || markdown.isEmpty) return (facts: const [], paragraphs: const []);
  final (:facts, :rest) = _leadingFacts(_clean(markdown));

  // spoilers can run across paragraphs, so they're split out first
  final paragraphs = <List<Segment>>[[]];
  var spoiler = false;
  var at = 0;
  final pieces = <String>[];
  for (final m in _spoilerMark.allMatches(rest)) {
    pieces
      ..add(rest.substring(at, m.start))
      ..add(m[0]!);
    at = m.end;
  }
  pieces.add(rest.substring(at));
  for (final piece in pieces) {
    if (piece == '~!' || piece == '!~') {
      spoiler = piece == '~!';
      continue;
    }
    for (final (i, chunk) in piece.split(_paragraphBreak).indexed) {
      if (i > 0) paragraphs.add([]);
      if (chunk.isNotEmpty) paragraphs.last.addAll(_inlineOf(chunk, Segment('', spoiler: spoiler)));
    }
  }
  return (
    facts: facts,
    paragraphs: [
      for (final p in paragraphs)
        if (_trimEnds(_merge(p)) case final merged when merged.isNotEmpty) merged,
    ],
  );
}

/// Trims the paragraph's ends, not the text inside it.
List<Segment> _trimEnds(List<Segment> merged) {
  if (merged.isEmpty) return merged;
  merged.first = merged.first.copyWith(text: merged.first.text.trimLeft());
  merged.last = merged.last.copyWith(text: merged.last.text.trimRight());
  return [
    for (final s in merged)
      if (s.text.isNotEmpty) s,
  ];
}
