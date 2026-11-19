import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/catalog/title.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/poster_row.dart' show SectionHeading;
import 'detail_data.dart';

const _soft = Color(0xFFDDD3C3);

/// The facts, as a two-column table on a raised card.
class InfoTable extends StatelessWidget {
  const InfoTable({super.key, required this.rows});

  final List<InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x1),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed)
            Container(
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Surface.line)),
              ),
              child: switch (row.href) {
                // a row that leads somewhere (the studio) is a 44pt link
                final href? => Semantics(
                  link: true,
                  label: '${row.label}: ${row.value}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => context.push(href),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Space.minTarget),
                      child: _InfoLine(row: row, link: true),
                    ),
                  ),
                ),
                null => _InfoLine(row: row),
              },
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.row, this.link = false});

  final InfoRow row;
  final bool link;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: link ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(row.label, style: AppType.body.copyWith(fontSize: 13, color: TextTone.low)),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: AppType.body.copyWith(
                fontSize: 13,
                color: _soft,
                decoration: link ? TextDecoration.underline : null,
                decorationColor: TextTone.low,
              ),
            ),
          ),
          if (link) ...[
            const SizedBox(width: 2),
            const Icon(Symbols.chevron_right_rounded, size: 16, color: TextTone.low),
          ],
        ],
      ),
    );
  }
}

/// A heading with an optional "All →" that switches tabs.
class DetailHeading extends StatelessWidget {
  const DetailHeading({super.key, required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // the shared heading: serif, a hairline out to the action
    return SectionHeading(
      heading: text,
      padding: EdgeInsets.zero,
      trailing: action == null
          ? null
          : TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: TextTone.mid, minimumSize: const Size(0, Space.minTarget)),
              child: Text(
                action!,
                style: AppType.body.copyWith(fontWeight: FontWeight.w500, color: TextTone.mid),
              ),
            ),
    );
  }
}

Color _relationColor(String kind) => switch (kind) {
  'SOURCE' => Accent.fujiText,
  'PREQUEL' || 'SEQUEL' => Accent.soraText,
  'ADAPTATION' => Accent.beniText,
  _ => TextTone.mid,
};

class RelationList extends StatelessWidget {
  const RelationList({super.key, required this.relations});

  final List<RelationCard> relations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in relations)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x3),
            child: Material(
              // a ruled row, not a card
              color: Colors.transparent,
              shape: const Border(bottom: BorderSide(color: Surface.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(Corner.md),
                onTap: () => context.push('/title/${r.id}'),
                child: Container(
                  padding: const EdgeInsets.all(Space.x3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Corner.md),
                    border: Border.all(color: const Color(0x0FFFFFFF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 120,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: coverGradient(r.colors),
                        ),
                        child: r.cover == null ? null : CachedNetworkImage(imageUrl: r.cover!, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: Space.x4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.relation.toUpperCase(),
                              style: AppType.overline.copyWith(color: _relationColor(r.kind)),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.title.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(r.meta, style: AppType.caption.copyWith(color: TextTone.low)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.image, required this.width, required this.height, this.radius = 0});

  final String? image;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Surface.s4, Surface.s2],
        ),
      ),
      child: image == null
          ? const Icon(Symbols.person_rounded, color: TextTone.low)
          : CachedNetworkImage(imageUrl: image!, fit: BoxFit.cover),
    );
  }
}

/// Overview's sideways rail of characters.
class CharacterRail extends StatelessWidget {
  const CharacterRail({super.key, required this.characters});

  final List<CharacterCard> characters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
        itemBuilder: (context, i) {
          final c = characters[i];
          return SizedBox(
            width: 80,
            child: _PersonLink(
              href: '/character/${c.id}',
              label: c.name,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Portrait(image: c.image, width: 80, height: 106, radius: Corner.sm),
                  const SizedBox(height: 6),
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(fontSize: 13, height: 1.15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The Characters & Staff tab: each character beside their voice actor.
class CharacterList extends StatelessWidget {
  const CharacterList({super.key, required this.characters});

  final List<CharacterCard> characters;

  @override
  Widget build(BuildContext context) {
    final name = AppType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    final role = AppType.caption.copyWith(fontSize: 11, color: TextTone.low, fontWeight: FontWeight.w400);
    return Column(
      children: [
        for (final c in characters)
          Container(
            margin: const EdgeInsets.only(bottom: Space.x2),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Surface.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PersonLink(
                    href: '/character/${c.id}',
                    label: '${c.name}, ${c.role}',
                    child: Row(
                      children: [
                        _Portrait(image: c.image, width: 48, height: 64),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: name),
                                Text(c.role, style: role),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (c.voice case final voice?)
                  Expanded(
                    child: _PersonLink(
                      href: '/staff/${voice.id}',
                      label: '${voice.name}, ${voice.role}',
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(voice.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: name),
                                  Text(voice.role, style: role),
                                ],
                              ),
                            ),
                          ),
                          _Portrait(image: voice.image, width: 48, height: 64),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Recommendations as a three-across poster grid (five on a wide screen).
class RecommendationGrid extends StatelessWidget {
  const RecommendationGrid({super.key, required this.titles});

  final List<Title> titles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 5 : 3;
        final width = (constraints.maxWidth - Space.x2 * (columns - 1)) / columns;
        return Wrap(
          spacing: Space.x2,
          runSpacing: Space.x5,
          children: [
            for (final t in titles)
              SizedBox(
                width: width,
                child: PosterCard(title: t),
              ),
          ],
        );
      },
    );
  }
}

/// Manga's publication card: chapters and volumes.
class PublicationCard extends StatelessWidget {
  const PublicationCard({super.key, required this.title, required this.overline});

  final Title title;
  final String overline;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x9913110F), borderRadius: BorderRadius.circular(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppType.numeric.copyWith(fontSize: 28, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PUBLICATION', style: AppType.overline.copyWith(color: TextTone.mid)),
          const SizedBox(height: Space.x4),
          Row(
            children: [
              stat(title.total?.toString() ?? '—', title.total != null ? 'Chapters' : 'Chapters (ongoing)'),
              const SizedBox(width: 10),
              stat(title.vol?.toString() ?? '—', 'Volumes'),
            ],
          ),
          const SizedBox(height: Space.x4),
          Wrap(
            spacing: Space.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: title.colors.tint, borderRadius: BorderRadius.circular(Corner.full)),
                child: Text(
                  title.status,
                  style: AppType.caption.copyWith(color: title.colors.accent, fontWeight: FontWeight.w600),
                ),
              ),
              Text(overline, style: AppType.body.copyWith(fontSize: 13, color: _soft)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where to watch (anime) or read (manga): above the tabs, so it's there on
/// every tab. A manga can have a dozen reading links (one per language), so
/// the first six, then "N more".
class WatchLinks extends StatefulWidget {
  const WatchLinks({super.key, required this.links, required this.isAnime});

  final List<LinkChip> links;
  final bool isAnime;

  static const preview = 6;

  @override
  State<WatchLinks> createState() => _WatchLinksState();
}

class _WatchLinksState extends State<WatchLinks> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final links = widget.links;
    final more = links.length - WatchLinks.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  widget.isAnime ? 'WHERE TO WATCH' : 'WHERE TO READ',
                  style: AppType.overline.copyWith(color: TextTone.mid),
                ),
              ),
            ),
            if (more > 0)
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                style: TextButton.styleFrom(foregroundColor: TextTone.mid, minimumSize: const Size(0, Space.minTarget)),
                child: Text(
                  _open ? 'Show fewer' : '$more more',
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: TextTone.mid),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        LinkChips(links: _open ? links : links.take(WatchLinks.preview).toList()),
      ],
    );
  }
}

/// Links to other sites: the site's logo on its colour, its name, and what
/// tells two links to one site apart ("Thai", "Muse Asia").
class LinkChips extends StatelessWidget {
  const LinkChips({super.key, required this.links});

  final List<LinkChip> links;

  static Color? _color(String? hex) => hex == null ? null : Color(int.parse('FF${hex.substring(1)}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.x2,
      runSpacing: Space.x2,
      children: [
        for (final l in links)
          Semantics(
            container: true,
            link: true,
            label: [l.site, if (l.detail.isNotEmpty) l.detail, 'opens outside miruyo'].join(', '),
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
                side: const BorderSide(color: Surface.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => launchUrl(l.url, mode: LaunchMode.externalApplication),
                child: Container(
                  height: Space.minTarget,
                  padding: const EdgeInsets.only(left: Space.x2, right: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _color(l.color) ?? const Color(0xFF25211C),
                          borderRadius: BorderRadius.circular(Corner.sm),
                        ),
                        child: l.icon == null
                            ? const Icon(Symbols.open_in_new_rounded, size: 16, color: TextTone.high)
                            : CachedNetworkImage(
                                imageUrl: l.icon.toString(),
                                width: 16,
                                height: 16,
                                errorWidget: (_, _, _) =>
                                    const Icon(Symbols.open_in_new_rounded, size: 16, color: TextTone.high),
                              ),
                      ),
                      const SizedBox(width: Space.x2),
                      Flexible(
                        child: Text(
                          l.site,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (l.detail.isNotEmpty) ...[
                        const SizedBox(width: Space.x2),
                        Flexible(
                          child: Text(
                            l.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A title's tags, best fit first, each opening Browse filtered by it.
/// Spoiler tags stay hidden until asked for.
class TagWrap extends StatefulWidget {
  const TagWrap({super.key, required this.tags});

  final List<TagChip> tags;

  @override
  State<TagWrap> createState() => _TagWrapState();
}

class _TagWrapState extends State<TagWrap> {
  bool _spoilers = false;

  /// A title can carry thirty tags: the best-fitting few (they're ranked by
  /// fit), then "N more", as on the web.
  static const preview = 8;
  bool _open = false;

  static const _spoilerInk = Color(0xFFF07A63);

  @override
  Widget build(BuildContext context) {
    final spoilerCount = widget.tags.where((t) => t.spoiler).length;
    final shown = widget.tags.where((t) => _spoilers || !t.spoiler).toList();
    final visible = _open ? shown : shown.take(preview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailHeading(
          text: 'Tags',
          action: spoilerCount == 0
              ? null
              : _spoilers
              ? 'Hide spoilers'
              : 'Show $spoilerCount spoiler${spoilerCount == 1 ? '' : 's'}',
          onAction: () => setState(() {
            _spoilers = !_spoilers;
            // a spoiler can rank below the fold: showing them shows them all
            if (_spoilers) _open = true;
          }),
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 0,
            children: [
              for (final t in visible)
                // like the genre chips: a 48pt tap area around the chip
                ActionChip(
                  tooltip: t.description,
                  onPressed: () => context.go('/browse?tag=${Uri.encodeComponent(t.name)}'),
                  backgroundColor: Surface.base,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  labelPadding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Semantics(
                    label: '${t.name}, ${t.rank}%${t.spoiler ? ', spoiler' : ''}',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.name, style: AppType.body.copyWith(color: t.spoiler ? _spoilerInk : _soft)),
                        const SizedBox(width: 6),
                        Text('${t.rank}%', style: AppType.numeric.copyWith(fontSize: 11, color: TextTone.low)),
                      ],
                    ),
                  ),
                ),
              if (shown.length > preview)
                Semantics(
                  expanded: _open,
                  child: ActionChip(
                    onPressed: () => setState(() => _open = !_open),
                    backgroundColor: Surface.base,
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _open ? 'Show fewer' : '${shown.length - preview} more',
                          style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _open ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                          size: 18,
                          color: TextTone.mid,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Opens a character's or staff member's page.
class _PersonLink extends StatelessWidget {
  const _PersonLink({required this.href, required this.label, required this.child});

  final String href;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(onTap: () => context.push(href), child: child),
    );
  }
}

/// Manga: the people credited with story and art, each opening their page.
class AuthorsCard extends StatelessWidget {
  const AuthorsCard({super.key, required this.authors});

  final List<Person> authors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.x5, Space.x4, Space.x5, Space.x3),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUTHORS', style: AppType.overline.copyWith(color: TextTone.mid)),
          const SizedBox(height: Space.x2),
          for (final a in authors)
            _PersonLink(
              href: '/staff/${a.id}',
              label: '${a.name}, ${a.role}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ClipOval(child: _Portrait(image: a.image, width: 52, height: 52)),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name, style: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(a.role, style: AppType.body.copyWith(fontSize: 13, color: TextTone.low)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
