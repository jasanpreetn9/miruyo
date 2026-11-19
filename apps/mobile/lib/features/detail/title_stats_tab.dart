// The title page's Stats tab: where it ranks, how many people have it on
// each list, and how they score it, from AniList's counts across every user.
// It loads when the tab opens; the bars take the cover's colour, as the rest
// of the page does. Ported from apps/web/src/lib/components/title/TitleStats.svelte.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog/status.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../profile/charts.dart';
import '../profile/profile_data.dart' show Bar, Tone;
import 'title_stats.dart';

class TitleStatsTab extends ConsumerWidget {
  const TitleStatsTab({super.key, required this.id, required this.isAnime, required this.accent});

  final int id;
  final bool isAnime;

  /// The cover's colour (Title.colors.accent).
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(titleStatsProvider(id));
    return switch (stats) {
      AsyncData(:final value) => _Stats(
        view: buildTitleStats(value, isAnime: isAnime),
        accent: accent,
      ),
      AsyncError(:final error) => SectionError(
        title: "Couldn't load this ${isAnime ? 'anime' : 'manga'}'s stats",
        error: error,
        onRetry: () => ref.invalidate(titleStatsProvider(id)),
      ),
      _ => Semantics(
        label: 'Loading stats',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Skeleton(height: 96, radius: Corner.md),
            SizedBox(height: Space.x4),
            Skeleton(height: 120, radius: Corner.md),
            SizedBox(height: Space.x4),
            Skeleton(height: 200, radius: Corner.md),
          ],
        ),
      ),
    };
  }
}

/// "1,234": exact counts read out while scrubbing.
String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.aside});

  final String text;
  final String? aside;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(text, style: AppType.section.copyWith(fontSize: 22))),
        if (aside != null) Text(aside!, style: AppType.caption.copyWith(color: TextTone.mid)),
      ],
    );
  }
}

BoxDecoration get _card => BoxDecoration(
  color: Surface.s1,
  borderRadius: BorderRadius.circular(Corner.md),
  border: Border.all(color: Surface.line),
);

/// Two to a row, as the web lays them out on a phone.
Widget _twoUp(List<Widget> children, {double gap = Space.x2, double runGap = Space.x2}) => LayoutBuilder(
  builder: (context, box) {
    final width = (box.maxWidth - gap) / 2;
    return Wrap(
      spacing: gap,
      runSpacing: runGap,
      children: [for (final c in children) SizedBox(width: width, child: c)],
    );
  },
);

class _Stats extends StatelessWidget {
  const _Stats({required this.view, required this.accent});

  final TitleStats view;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scored = view.scores.any((b) => b.count > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.rankings.isNotEmpty) ...[
          const _Heading('Rankings'),
          const SizedBox(height: Space.x4),
          _twoUp([for (final r in view.rankings) _Ranking(row: r, accent: accent)]),
          const SizedBox(height: Space.x8),
        ],
        if (view.statuses.isNotEmpty) ...[
          _Heading('On lists', aside: '${view.members} people'),
          const SizedBox(height: Space.x4),
          Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: _card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          for (final (i, s) in view.statuses.indexed) ...[
                            if (i > 0) const SizedBox(width: 2),
                            Expanded(
                              flex: s.count,
                              child: ColoredBox(color: statusColor[s.status]!, child: const SizedBox.expand()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.x4),
                _twoUp(runGap: Space.x3, gap: Space.x4, [for (final s in view.statuses) _StatusCount(row: s)]),
              ],
            ),
          ),
          const SizedBox(height: Space.x8),
        ],
        _Heading('Score distribution', aside: view.average == null ? null : 'Average ${view.average}'),
        const SizedBox(height: Space.x4),
        if (scored)
          ChartCard(
            title: 'People per score',
            summary: '${view.scored} scores',
            builder: (context, readout) => ScrubBars(
              height: 120,
              color: accent,
              bars: [
                for (final b in view.scores)
                  Bar(label: '${b.score}', name: 'Score ${b.score}', count: b.count, tone: Tone.accent),
              ],
              describe: (b) => '${_thousands(b.count)} scored it ${b.label}',
              onReadout: readout,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: _card,
            child: Text('No one has scored it on AniList yet.', style: AppType.body.copyWith(color: TextTone.mid)),
          ),
      ],
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking({required this.row, required this.accent});

  final RankingRow row;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final href = row.href;
    final body = Container(
      constraints: const BoxConstraints(minHeight: Space.minTarget),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${row.rank}',
            style: AppType.numeric.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: accent, height: 1),
          ),
          const SizedBox(height: 6),
          Text(row.label, style: AppType.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '${row.when} · ${row.format}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(color: TextTone.mid),
          ),
        ],
      ),
    );
    return Semantics(
      label: '#${row.rank} ${row.label}, ${row.when}, ${row.format}',
      button: href != null,
      excludeSemantics: true,
      child: Material(
        color: Surface.s1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.sm),
          side: const BorderSide(color: Surface.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: href == null ? body : InkWell(onTap: () => context.go(href), child: body),
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({required this.row});

  final StatusRow row;

  @override
  Widget build(BuildContext context) {
    final percent = row.percent == row.percent.roundToDouble() ? '${row.percent.round()}' : '${row.percent}';
    return Semantics(
      label: '${row.label}: ${row.shown}, $percent%',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor[row.status], shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                row.label,
                style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: row.shown),
                TextSpan(
                  text: '  $percent%',
                  style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.low),
                ),
              ],
            ),
            style: AppType.numeric.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: TextTone.high),
          ),
        ],
      ),
    );
  }
}
