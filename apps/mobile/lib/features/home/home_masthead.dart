import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalog/humanize.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/season.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../widgets/motion.dart';
import 'home_list.dart';

/// Home's masthead (design/mockups/home-editorial): a dateline, a greeting,
/// where you stand in one sentence, and three running totals. Its lines
/// settle in one after another.
class HomeMasthead extends ConsumerWidget {
  const HomeMasthead({super.key, required this.plan, required this.mode});

  final ContinuePlan plan;
  final Mode mode;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _jpDays = ['月', '火', '水', '木', '金', '土', '日'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final now = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final greeting = switch (now.hour) {
      < 5 => ('Up', 'late'),
      < 12 => ('Good', 'morning'),
      < 18 => ('Good', 'afternoon'),
      _ => ('Good', 'evening'),
    };
    final midnight = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch ~/ 1000;
    final inProgress = [...plan.ready, ...plan.waiting];
    final airingToday = mode.isAnime
        ? inProgress.where((t) {
            final at = t.next?.airingAt;
            return at != null && at > seconds && at < midnight;
          }).length
        : 0;
    final behind = plan.ready.length;
    final unit = mode.isAnime ? 'episode' : 'chapter';
    String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
    final season = currentSeason();
    final strong = AppType.bodyL.copyWith(color: TextTone.high, fontWeight: FontWeight.w600);

    final sentence = <InlineSpan>[
      if (plan.newEpisodes > 0) ...[
        const TextSpan(text: "You're "),
        TextSpan(text: '${plural(plan.newEpisodes, unit)} behind', style: strong),
        TextSpan(text: ' across ${plural(behind, mode.isAnime ? 'show' : 'series')}.'),
      ] else if (inProgress.isNotEmpty) ...[
        const TextSpan(text: "You're "),
        TextSpan(text: 'caught up', style: strong),
        TextSpan(text: " on everything you're ${mode.isAnime ? 'watching' : 'reading'}."),
      ] else
        const TextSpan(text: 'Nothing in progress right now.'),
      if (airingToday > 0) ...[
        const TextSpan(text: ' '),
        TextSpan(text: '$airingToday', style: strong),
        TextSpan(text: ' of yours ${airingToday == 1 ? 'airs' : 'air'} later today.'),
      ],
    ];

    Widget tally(int n, String label, {bool hot = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$n',
          style: AppType.serif(
            40,
            height: 1,
            weight: FontWeight.w300,
            tracking: -0.04,
            color: hot && n > 0 ? context.mode.accent : TextTone.high,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppType.overline.copyWith(color: TextTone.low, fontWeight: FontWeight.w500),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Appear(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: Space.x3),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Surface.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} ${now.year} · '
                            .toUpperCase(),
                        children: [
                          TextSpan(
                            text: '${_jpDays[now.weekday - 1]}曜日',
                            style: AppType.jp.copyWith(fontSize: 11, letterSpacing: 0),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.overline.copyWith(color: TextTone.low, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Text(
                    '${humanizeSeason(season.season)} ${season.year}'.toUpperCase(),
                    style: AppType.overline.copyWith(color: TextTone.low, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Surface.line, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Appear(
                  delay: const Duration(milliseconds: 70),
                  child: Text.rich(
                    TextSpan(
                      text: '${greeting.$1} ',
                      children: [
                        TextSpan(
                          text: greeting.$2,
                          style: AppType.displayL.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: AppType.displayL,
                  ),
                ),
                const SizedBox(height: Space.x3),
                Appear(
                  delay: const Duration(milliseconds: 140),
                  child: Text.rich(
                    TextSpan(children: sentence),
                    style: AppType.bodyL.copyWith(color: TextTone.mid, height: 1.5),
                  ),
                ),
                const SizedBox(height: Space.x5),
                Appear(
                  delay: const Duration(milliseconds: 200),
                  // the totals wrap to a second line before they'd overflow (large text)
                  child: Wrap(
                    spacing: Space.x6,
                    runSpacing: Space.x4,
                    children: [
                      tally(plan.newEpisodes, mode.isAnime ? 'TO WATCH' : 'TO READ', hot: true),
                      tally(inProgress.length, mode.isAnime ? 'WATCHING' : 'READING'),
                      if (mode.isAnime) tally(airingToday, 'AIRING TODAY'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
