import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/score.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart';
import '../../widgets/poster_card.dart' show HiddenCover, StatusBar;
import '../editor/quick_actions.dart';
import 'list_data.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// My List's grid card (05, "a list you admire"). The cover is only the
/// art; everything else sits under it: the status bar filled to your
/// progress, the title, the status in words with your progress, then the
/// rows' note, or when you finished it, with your score. Tap for details;
/// swipe like a My List row: a short left +1, right −1, a long left or a
/// hold for quick actions.
class ListGridCard extends ConsumerStatefulWidget {
  const ListGridCard({super.key, required this.row, this.demo});

  final ListRow row;

  /// The coach mark's demonstration of the swipes, on the first card.
  final ValueListenable<double>? demo;

  @override
  ConsumerState<ListGridCard> createState() => _ListGridCardState();
}

class _ListGridCardState extends ConsumerState<ListGridCard> {
  bool _revealed = false;

  /// The last line: when you finished it on the shelf tabs, else the rows'
  /// note.
  (String, Color) get _note {
    final row = widget.row;
    if (row.status == MediaListStatus.completed) {
      final d = row.completedAt;
      if (d.year != null) {
        final month = d.month == null ? '' : '${_months[d.month! - 1]} ';
        return ('Finished $month${d.year}', TextTone.low);
      }
    }
    return (row.note, row.noteColor);
  }

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context) => Appear(child: _build(context));

  Widget _build(BuildContext context) {
    final row = widget.row;
    final title = row.title;
    final session = ref.watch(sessionProvider);
    final hidden = title.adult && !session.showAdultContent && !_revealed;
    final total = title.total;
    final moving = isInProgress(row.status);
    final atTotal = total != null && total > 0 && row.progress >= total;
    final (note, noteColor) = _note;
    final label = statusLabel(row.status, isAnime: title.isAnime);
    // the tab already names the status: only where you are, while it moves
    final progressLine = moving ? '${title.unit} ${row.progress} / ${total ?? '?'}' : null;
    final status = moving ? '$label · ${row.progress}/${total ?? '?'}' : label;
    final score = row.score > 0 ? formatScore(row.score, session.scoreFormat) : null;

    final actions = ref.read(listActionsProvider);
    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    // My List's swipes, as on its rows: a short left +1, right −1, a long
    // left or a hold for quick actions. RowSwipe also offers them to screen
    // readers as actions.
    return RowSwipe(
      swapped: true,
      demo: widget.demo,
      onPositive: row.progress > 0 ? () => act(() => unawaited(actions.minusOne(title))) : null,
      positiveLabel: '−1',
      positiveIcon: Symbols.remove_rounded,
      onNegative: moving && !atTotal ? () => act(() => unawaited(actions.plusOne(title))) : null,
      negativeLabel: '+1',
      negativeIcon: Symbols.add_rounded,
      onMore: () => unawaited(showQuickActions(context, ref, title)),
      borderRadius: Corner.sm,
      child: Semantics(
        button: true,
        label: [title.title, status, if (score != null) 'your score $score', note].join(', '),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => context.push('/title/${title.id}'),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(title: title),
                    if (hidden) HiddenCover(onReveal: () => setState(() => _revealed = true)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              StatusBar(status: row.status, progress: row.progress, total: total),
              const SizedBox(height: 8),
              // two lines kept for the title, so the lines under it align
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(13) * 1.25 * 2,
                child: Text(
                  title.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
                ),
              ),
              const SizedBox(height: 2),
              if (progressLine != null)
                Text(
                  progressLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(
                    fontSize: 11,
                    color: TextTone.mid,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
              Text.rich(
                TextSpan(
                  children: [
                    if (score != null) ...[
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Symbols.star_rounded, size: 12, fill: 1, color: Accent.gold),
                      ),
                      TextSpan(
                        text: ' $score  ',
                        style: const TextStyle(color: TextTone.high),
                      ),
                    ],
                    TextSpan(text: note),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption.copyWith(fontSize: 11, color: noteColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
