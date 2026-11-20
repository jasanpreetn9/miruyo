// My List's Edit mode: select several entries,
// then carry them to a status, Move to…, or hold to remove. Row swipes and
// pull to refresh pause while it's on, so selecting can never change
// progress.

import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/list_actions.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/hold_to_confirm.dart';

class ListEditState {
  const ListEditState({this.editing = false, this.tab = MediaListStatus.current, this.selected = const {}});

  final bool editing;

  /// The tab being edited: its status is shown in the panel but can't be a target.
  final MediaListStatus tab;

  /// Selected titles by media id, in the order they were selected.
  final Map<int, Title> selected;

  bool isSelected(int id) => selected.containsKey(id);
}

class ListEditController extends Notifier<ListEditState> {
  @override
  ListEditState build() => const ListEditState();

  void _haptic(Haptic h) => unawaited(ref.read(hapticsProvider).play(h));

  void start(MediaListStatus tab) => state = ListEditState(editing: true, tab: tab);

  void stop() => state = const ListEditState();

  /// A new tab while editing clears the selection, since it isn't on screen.
  void showTab(MediaListStatus tab) {
    if (state.editing) state = ListEditState(editing: true, tab: tab);
  }

  void set(Title title, bool selected) {
    if (!state.editing || state.isSelected(title.id) == selected) return;
    final next = {...state.selected};
    selected ? next[title.id] = title : next.remove(title.id);
    state = ListEditState(editing: true, tab: state.tab, selected: next);
    _haptic(Haptic.selection);
  }

  void toggle(Title title) => set(title, !state.isSelected(title.id));

  /// Moves the selection to [status] and clears it. Edit stays on.
  void moveTo(MediaListStatus status) {
    final titles = state.selected.values.toList();
    if (titles.isEmpty || status == state.tab) return;
    state = ListEditState(editing: true, tab: state.tab);
    unawaited(ref.read(listActionsProvider).moveMany(titles, status));
  }

  void removeSelected() {
    final titles = state.selected.values.toList();
    if (titles.isEmpty) return;
    state = ListEditState(editing: true, tab: state.tab);
    unawaited(ref.read(listActionsProvider).removeMany(titles));
  }
}

final listEditProvider = NotifierProvider<ListEditController, ListEditState>(ListEditController.new);

/// Takes the tab bar's place while Edit is on: Move to… and Hold to remove.
class ListEditBar extends ConsumerWidget {
  const ListEditBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(listEditProvider);
    final some = edit.selected.isNotEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(Space.gutter, 10, Space.gutter, bottom > 0 ? bottom : 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F16),
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: some ? () => unawaited(showMoveTo(context, ref)) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: TextTone.high,
                foregroundColor: Surface.base,
                disabledBackgroundColor: Surface.s3,
                disabledForegroundColor: TextTone.low,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Symbols.drive_file_move_rounded, size: 20),
              label: const Text('Move to…'),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: IgnorePointer(
              ignoring: !some,
              child: AnimatedOpacity(
                duration: Motion.overlay,
                opacity: some ? 1 : 0.4,
                child: HoldToConfirm(
                  label: 'Remove',
                  icon: Symbols.delete_rounded,
                  confirmTitle: edit.selected.length == 1
                      ? 'Remove ${edit.selected.values.first.title} from your list?'
                      : 'Remove ${edit.selected.length} titles from your list?',
                  onConfirmed: ref.read(listEditProvider.notifier).removeSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Move to…: the status panel as a sheet, for taps instead of carrying.
Future<void> showMoveTo(BuildContext context, WidgetRef ref) async {
  final edit = ref.read(listEditProvider);
  final isAnime = ref.read(modeProvider).isAnime;
  final status = await showModalBottomSheet<MediaListStatus>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Surface.s2,
    barrierColor: const Color(0x8013110F),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
        child: StatusPanel(
          title: 'Move ${edit.selected.length} to…',
          here: edit.tab,
          isAnime: isAnime,
          onTap: (s) => Navigator.of(context).pop(s),
        ),
      ),
    ),
  );
  if (status != null) ref.read(listEditProvider.notifier).moveTo(status);
}

/// The six statuses as 76px targets, two rows of three: the drop zone while
/// carrying, and Move to…'s sheet. The current tab's is shown but disabled.
class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.title,
    required this.here,
    required this.isAnime,
    this.hot,
    this.onTap,
    this.targetKeys,
  });

  final String title;
  final MediaListStatus here;
  final bool isAnime;

  /// The target under a carried stack.
  final MediaListStatus? hot;
  final ValueChanged<MediaListStatus>? onTap;

  /// For hit-testing a carried stack against the targets.
  final Map<MediaListStatus, GlobalKey>? targetKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppType.title.copyWith(fontSize: 16)),
        const SizedBox(height: Space.x3),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: Space.x2,
          crossAxisSpacing: Space.x2,
          childAspectRatio: 1.45,
          children: [for (final s in listStatuses) _target(s)],
        ),
      ],
    );
  }

  Widget _target(MediaListStatus s) {
    final color = statusColor[s]!;
    final isHere = s == here;
    final isHot = s == hot;
    final label = statusLabel(s, isAnime: isAnime);
    return Semantics(
      button: true,
      enabled: !isHere,
      label: isHere ? '$label, current tab' : label,
      excludeSemantics: true,
      child: AnimatedScale(
        key: targetKeys?[s],
        duration: Motion.press,
        scale: isHot ? 1.04 : 1,
        child: Material(
          color: isHot ? color.withValues(alpha: 0.2) : Surface.s1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Corner.md),
            side: BorderSide(color: isHot ? color : Surface.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Corner.md),
            onTap: isHere || onTap == null ? null : () => onTap!(s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: isHere ? TextTone.low : color, shape: BoxShape.circle),
                ),
                const SizedBox(height: 6),
                Text(
                  isHere ? '$label · here' : label,
                  style: AppType.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isHere ? const Color(0xFF9A9080) : TextTone.high,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
