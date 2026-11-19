// The top of a staff or character page, ported from the web's
// components/person/{PersonLayout,Bio,RoleCard}.svelte in its phone layout:
// the portrait blurred behind the top, back and share over it; the portrait
// beside the name; other names, Favourite, the bio, the facts and a link to
// AniList; then the page's own sections.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';
import '../detail/detail_data.dart' show InfoRow, favouritesProvider;
import '../detail/detail_sections.dart' show InfoTable;
import 'markdown.dart';
import 'person_data.dart';

const _soft = Color(0xFFD7DBE6);
const _spoilerInk = Color(0xFFFF8A78);
const _pink = Color(0xFFFF8FA8);

/// Where a page lives on the web, for Share.
const _site = 'https://miruyo.jnagra.com';

/// Opens a link from a bio: miruyo's own pages in the app, the rest outside it.
void openHref(BuildContext context, String href, {bool external = false}) {
  if (external) {
    unawaited(launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication));
  } else {
    unawaited(context.push(href));
  }
}

class PersonPage extends ConsumerWidget {
  const PersonPage({
    super.key,
    required this.header,
    required this.kind,
    required this.id,
    required this.sections,
    this.sharePath,
    this.banner,
    this.actions,
    this.squarePortrait = false,
    this.back = true,
    this.wide = const [],
    this.portraitIcon = Symbols.person_rounded,
  });

  final PersonHeader header;
  final FavouriteKind kind;
  final int id;

  /// The page's path on the web, for Share; the person's page by default.
  final String? sharePath;

  /// A picture for the top band (a user's banner); the portrait, blurred, otherwise.
  final String? banner;

  /// In Favourite's place: Follow, or Settings on your own page.
  final Widget? actions;

  /// A user's avatar is square; a person's portrait is 3:4.
  final bool squarePortrait;

  /// In the portrait's place when there's no picture (a studio has none).
  final IconData portraitIcon;

  /// A Back button over the band; off where the page is a tab of its own.
  final bool back;

  /// Sections after [sections] that run edge to edge (rows that pad themselves).
  final List<Widget> wide;

  /// The page's own sections, under the bio and facts.
  final List<Widget> sections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: top + 160,
                width: double.infinity,
                child: _Band(image: banner ?? header.image, blur: banner == null),
              ),
              Positioned(
                top: top + Space.x3,
                left: Space.x3,
                right: Space.x3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (back)
                      RoundIconButton(
                        icon: Symbols.arrow_back_rounded,
                        label: 'Back',
                        onTap: () => context.canPop() ? context.pop() : context.go('/'),
                      )
                    else
                      const SizedBox(),
                    RoundIconButton(
                      icon: Symbols.ios_share_rounded,
                      label: 'Share',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: '$_site/${sharePath ?? '${kind.name}/$id'}'));
                        ref.read(toastProvider.notifier).show('Link copied');
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(Space.gutter, top + 80, Space.gutter, 0),
                child: _Headline(header: header, square: squarePortrait, icon: portraitIcon),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, wide.isEmpty ? Space.x20 : 0),
          sliver: SliverList.list(
            children: [
              if (header.altNames.isNotEmpty || header.spoilerNames.isNotEmpty) ...[
                _OtherNames(header: header),
                const SizedBox(height: Space.x4),
              ],
              actions ?? _FavouriteButton(kind: kind, id: id, header: header),
              if (header.bio.isNotEmpty) ...[const SizedBox(height: Space.x6), Bio(paragraphs: header.bio)],
              if (header.facts.isNotEmpty) ...[
                const SizedBox(height: Space.x6),
                InfoTable(rows: [for (final f in header.facts) InfoRow(f.label, f.value)]),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(header.anilist, mode: LaunchMode.externalApplication),
                  style: TextButton.styleFrom(
                    foregroundColor: TextTone.mid,
                    minimumSize: const Size(0, Space.minTarget),
                    padding: EdgeInsets.zero,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Symbols.open_in_new_rounded, size: 16),
                  label: Text('View on AniList', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              ...sections,
            ],
          ),
        ),
        if (wide.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Space.x20),
            sliver: SliverList.list(children: wide),
          ),
      ],
    );
  }
}

/// The portrait, blurred, behind the top of the page.
class _Band extends StatelessWidget {
  const _Band({required this.image, this.blur = true});

  final String? image;

  /// A portrait is blurred into a backdrop; a banner shows as it is.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Opacity(
              opacity: blur ? 0.6 : 1,
              child: ImageFiltered(
                enabled: blur,
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40, tileMode: TileMode.decal),
                child: CachedNetworkImage(imageUrl: image!, fit: BoxFit.cover),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Surface.base, Color(0x8C090B11), Color(0x40090B11)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.header, this.square = false, this.icon = Symbols.person_rounded});

  final PersonHeader header;
  final bool square;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Portrait(
          image: header.image,
          width: 112,
          height: square ? 112 : 150,
          radius: 10,
          label: header.name,
          placeholder: icon,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.x1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(header.name, style: AppType.heading.copyWith(fontSize: 24, height: 1.05)),
                ),
                if (header.native != null) ...[
                  const SizedBox(height: 6),
                  Text(header.native!, style: AppType.body.copyWith(fontSize: 13, color: TextTone.mid)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A person's picture, on a gradient while it loads (or when there's none).
class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.image,
    required this.width,
    required this.height,
    this.radius = 0,
    this.label,
    this.placeholder = Symbols.person_rounded,
  });

  final String? image;
  final double width;
  final double height;
  final double radius;

  /// Shown without a picture: a person, or a studio's icon.
  final IconData placeholder;

  /// Read out as an image; null keeps it out of the semantics tree.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: label != null,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF262C3D), Color(0xFF161A26)],
          ),
        ),
        child: image == null
            ? Icon(placeholder, color: TextTone.low, size: width > 64 ? 36 : null)
            : CachedNetworkImage(imageUrl: image!, fit: BoxFit.cover, alignment: Alignment.topCenter),
      ),
    );
  }
}

class _OtherNames extends StatefulWidget {
  const _OtherNames({required this.header});

  final PersonHeader header;

  @override
  State<_OtherNames> createState() => _OtherNamesState();
}

class _OtherNamesState extends State<_OtherNames> {
  bool _spoilers = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.header;
    final style = AppType.body.copyWith(fontSize: 13, color: TextTone.mid);
    final count = h.spoilerNames.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (h.altNames.isNotEmpty)
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Also known as ',
                  style: TextStyle(color: TextTone.low),
                ),
                TextSpan(text: h.altNames.join(' · ')),
              ],
            ),
            style: style,
          ),
        if (count > 0)
          _spoilers
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.x1),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Spoiler names ',
                          style: TextStyle(color: TextTone.low),
                        ),
                        TextSpan(text: h.spoilerNames.join(' · ')),
                      ],
                    ),
                    style: style.copyWith(color: _spoilerInk),
                  ),
                )
              : TextButton(
                  onPressed: () => setState(() => _spoilers = true),
                  style: TextButton.styleFrom(
                    foregroundColor: TextTone.mid,
                    minimumSize: const Size(0, Space.minTarget),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Show $count spoiler ${count == 1 ? 'name' : 'names'}',
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
      ],
    );
  }
}

class _FavouriteButton extends ConsumerWidget {
  const _FavouriteButton({required this.kind, required this.id, required this.header});

  final FavouriteKind kind;
  final int id;
  final PersonHeader header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(favouritesProvider.select((f) => f[(kind, id)])) ?? header.isFavourite;

    Future<void> toggle() async {
      if (ref.read(sessionProvider).authState != AuthState.signedIn) {
        unawaited(context.push('/login'));
        return;
      }
      unawaited(ref.read(hapticsProvider).play(on ? Haptic.light : Haptic.success));
      final ok = await ref.read(favouritesProvider.notifier).toggle(kind, id, was: on);
      if (!ok) {
        ref.read(toastProvider.notifier).show("Couldn't update your favourites. Try again.", tone: ToastTone.error);
      }
    }

    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: on ? 'Favourite' : 'Add to favourites',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: toggle,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, Space.minTarget),
          backgroundColor: Surface.s1,
          foregroundColor: on ? _pink : TextTone.high,
          side: const BorderSide(color: Surface.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.favorite_rounded, size: 20, fill: on ? 1 : 0),
            const SizedBox(width: Space.x2),
            Text(
              on ? 'Favourite' : 'Add to favourites',
              style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: on ? _pink : TextTone.high),
            ),
            const SizedBox(width: Space.x2),
            Text(header.favourites, style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.low)),
          ],
        ),
      ),
    );
  }
}

/// A character's or staff member's description, from parseDescription: text
/// only. Spoilers hide behind a chip until one is tapped, which shows them
/// all; a long bio folds under "Read more".
class Bio extends StatefulWidget {
  const Bio({super.key, required this.paragraphs});

  final List<Paragraph> paragraphs;

  @override
  State<Bio> createState() => _BioState();
}

class _BioState extends State<Bio> {
  bool _open = false;
  bool _spoilers = false;

  /// About seven lines of text.
  bool get _long =>
      widget.paragraphs.fold(0, (n, p) => n + p.fold(0, (m, s) => m + s.text.length)) > 700 ||
      widget.paragraphs.length > 4;

  InlineSpan _span(Segment s) {
    final style = TextStyle(fontWeight: s.bold ? FontWeight.w700 : null, fontStyle: s.italic ? FontStyle.italic : null);
    if (s.spoiler && !_spoilers) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Semantics(
          container: true,
          button: true,
          label: 'Spoiler, show',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => setState(() => _spoilers = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 2),
              decoration: BoxDecoration(
                color: _spoilerInk.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Corner.full),
                border: Border.all(color: _spoilerInk.withValues(alpha: 0.35)),
              ),
              child: Text('Spoiler', style: AppType.caption.copyWith(color: _spoilerInk)),
            ),
          ),
        ),
      );
    }
    if (s.href case final href?) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Semantics(
          container: true,
          link: true,
          child: GestureDetector(
            onTap: () => openHref(context, href, external: s.external),
            child: Text(
              s.text,
              style: AppType.bodyL
                  // underlined in its own colour: a dimmer line read as the link's colour, below contrast
                  .copyWith(color: TextTone.high, decoration: TextDecoration.underline, decorationColor: TextTone.high)
                  .merge(style),
            ),
          ),
        ),
      );
    }
    return TextSpan(
      text: s.text,
      style: s.spoiler ? style.copyWith(backgroundColor: _spoilerInk.withValues(alpha: 0.08)) : style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, p) in widget.paragraphs.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Space.x3),
            child: Text.rich(
              TextSpan(children: [for (final s in p) _span(s)]),
              style: AppType.bodyL.copyWith(color: _soft, fontSize: 15),
            ),
          ),
      ],
    );
    final folded = _long && !_open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (folded)
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.6, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ClipRect(
                child: OverflowBox(alignment: Alignment.topLeft, maxHeight: double.infinity, child: text),
              ),
            ),
          )
        else
          text,
        if (_long)
          TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              foregroundColor: TextTone.mid,
              minimumSize: const Size(0, Space.minTarget),
              padding: EdgeInsets.zero,
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(_open ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, size: 18),
            label: Text(_open ? 'Show less' : 'Read more', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}

/// A round button over a picture: back, share.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: const Color(0x99090B11),
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: Space.minTarget,
                child: Icon(icon, size: 22, color: TextTone.high),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section heading, with an optional control at its end.
class PersonSectionHeading extends StatelessWidget {
  const PersonSectionHeading({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x8, bottom: Space.x4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(text, style: AppType.section.copyWith(fontSize: 22))),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Someone on a role card: a character (on a staff page) or a voice actor
/// (on a character page).
typedef RolePerson = ({String href, String name, String? image, String? caption});

/// A title in someone's roles: its cover and name (opening the title), your
/// status if it's on your list, what they did on it, and who they played or
/// who voiced them.
class RoleCard extends ConsumerWidget {
  const RoleCard({super.key, required this.media, this.caption, this.people = const []});

  final MediaCard media;

  /// Under the title: a credit's roles, or a character's role in it.
  final String? caption;
  final List<RolePerson> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final status = signedIn ? ref.watch(listStoreProvider.select((l) => l[media.id]?.status)) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          button: true,
          label: [
            media.title,
            if (media.meta.isNotEmpty) media.meta,
            if (status != null) statusLabel(status, isAnime: media.isAnime),
          ].join(', '),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/title/${media.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: media.colors.base, borderRadius: BorderRadius.circular(Corner.sm)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (media.cover != null) CachedNetworkImage(imageUrl: media.cover!, fit: BoxFit.cover),
                        if (status != null)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xCC090B11),
                                borderRadius: BorderRadius.circular(Corner.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: statusColor[status], shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: Space.x1),
                                  Text(
                                    statusLabel(status, isAnime: media.isAnime),
                                    style: AppType.caption.copyWith(fontSize: 10, color: TextTone.high),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  media.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(fontSize: 13, height: 1.25, fontWeight: FontWeight.w600),
                ),
                if (media.meta.isNotEmpty)
                  Text(media.meta, style: AppType.caption.copyWith(fontSize: 11, color: TextTone.low)),
              ],
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(fontSize: 11, color: TextTone.mid, fontWeight: FontWeight.w400),
          ),
        ],
        for (final p in people)
          Semantics(
            container: true,
            button: true,
            label: [p.name, ?p.caption].join(', '),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => context.push(p.href),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Space.minTarget),
                child: Row(
                  children: [
                    Portrait(image: p.image, width: 28, height: 28, radius: Corner.full),
                    const SizedBox(width: Space.x2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(height: 1.15, fontWeight: FontWeight.w600),
                          ),
                          if (p.caption != null)
                            Text(
                              p.caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(fontSize: 11, color: TextTone.low),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Role cards three across.
class RoleGrid extends StatelessWidget {
  const RoleGrid({super.key, required this.cards, this.faded = false});

  final List<Widget> cards;

  /// While a new sort loads.
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: faded ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: Column(
        children: [
          for (var i = 0; i < cards.length; i += 3)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : Space.x5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = i; j < i + 3; j++) ...[
                    if (j > i) const SizedBox(width: Space.x3),
                    Expanded(child: j < cards.length ? cards[j] : const SizedBox()),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Load more" under a section, or why it couldn't.
class LoadMore extends StatelessWidget {
  const LoadMore({super.key, required this.loading, required this.failed, required this.onTap, required this.what});

  final bool loading;
  final bool failed;
  final VoidCallback onTap;

  /// "roles", "titles": for the error.
  final String what;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x5),
      child: Column(
        children: [
          if (failed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Text("Couldn't load more $what", style: AppType.body.copyWith(color: TextTone.mid)),
            ),
          OutlinedButton(
            onPressed: loading ? null : onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, Space.minTarget),
              backgroundColor: Surface.s1,
              foregroundColor: TextTone.high,
              side: const BorderSide(color: Surface.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              loading ? 'Loading…' : (failed ? 'Try again' : 'Load more'),
              style: AppType.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
