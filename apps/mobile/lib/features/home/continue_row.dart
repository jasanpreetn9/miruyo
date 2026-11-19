import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/progress.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart' show Tick;
import '../../widgets/poster_card.dart' show StatusBar;
import '../../widgets/poster_row.dart' show SectionHeading;
import '../editor/quick_actions.dart';
import 'home_list.dart';

/// Nothing is ready (1i): you're caught up, here's what airs next, and the
/// schedule for the rest of the week.
class _CaughtUpCard extends ConsumerWidget {
  const _CaughtUpCard({required this.title});

  final Title title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final next = title.next!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/title/${title.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Space.x3),
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("You're caught up.", style: AppType.serif(20, italic: true)),
              const SizedBox(height: Space.x3),
              Text('NEXT TO AIR ON YOUR LIST', style: AppType.overline.copyWith(color: TextTone.low)),
              const SizedBox(height: Space.x2),
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 66,
                    child: CoverImage(title: title, thumb: true, radius: Corner.sm, showMissing: false),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EP ${next.ep} in ${countdown(next.airingAt - now)}',
                          style: AppType.numeric.copyWith(fontSize: 12, color: Accent.soraText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/seasonal?view=airing'),
                    icon: const Icon(Symbols.calendar_month_rounded, size: 18),
                    label: const Text('Schedule'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TextTone.high,
                      minimumSize: const Size(0, Space.minTarget),
                      side: const BorderSide(color: Surface.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.sm)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Continue's lead (design/mockups/home-editorial): the title you're furthest
/// behind on, its cover large with an offset shadow in its colour, and a +1
/// that says where it lands ("4 / 26 · +1 → 5"); the numbers tick on a +1.
class _LeadCard extends ConsumerWidget {
  const _LeadCard({super.key, required this.title});

  final Title title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final progress = entry?.progress ?? title.me?.progress ?? 0;
    final total = title.total;
    final behind = newEpisodesFor(title, progress) ?? 0;
    final atTotal = total != null && total > 0 && progress >= total;
    final actions = ref.read(listActionsProvider);
    final unit = title.isAnime ? 'episode' : 'chapter';
    final status = entry?.status ?? title.me?.status ?? MediaListStatus.current;
    final onInk = AppType.sans(13, 1, FontWeight.w700).copyWith(color: Surface.base);
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final left = (total ?? 0) - progress;
    final minutes = title.duration;
    final next = title.next;
    // the row's other end, as rows have it: when the next one airs, or the time left
    final aside = next != null
        ? '${title.unit} ${next.ep} in ${countdown(next.airingAt - now)}'
        : minutes != null && minutes > 0 && left > 0
        ? '${hoursMinutes(left * minutes)} left'
        : null;

    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    // the row grammar, as Continue's rows have it: right +1, short left −1,
    // long left or a hold for quick actions
    return RowSwipe(
      borderRadius: 0,
      onPositive: atTotal ? null : () => act(() => unawaited(actions.plusOne(title))),
      onNegative: progress > 0 ? () => act(() => unawaited(actions.minusOne(title))) : null,
      onMore: () => unawaited(showQuickActions(context, ref, title)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/title/${title.id}'),
        child: Container(
          padding: const EdgeInsets.only(bottom: Space.x5),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Surface.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(boxShadow: offsetShadow(title.colors.accent)),
                  child: SizedBox(
                    width: 100,
                    height: 150,
                    child: CoverImage(title: title, radius: Corner.sm, showMissing: false),
                  ),
                ),
              ),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      behind > 1 ? 'FURTHEST BEHIND' : 'PICK UP WHERE YOU LEFT OFF',
                      style: AppType.overline.copyWith(color: title.colors.accent),
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      title.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(24, height: 1.0, weight: FontWeight.w600, tracking: -0.03),
                    ),
                    const SizedBox(height: Space.x2),
                    Text(
                      behind > 0
                          ? '$behind ${title.next == null ? 'left' : 'new'} · ${title.unit} $progress / ${total ?? '?'}'
                          : '${title.unit} $progress / ${total ?? '?'}',
                      style: AppType.caption.copyWith(
                        color: behind > 0 ? Accent.green : TextTone.mid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (aside != null) ...[
                      const SizedBox(height: 2),
                      Text(aside, style: AppType.numeric.copyWith(fontSize: 11, color: TextTone.low)),
                    ],
                    const SizedBox(height: Space.x3),
                    if (atTotal)
                      _RowButton(
                        icon: Symbols.task_alt_rounded,
                        label: 'Mark ${title.title} as completed',
                        fill: Accent.green,
                        ink: Accent.greenInk,
                        onTap: () => act(() => unawaited(actions.changeStatus(title, MediaListStatus.completed))),
                      )
                    else
                      // a tally counter: where you are, and the number +1 lands on
                      FittedBox(
                        // it shrinks a little rather than overflow at the largest text
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          button: true,
                          label: 'Add one $unit to ${title.title}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => act(() => unawaited(actions.plusOne(title))),
                            child: Container(
                              height: Space.minTarget,
                              decoration: BoxDecoration(border: Border.all(color: TextTone.high)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Tick(value: progress, style: AppType.mono(18)),
                                        Text(' / ${total ?? '?'}', style: AppType.mono(11, color: TextTone.low)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    color: TextTone.high,
                                    padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                                    alignment: Alignment.center,
                                    child: Row(
                                      children: [
                                        Text('+1 → ', style: onInk),
                                        Tick(value: progress + 1, style: onInk),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (progress > 0) ...[
                      const SizedBox(height: Space.x3),
                      StatusBar(status: status, progress: progress, total: total),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "2d 4h", "3h 05m", "12m", "now".
String countdown(int seconds) {
  if (seconds <= 0) return 'now';
  final d = seconds ~/ 86400, h = (seconds % 86400) ~/ 3600, m = (seconds % 3600) ~/ 60;
  return d > 0 ? '${d}d ${h}h' : (h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m');
}

/// Continue (01): everything you're tracking, first on Home. A heading and
/// summary, then one list: ready titles first (their +1 green), then those
/// waiting for their next episode (with a countdown), then Up next; Paused
/// fold into one line at the end. With nothing ready it opens on "You're
/// caught up".
class ContinueSection extends ConsumerStatefulWidget {
  const ContinueSection({super.key, required this.plan});

  final ContinuePlan plan;

  /// Rows shown before "Show all".
  static const shown = 5;

  @override
  ConsumerState<ContinueSection> createState() => _ContinueSectionState();
}

class _ContinueSectionState extends ConsumerState<ContinueSection> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final mode = ref.watch(modeProvider);
    final summary = continueSummary(plan, isAnime: mode.isAnime);
    // caught up: the next to air leads, as a card; the rest follow as rows
    final lead = plan.caughtUp ? plan.waiting.first : null;
    // otherwise the title you're furthest behind on leads, large (ready is
    // sorted most new first); the rest follow as ruled rows
    final featured = lead == null && plan.ready.isNotEmpty ? plan.ready.first : null;
    final rows = [
      for (final t in [...plan.ready, ...plan.waiting])
        if (t.id != lead?.id && t.id != featured?.id) t,
    ];
    final visible = _all ? rows : rows.take(ContinueSection.shown).toList();

    Widget group(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x1),
      child: Text(label, style: AppType.overline.copyWith(color: TextTone.low)),
    );

    final children = <Widget>[];
    for (final (i, t) in visible.indexed) {
      final prev = i == 0 ? null : visible[i - 1];
      // a label where the waiting titles start (the caught-up card heads them otherwise)
      if (lead == null && plan.waiting.contains(t) && (prev == null || !plan.waiting.contains(prev))) {
        children.add(group(mode.isAnime ? 'WAITING FOR THE NEXT EPISODE' : 'WAITING FOR THE NEXT CHAPTER'));
      }
      children.add(_ContinueRow(key: ValueKey(t.id), title: t, waiting: plan.waiting.contains(t)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // what these rows hold, over them
        SectionHeading(
          heading: continueHeading(mode),
          jp: mode.isAnime ? '視聴中' : '読書中',
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.x2, 0),
          trailing: TextButton(
            onPressed: () => context.go('/list'),
            style: TextButton.styleFrom(minimumSize: const Size(0, Space.minTarget)),
            child: Text(
              'My List →',
              style: AppType.body.copyWith(color: TextTone.mid, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              summary,
              style: AppType.caption.copyWith(
                color: plan.newEpisodes > 0 ? Accent.green : TextTone.mid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (featured != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
            child: _LeadCard(key: ValueKey('lead-${featured.id}'), title: featured),
          ),
        if (lead != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
            child: _CaughtUpCard(title: lead),
          ),
        if (lead != null && visible.isNotEmpty) group('ALSO ON ITS WAY'),
        if (lead == null) const SizedBox(height: Space.x1),
        ...children,
        if (rows.length > ContinueSection.shown)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x2),
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                style: TextButton.styleFrom(minimumSize: const Size(0, Space.minTarget)),
                child: Text(
                  _all ? 'Show fewer' : 'Show all ${rows.length}',
                  style: AppType.body.copyWith(color: TextTone.mid, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (plan.upNext.isNotEmpty) ...[
          group('UP NEXT'),
          for (final t in plan.upNext) _ContinueRow(key: ValueKey(t.id), title: t, waiting: false),
        ],
        if (plan.paused.isNotEmpty) _PausedLine(titles: plan.paused),
      ],
    );
  }
}

/// "5 paused · The Apothecary Diaries, ONE PIECE…": Paused titles as one
/// line under the list, opening My List.
class _PausedLine extends StatelessWidget {
  const _PausedLine({required this.titles});

  final List<Title> titles;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${titles.length} paused, in My List',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go('/list'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.x3),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Accent.gold.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: const Icon(Symbols.pause_rounded, size: 18, fill: 1, color: Accent.gold),
              ),
              const SizedBox(width: Space.x3),
              Text('${titles.length} paused', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  titles.map((t) => t.title).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: TextTone.low),
                ),
              ),
              const Icon(Symbols.chevron_right_rounded, size: 20, color: TextTone.low),
            ],
          ),
        ),
      ),
    );
  }
}

/// One title in Continue: cover, title (with when it airs, the time left,
/// or on Up next its score at the other end), what's new, the progress bar,
/// and one thing on the right: +1 (green when there's something new), Start
/// on Up next, Complete at the last episode, or the countdown while you
/// wait. The row grammar: right +1, short left −1, long left or a hold for
/// quick actions.
class _ContinueRow extends ConsumerWidget {
  const _ContinueRow({super.key, required this.title, required this.waiting});

  final Title title;
  final bool waiting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final status = entry?.status ?? title.me?.status ?? MediaListStatus.current;
    final progress = entry?.progress ?? title.me?.progress ?? 0;
    final total = title.total;
    final atTotal = total != null && total > 0 && progress >= total;
    final paused = status == MediaListStatus.paused;
    final starts = status == MediaListStatus.planning;
    // Up next not out yet: its premiere countdown on the right, nothing to start
    final premieres = starts && title.status == 'Not yet released' && title.next != null;
    final counting = waiting || premieres;
    final fresh = !starts && (newEpisodesFor(title, progress) ?? 0) > 0;
    final actions = ref.read(listActionsProvider);
    final (sub, subColor) = _sub(status, progress);
    final aside = counting ? null : _aside(status, progress, now);

    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    final Widget trailing;
    if (counting) {
      trailing = Text(
        countdown(title.next!.airingAt - now),
        style: AppType.numeric.copyWith(fontSize: 12, color: Accent.soraText, fontWeight: FontWeight.w600),
      );
    } else if (paused) {
      trailing = const SizedBox.shrink();
    } else if (atTotal) {
      trailing = _RowButton(
        icon: Symbols.task_alt_rounded,
        label: 'Mark ${title.title} as completed',
        fill: Accent.green,
        ink: Accent.greenInk,
        onTap: () => act(() => unawaited(actions.changeStatus(title, MediaListStatus.completed))),
      );
    } else {
      // quiet, except where there's something new to watch; on Up next the
      // +1 starts it (Watching, at episode 1), so it says Start: miruyo plays nothing
      trailing = _RowButton(
        icon: Symbols.add_rounded,
        text: starts ? 'Start' : null,
        label: starts ? 'Start ${title.title}' : 'Add one ${title.isAnime ? 'episode' : 'chapter'} to ${title.title}',
        fill: fresh ? TextTone.high : Quiet.fill,
        border: fresh ? TextTone.high : Quiet.border,
        ink: fresh ? Surface.base : TextTone.mid,
        onTap: () => act(() => unawaited(actions.plusOne(title))),
      );
    }

    return RowSwipe(
      borderRadius: 0,
      onPositive: counting || paused ? null : () => act(() => unawaited(actions.plusOne(title))),
      onNegative: progress > 0 ? () => act(() => unawaited(actions.minusOne(title))) : null,
      onMore: () => unawaited(showQuickActions(context, ref, title)),
      child: InkWell(
        onTap: () => context.push('/title/${title.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
          padding: const EdgeInsets.symmetric(vertical: Space.x2 + 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Surface.line)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 66,
                child: CoverImage(title: title, thumb: true, radius: Corner.sm, showMissing: false),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            title.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: waiting || paused ? TextTone.mid : TextTone.high,
                            ),
                          ),
                        ),
                        if (aside != null) ...[
                          const SizedBox(width: Space.x2),
                          Text(aside.$1, style: AppType.numeric.copyWith(fontSize: 11, color: aside.$2)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: subColor),
                    ),
                    // nothing watched yet (Up next), no bar: an empty track only adds a line
                    if (progress > 0) ...[
                      const SizedBox(height: 6),
                      StatusBar(status: status, progress: progress, total: total),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.x3),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// "3 new · EP 9 / 24", "16 left · EP 8 / 24", or just where you are; on
  /// Up next, "TV · Fall 2026".
  (String, Color) _sub(MediaListStatus status, int progress) {
    if (status == MediaListStatus.planning) {
      final about = [title.knownFormat, if (title.isAnime) title.season].whereType<String>().join(' · ');
      return (about, TextTone.low);
    }
    final where = '${title.unit} $progress / ${title.total ?? '?'}';
    if (status == MediaListStatus.paused) return (where, TextTone.low);
    final fresh = newEpisodesFor(title, progress);
    if (fresh != null && fresh > 0) {
      return (title.next == null ? '$fresh left · $where' : '$fresh new · $where', Accent.green);
    }
    if (waiting) return (where, TextTone.low);
    return (where, TextTone.mid);
  }

  /// The title line's other end: when the next episode airs ("EP 3 in 2d
  /// 7h"), or for something finished the time left to finish it ("6h 24m
  /// left"); on Up next, how long it is ("24 eps", "1h 47m"), what helps
  /// pick one to start. (AniList's average there read like your own score.)
  (String, Color)? _aside(MediaListStatus status, int progress, int now) {
    if (status == MediaListStatus.planning) {
      final length = lengthOf(title);
      return length == null ? null : (length, TextTone.low);
    }
    if (status == MediaListStatus.paused) return null;
    final next = title.next;
    if (next != null) return ('${title.unit} ${next.ep} in ${countdown(next.airingAt - now)}', Accent.soraText);
    final left = (title.total ?? 0) - progress;
    final minutes = title.duration;
    return minutes != null && minutes > 0 && left > 0 ? ('${hoursMinutes(left * minutes)} left', TextTone.low) : null;
  }
}

/// The row's one button: a 34pt circle (a word on a square tag) in a 44px target.
class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.label,
    required this.fill,
    required this.ink,
    required this.onTap,
    this.border,
    this.text,
  });

  final IconData icon;

  /// A word in the icon's place ("Start"), on a wider pill.
  final String? text;
  final String label;
  final Color fill;
  final Color? border;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: Space.minTarget, minHeight: Space.minTarget),
          child: Center(
            child: Container(
              width: text == null ? 34 : null,
              height: text == null ? 34 : 32,
              padding: text == null ? null : const EdgeInsets.symmetric(horizontal: Space.x3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: text == null ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: text == null ? null : BorderRadius.circular(Corner.sm),
                border: border == null ? null : Border.all(color: border!),
              ),
              child: text == null
                  ? Icon(icon, size: 20, color: ink)
                  : Text(
                      text!,
                      style: AppType.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
