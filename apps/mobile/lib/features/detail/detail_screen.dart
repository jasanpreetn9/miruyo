import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/airing.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/progress.dart';
import '../../core/catalog/score.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/notifications/episode_alerts.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/halftone.dart';
import '../../widgets/motion.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../editor/list_editor.dart';
import '../shell/drag_to_close.dart';
import 'detail_data.dart';
import 'detail_sections.dart';
import 'title_stats_tab.dart';

enum _Tab {
  overview('Overview'),
  relations('Relations'),
  characters('Characters & Staff'),
  stats('Stats'),
  recommendations('Recommendations');

  const _Tab(this.label);
  final String label;
}

/// The title page (03). The title's cover colour owns the page: banner,
/// glow, progress and the countdown all derive from it while the chrome
/// stays constant. On phones the facts sit above the tabs, which stick
/// under the header.
class DetailScreen extends ConsumerStatefulWidget {
  const DetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  _Tab _tab = _Tab.overview;
  bool _synopsisOpen = false;

  /// The top bar under the status bar: back, and the title once scrolled.
  static const _bar = 52.0;

  /// How far the page has scrolled, for the top bar.
  final _offset = ValueNotifier<double>(0);

  /// The title the mode was last switched for.
  int? _modeSetFor;

  @override
  void initState() {
    super.initState();
    // The top bar's Anime / Manga switch follows the title you open, so a
    // manga's page says Manga (and Browse, My List… carry on in manga). Once
    // per title: switching back by hand while you're here stays switched.
    ref.listenManual(detailProvider(widget.id), (_, next) {
      final title = next.value?.title;
      if (title == null || title.id == _modeSetFor) return;
      _modeSetFor = title.id;
      // not while building: the cached page arrives during initState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(modeProvider.notifier).set(title.isAnime ? Mode.anime : Mode.manga);
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailProvider(widget.id));
    return Scaffold(
      // DragToClose paints the page, so the one behind can show through
      backgroundColor: detail is AsyncData ? Colors.transparent : null,
      body: switch (detail) {
        AsyncData(:final value) => Appear(child: _content(value)),
        AsyncError(error: TitleNotFound()) => _NotFound(onBack: _back),
        AsyncError(:final error) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Space.gutter),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _RoundButton(icon: Symbols.arrow_back_rounded, label: 'Back', onTap: _back),
              ),
              const SizedBox(height: Space.x6),
              SectionError(
                title: "Couldn't load this title",
                error: error,
                onRetry: () => ref.invalidate(detailProvider(widget.id)),
              ),
            ],
          ),
        ),
        _ => const _DetailSkeleton(),
      },
    );
  }

  void _back() => context.canPop() ? context.pop() : context.go('/');

  Widget _content(DetailContent content) {
    final title = content.title;
    final top = MediaQuery.paddingOf(context).top;

    // The page scrolls below the top bar, so the tabs pin under it; the
    // banner still bleeds up behind it. Back stays put, and the bar fills in
    // with the title once the headline has scrolled under it.
    Widget page(ScrollPhysics physics) => NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (n.depth == 0) _offset.value = n.metrics.pixels;
        return false;
      },
      child: CustomScrollView(
        clipBehavior: Clip.none,
        physics: physics,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -(top + _bar),
                  left: 0,
                  right: 0,
                  height: top + _bar + 150,
                  child: _Banner(title: title),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
                  child: _Headline(title: title, altTitles: content.altTitles),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x5, Space.gutter, 0),
            sliver: SliverList.list(
              children: [
                if (title.next != null) ...[_CountdownStrip(title: title), const SizedBox(height: Space.x6)],
                _StatusPanel(title: title, isFavourite: content.isFavourite),
                const SizedBox(height: Space.x6),
                _Stats(content: content),
                if (title.synopsis != null && title.synopsis!.isNotEmpty) ...[
                  const SizedBox(height: Space.x6),
                  _Synopsis(
                    text: title.synopsis!,
                    open: _synopsisOpen,
                    onToggle: () => setState(() => _synopsisOpen = !_synopsisOpen),
                  ),
                ],
                const SizedBox(height: Space.x6),
                InfoTable(rows: content.info),
                const SizedBox(height: Space.x6),
                // where to watch / read: above the tabs, so it's there on every tab
                if (content.watch.isNotEmpty) ...[
                  WatchLinks(links: content.watch, isAnime: title.isAnime),
                  const SizedBox(height: Space.x6),
                ],
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(
              selected: _tab,
              accent: context.mode.accent,
              onSelect: (t) => setState(() => _tab = t),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x6, Space.gutter, Space.x20),
            sliver: SliverList.list(children: _panel(content)),
          ),
        ],
      ),
    );

    return DragToClose(
      onClose: _back,
      builder: (context, physics) => Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: top + _bar),
            child: page(physics),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + _bar,
            child: ValueListenableBuilder<double>(
              valueListenable: _offset,
              builder: (context, offset, _) {
                // the bar fills in as the banner goes, the title once the headline has
                final fill = ((offset - 40) / 80).clamp(0.0, 0.92);
                final named = ((offset - 120) / 40).clamp(0.0, 1.0);
                return ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12 * fill, sigmaY: 12 * fill),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(Space.x3, top, Space.gutter, 0),
                      decoration: BoxDecoration(
                        color: Surface.base.withValues(alpha: fill),
                        border: Border(
                          bottom: BorderSide(color: Surface.line.withValues(alpha: named * 0.08)),
                        ),
                      ),
                      child: Row(
                        children: [
                          _RoundButton(icon: Symbols.arrow_back_rounded, label: 'Back', onTap: _back),
                          const SizedBox(width: Space.x3),
                          Expanded(
                            child: Opacity(
                              opacity: named,
                              child: ExcludeSemantics(
                                excluding: named < 1,
                                child: Text(
                                  title.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.title.copyWith(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _panel(DetailContent content) {
    final empty = AppType.body.copyWith(color: TextTone.mid);
    switch (_tab) {
      case _Tab.overview:
        return [
          if (content.tags.isNotEmpty) ...[TagWrap(tags: content.tags), const SizedBox(height: Space.x8)],
          if (!content.title.isAnime) ...[
            PublicationCard(title: content.title, overline: content.overline),
            if (content.authors.isNotEmpty) ...[
              const SizedBox(height: Space.x3),
              AuthorsCard(authors: content.authors),
            ],
            const SizedBox(height: Space.x8),
          ],
          if (content.relations.isNotEmpty) ...[
            DetailHeading(
              text: 'Relations',
              action: content.relations.length > 3 ? 'All ${content.relations.length} →' : null,
              onAction: () => setState(() => _tab = _Tab.relations),
            ),
            const SizedBox(height: 14),
            RelationList(relations: content.relations.take(3).toList()),
            const SizedBox(height: Space.x6),
          ],
          if (content.characters.isNotEmpty) ...[
            DetailHeading(text: 'Characters', action: 'All →', onAction: () => setState(() => _tab = _Tab.characters)),
            const SizedBox(height: 14),
            CharacterRail(characters: content.characters),
            const SizedBox(height: Space.x8),
          ],
          if (content.recommendations.isNotEmpty) ...[
            const DetailHeading(text: 'If you like this'),
            const SizedBox(height: 14),
            RecommendationGrid(titles: content.recommendations),
            const SizedBox(height: Space.x8),
          ],
          // the official site, socials and other names close the Overview
          if (content.links.isNotEmpty) ...[
            const DetailHeading(text: 'Links'),
            const SizedBox(height: 14),
            LinkChips(links: content.links),
            const SizedBox(height: Space.x8),
          ],
          if (content.synonyms.isNotEmpty) ...[
            const DetailHeading(text: 'Also known as'),
            const SizedBox(height: Space.x2),
            Text(content.synonyms.join(' · '), style: AppType.body.copyWith(color: TextTone.mid, height: 1.6)),
          ],
        ];
      case _Tab.relations:
        return content.relations.isEmpty
            ? [Text('No related titles on AniList.', style: empty)]
            : [RelationList(relations: content.relations)];
      case _Tab.characters:
        return content.characters.isEmpty
            ? [Text('No characters listed on AniList yet.', style: empty)]
            : [CharacterList(characters: content.characters)];
      case _Tab.stats:
        return [
          TitleStatsTab(id: content.title.id, isAnime: content.title.isAnime, accent: content.title.colors.accent),
        ];
      case _Tab.recommendations:
        return content.recommendations.isEmpty
            ? [Text('No recommendations yet.', style: empty)]
            : [RecommendationGrid(titles: content.recommendations)];
    }
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: Space.minTarget,
              height: Space.minTarget,
              color: const Color(0x9913110F),
              child: Icon(icon, size: 22, color: TextTone.high),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banner bleeds edge to edge and fades into the page, editorial: the
/// art in two tones (the cover's colour and the page), under a dot screen.
/// Without one, the cover stands in, blurred and enlarged.
class _Banner extends StatelessWidget {
  const _Banner({required this.title});

  final Title title;

  @override
  Widget build(BuildContext context) {
    final image = title.bannerUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          // duotone: the art in greys, multiplied by the cover's colour
          ColorFiltered(
            // modulate, not multiply: transparent pixels (before the image loads, or
            // past its edges) stay transparent instead of filling with the colour
            colorFilter: ColorFilter.mode(title.colors.accent, BlendMode.modulate),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
            ),
          )
        else
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Transform.scale(scale: 1.4, child: CoverImage(title: title, radius: 0, showMissing: false)),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Surface.base, Color(0x8013110F), Color(0x1A13110F)],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
        // the dot screen over it
        const Halftone(color: Surface.base, spacing: 5, radius: 0.8, fade: 1.4, opacity: 0.55),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.title, this.altTitles = ''});

  final Title title;

  /// The English / native names, when they differ from the headline.
  final String altTitles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 104,
          margin: const EdgeInsets.only(right: 6, bottom: 6),
          decoration: BoxDecoration(boxShadow: offsetShadow(title.colors.accent)),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: CoverImage(title: title),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.x1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (no ANIME / MANGA badge: the top bar's mode already says)
                Semantics(
                  header: true,
                  child: Text(
                    title.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(30, height: 0.98, weight: FontWeight.w600, tracking: -0.03),
                  ),
                ),
                if (altTitles.isNotEmpty) ...[
                  const SizedBox(height: Space.x1),
                  Text(
                    altTitles,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontSize: 13, color: TextTone.mid),
                  ),
                ],
                const SizedBox(height: 6),
                // the score is in the row below, large
                Text(
                  [title.knownFormat, title.knownCount].whereType<String>().join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "EP 9 airs Fri, Oct 9 · 23:00 · 2d 04h 31m", in the cover colour.
class _CountdownStrip extends ConsumerWidget {
  const _CountdownStrip({required this.title});

  final Title title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = title.next!;
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final phase = airingPhase(next.airingAt, now);
    if (phase == AiringPhase.aired) return const SizedBox.shrink();
    final left = (next.airingAt - now).clamp(0, 1 << 31);
    final d = left ~/ 86400, h = (left % 86400) ~/ 3600, m = (left % 3600) ~/ 60;
    String two(int n) => n.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Accent.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              phase == AiringPhase.live
                  ? 'EP ${next.ep} is airing now'
                  : 'EP ${next.ep} airs ${formatAiringLong(next.airingAt)}',
              style: AppType.body.copyWith(fontSize: 13, color: const Color(0xFFDDD3C3)),
            ),
          ),
          if (phase != AiringPhase.live) ...[
            Text(
              '${d}d ${two(h)}h ${two(m)}m',
              style: AppType.numeric.copyWith(fontWeight: FontWeight.w600, color: title.colors.accent),
            ),
            if (title.isAnime) _RemindButton(title: title),
          ],
        ],
      ),
    );
  }
}

/// "Remind me": a notification on this phone when the next episode airs,
/// for anything, on the list or not. The bell stays filled while it's set.
class _RemindButton extends ConsumerWidget {
  const _RemindButton({required this.title});

  final Title title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = title.next!;
    final set = ref.watch(remindersProvider.select((r) => r.any((x) => x.mediaId == title.id && x.episode == next.ep)));

    Future<void> toggle() async {
      final reminders = ref.read(remindersProvider.notifier);
      final toasts = ref.read(toastProvider.notifier);
      final haptics = ref.read(hapticsProvider);
      if (set) {
        await reminders.remove(title.id);
        unawaited(haptics.play(Haptic.light));
        toasts.show('Reminder off · ${title.title}');
        return;
      }
      final added = await reminders.add(
        EpisodeAlert(
          mediaId: title.id,
          title: title.title,
          episode: next.ep,
          at: DateTime.fromMillisecondsSinceEpoch(next.airingAt * 1000, isUtc: true),
        ),
      );
      if (added) {
        unawaited(haptics.play(Haptic.success));
        toasts.show('Reminder · EP ${next.ep} ${formatAiringLong(next.airingAt)}', tone: ToastTone.success);
      } else {
        toasts.show('Notifications are off for miruyo. Turn them on in the Settings app.', tone: ToastTone.error);
      }
    }

    return Semantics(
      button: true,
      toggled: set,
      label: set ? 'Reminder set for episode ${next.ep}' : 'Remind me when episode ${next.ep} airs',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(toggle()),
        child: SizedBox(
          width: Space.minTarget,
          height: 28,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(
              set ? Symbols.notifications_active_rounded : Symbols.notifications_rounded,
              fill: set ? 1 : 0,
              size: 20,
              color: set ? Accent.sora : TextTone.mid,
            ),
          ),
        ),
      ),
    );
  }
}

/// The heart beside the status button: an AniList favourite, saved straight
/// away (signed out, it leads to Log In).
class _FavouriteButton extends ConsumerWidget {
  const _FavouriteButton({required this.title, required this.isFavourite});

  final Title title;
  final bool isFavourite;

  static const _pink = Color(0xFFFF8FA8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (FavouriteKind.of(title.type), title.id);
    final on = ref.watch(favouritesProvider.select((f) => f[key])) ?? isFavourite;

    Future<void> toggle() async {
      if (ref.read(sessionProvider).authState != AuthState.signedIn) {
        unawaited(context.push('/login'));
        return;
      }
      unawaited(ref.read(hapticsProvider).play(on ? Haptic.light : Haptic.success));
      final ok = await ref.read(favouritesProvider.notifier).toggle(key.$1, key.$2, was: on);
      if (!ok) {
        ref.read(toastProvider.notifier).show("Couldn't update your favourites. Try again.", tone: ToastTone.error);
      }
    }

    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Favourite' : 'Add to favourites',
      excludeSemantics: true,
      child: Material(
        color: Surface.s3,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: () => unawaited(toggle()),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: AnimatedSwitcher(
              duration: Motion.overlay,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                Symbols.favorite_rounded,
                key: ValueKey(on),
                fill: on ? 1 : 0,
                size: 22,
                color: on ? _pink : TextTone.mid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Your status, under the headline: Add to list (signed out, it leads to
/// Log In), or your status with progress and the steppers.
class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.title, required this.isFavourite});

  final Title title;

  /// As the page loaded; a change made here since is in [favouritesProvider].
  final bool isFavourite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final actions = ref.read(listActionsProvider);

    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    final color = entry == null ? null : statusColor[entry.status]!;
    final statusButton = Material(
      // not on the list: Add to list, filled in ink (the page's one main action)
      color: color?.withValues(alpha: 0.12) ?? TextTone.high,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        // opens the editor (signed out, Log In); a title not on the list is
        // added as Planning by the editor's first change
        onTap: () => unawaited(showListEditor(context, ref, title)),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color?.withValues(alpha: 0.35) ?? Colors.transparent),
          ),
          child: Row(
            children: [
              if (entry != null)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                )
              else
                Icon(Symbols.add_rounded, size: 20, color: Surface.base),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  entry == null ? 'Add to list' : statusLabel(entry.status, isAnime: title.isAnime),
                  style: AppType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: entry == null ? Surface.base : TextTone.high,
                  ),
                ),
              ),
              Icon(Symbols.edit_rounded, size: 20, color: entry == null ? Surface.base : TextTone.high),
            ],
          ),
        ),
      ),
    );

    final button = Row(
      children: [
        Expanded(child: statusButton),
        const SizedBox(width: Space.x2),
        _FavouriteButton(title: title, isFavourite: isFavourite),
      ],
    );

    if (entry == null) return button;
    // nothing to count yet while planned: offer to start instead
    if (entry.status == MediaListStatus.planning) {
      return Column(
        children: [
          button,
          const SizedBox(height: Space.x3),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => act(() => unawaited(actions.changeStatus(title, MediaListStatus.current))),
              style: FilledButton.styleFrom(
                backgroundColor: TextTone.high,
                foregroundColor: Surface.s1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Symbols.play_arrow_rounded, fill: 1, size: 22),
              label: Text(title.isAnime ? 'Start watching' : 'Start reading'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        button,
        const SizedBox(height: Space.x3),
        _ProgressCard(
          title: title,
          entry: entry,
          scoreFormat: ref.watch(sessionProvider.select((s) => s.scoreFormat)),
          onEdit: () => unawaited(showListEditor(context, ref, title)),
          onStep: (dir) => act(() {
            unawaited(dir > 0 ? actions.plusOne(title) : actions.minusOne(title));
          }),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.entry,
    required this.scoreFormat,
    required this.onEdit,
    required this.onStep,
  });

  final Title title;
  final ListEntry entry;
  final ScoreFormat scoreFormat;

  /// Opens the list editor (from your score).
  final VoidCallback onEdit;
  final void Function(int direction) onStep;

  @override
  Widget build(BuildContext context) {
    final total = title.total;
    final canStep = isInProgress(entry.status) || entry.status == MediaListStatus.planning;
    final unit = title.isAnime ? 'episode' : 'chapter';
    final score = entry.score ?? 0;
    final fresh = isInProgress(entry.status) ? newEpisodesFor(title, entry.progress) : null;
    final waiting = isInProgress(entry.status) && fresh == 0 && title.next != null;
    final fraction = entry.status == MediaListStatus.completed
        ? 1.0
        : total != null && total > 0
        ? (entry.progress / total).clamp(0.0, 1.0)
        : null;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${entry.progress}', style: AppType.mono(26)),
              Text(' / ${total ?? '?'}', style: AppType.body.copyWith(fontSize: 15, color: TextTone.low)),
              const SizedBox(width: Space.x2),
              // what's out that you haven't seen, in Home's words
              Expanded(
                child: Text(
                  fresh != null && fresh > 0
                      ? '$fresh ${title.next == null ? 'left' : 'new'}'
                      : waiting
                      ? 'Caught up'
                      : (title.isAnime ? 'watched' : 'read'),
                  style: AppType.caption.copyWith(
                    color: fresh != null && fresh > 0
                        ? Accent.green
                        : waiting
                        ? Accent.soraText
                        : TextTone.mid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // your score, which opens the editor to set it
              Semantics(
                button: true,
                label: score > 0 ? 'Your score ${formatScore(score, scoreFormat)}, edit' : 'Not scored, rate it',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.minTarget),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.star_rounded,
                          size: 16,
                          fill: score > 0 ? 1 : 0,
                          color: score > 0 ? Accent.gold : TextTone.low,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          score > 0 ? '${formatScore(score, scoreFormat)} yours' : 'Rate it',
                          style: AppType.caption.copyWith(
                            color: score > 0 ? TextTone.high : TextTone.mid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(Corner.full),
            child: SizedBox(
              height: 6,
              child: fraction == null
                  // ongoing: the bar fades out instead of implying 100%
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor[entry.status]!, statusColor[entry.status]!.withValues(alpha: 0)],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        const ColoredBox(color: Surface.s3, child: SizedBox.expand()),
                        EasedFractionallySizedBox(
                          widthFactor: fraction,
                          child: ColoredBox(color: statusColor[entry.status]!, child: const SizedBox.expand()),
                        ),
                      ],
                    ),
            ),
          ),
          if (canStep) ...[
            const SizedBox(height: Space.x3),
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: Space.minTarget,
                  child: OutlinedButton(
                    onPressed: entry.progress > 0 ? () => onStep(-1) : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: Surface.s3,
                      side: const BorderSide(color: Surface.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: Icon(Symbols.remove_rounded, color: TextTone.high, semanticLabel: 'One less $unit'),
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: SizedBox(
                    height: Space.minTarget,
                    child: FilledButton.icon(
                      onPressed: total == null || entry.progress < total ? () => onStep(1) : null,
                      // quiet: the page's one loud button is the status
                      style: FilledButton.styleFrom(
                        backgroundColor: Quiet.fill,
                        foregroundColor: TextTone.high,
                        side: const BorderSide(color: Quiet.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                        textStyle: AppType.numeric.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Symbols.add_rounded, size: 20),
                      label: Text('1 ${title.unit}'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.content});

  final DetailContent content;

  @override
  Widget build(BuildContext context) {
    final title = content.title;
    final small = AppType.overline.copyWith(color: TextTone.low, fontWeight: FontWeight.w500);
    Widget fact(String value, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.mono(17)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: small),
      ],
    );

    // editorial: one large number in the cover's colour, the rest as small
    // labelled facts, between two rules; genres as words
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.x4),
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 28,
            runSpacing: Space.x4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Semantics(
                label: 'Average score ${title.score > 0 ? title.score.toStringAsFixed(1) : 'none'}',
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.score > 0 ? title.score.toStringAsFixed(1) : '—',
                      style: AppType.serif(
                        56,
                        height: 0.85,
                        weight: FontWeight.w200,
                        tracking: -0.06,
                        color: title.colors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('AVERAGE SCORE', style: small),
                  ],
                ),
              ),
              if (content.rank != null) fact(content.rank!.value, content.rank!.label),
              fact(content.members, 'Members'),
              if (content.trailer != null)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(content.trailer!, mode: LaunchMode.externalApplication),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, Space.minTarget),
                    foregroundColor: TextTone.high,
                    side: const BorderSide(color: Surface.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.sm)),
                    textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Symbols.play_arrow_rounded, fill: 1, size: 20),
                  label: const Text('Trailer'),
                ),
            ],
          ),
          if (title.genres.isNotEmpty) ...[
            const SizedBox(height: Space.x3),
            // genres as words, not pills; each opens Browse
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, g) in title.genres.indexed) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text('/', style: TextStyle(color: TextTone.low)),
                    ),
                  TextButton(
                    onPressed: () => context.go('/browse?genre=${Uri.encodeComponent(g)}'),
                    style: TextButton.styleFrom(
                      foregroundColor: TextTone.mid,
                      minimumSize: const Size(Space.minTarget, Space.minTarget),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(g, style: AppType.body.copyWith(color: TextTone.mid)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.text, required this.open, required this.onToggle});

  final String text;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: Motion.panel,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: Text(
            text,
            maxLines: open ? null : 3,
            overflow: open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppType.bodyL.copyWith(fontSize: 15, color: const Color(0xFFC9BFAE)),
          ),
        ),
        TextButton.icon(
          onPressed: onToggle,
          iconAlignment: IconAlignment.end,
          style: TextButton.styleFrom(
            foregroundColor: TextTone.mid,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, Space.minTarget),
            textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
          ),
          icon: Icon(open ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, size: 20),
          label: Text(open ? 'Show less' : 'Read more'),
        ),
      ],
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({required this.selected, required this.accent, required this.onSelect});

  final _Tab selected;
  final Color accent;
  final ValueChanged<_Tab> onSelect;

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE613110F),
            border: Border(bottom: BorderSide(color: Surface.line)),
          ),
          child: _TabStrip(selected: selected, accent: accent, onSelect: onSelect),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader old) => old.selected != selected || old.accent != accent;
}

/// The title page's tabs, which scroll sideways on a phone: the open one is
/// brought fully into view whenever it changes, by tap or by an "All →"
/// link, so it's never left half off the edge.
class _TabStrip extends StatefulWidget {
  const _TabStrip({required this.selected, required this.accent, required this.onSelect});

  final _Tab selected;
  final Color accent;
  final ValueChanged<_Tab> onSelect;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  final _scroll = ScrollController();
  final _keys = {for (final t in _Tab.values) t: GlobalKey()};

  @override
  void didUpdateWidget(_TabStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls just enough to show the open tab, keeping the strip's own edge
  /// padding. Only this strip moves, never the page around it.
  void _reveal() {
    final tab = _keys[widget.selected]!.currentContext?.findRenderObject() as RenderBox?;
    final strip = context.findRenderObject() as RenderBox?;
    if (!mounted || tab == null || strip == null || !_scroll.hasClients) return;
    final left = tab.localToGlobal(Offset.zero, ancestor: strip).dx;
    final right = left + tab.size.width;
    final by = left < Space.x3
        ? left - Space.x3
        : right > strip.size.width - Space.x3
        ? right - strip.size.width + Space.x3
        : 0.0;
    if (by == 0) return;
    final to = (_scroll.offset + by).clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(to);
    } else {
      unawaited(_scroll.animateTo(to, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.x3),
      child: Row(
        children: [
          for (final t in _Tab.values)
            KeyedSubtree(
              key: _keys[t],
              child: Semantics(
                selected: t == selected,
                button: true,
                child: InkWell(
                  onTap: () => widget.onSelect(t),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: t == selected ? widget.accent : Colors.transparent, width: 2),
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: AppType.body.copyWith(
                        fontWeight: t == selected ? FontWeight.w600 : FontWeight.w400,
                        color: t == selected ? TextTone.high : TextTone.mid,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Skeleton(height: 300, radius: 0),
        Padding(
          padding: EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 112, height: 168),
              SizedBox(height: Space.x4),
              Skeleton(width: 160, height: 16, radius: 4),
              SizedBox(height: Space.x3),
              Skeleton(width: 260, height: 32, radius: 6),
              SizedBox(height: Space.x3),
              Skeleton(width: 200, height: 16, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.search_off_rounded, size: 40, color: TextTone.low),
              const SizedBox(height: Space.x3),
              Text("This title doesn't exist", style: AppType.heading.copyWith(fontSize: 24)),
              const SizedBox(height: Space.x2),
              Text('It may have been removed from AniList.', style: AppType.body.copyWith(color: TextTone.mid)),
              const SizedBox(height: Space.x4),
              TextButton(onPressed: () => context.go('/browse'), child: const Text('Browse titles →')),
              TextButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      ),
    );
  }
}
