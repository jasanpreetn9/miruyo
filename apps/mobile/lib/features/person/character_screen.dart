// A character (/character/:id), ported from apps/web/src/routes/character/[id]:
// who they are, then every title they're in with who voices them, one
// language at a time (Japanese first).

import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/section_error.dart';
import 'person_data.dart';
import 'person_layout.dart';
import 'staff_screen.dart' show PersonNotFoundView, PersonSkeleton;

class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  /// Pages of titles after the first.
  final _more = <Json>[];
  bool _loading = false;
  bool _failed = false;

  /// The voice language picked, if any; otherwise the first (Japanese).
  String? _picked;

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final next = await ref.read(anilistClientProvider).fetchCharacterAppearances(widget.id, _more.length + 2);
      if (!mounted) return;
      unawaited(loadListState(ref.read, mediaIdsOf(next)));
      setState(() {
        _more.add(next);
        _failed = false;
      });
    } on Exception {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(characterProvider(widget.id));
    final session = ref.watch(sessionProvider);
    final raw = loaded.value;
    if (raw == null) {
      return Scaffold(
        body: switch (loaded) {
          AsyncError(error: PersonNotFound()) => const PersonNotFoundView(),
          AsyncError(:final error) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: SectionError(
                title: "Couldn't load this character",
                error: error,
                onRetry: () => ref.invalidate(characterProvider(widget.id)),
              ),
            ),
          ),
          _ => const PersonSkeleton(),
        },
      );
    }

    final content = createCharacterContent(
      {...raw, 'media': withPages(raw['media'] as Json?, _more)},
      titles: session.titles,
      adult: session.signedIn && session.showAdultContent,
    );
    final language = _picked != null && content.languages.contains(_picked) ? _picked : content.languages.firstOrNull;

    return Scaffold(
      body: PersonPage(
        header: content.header,
        kind: FavouriteKind.character,
        id: content.id,
        sections: [
          if (content.appearances.isNotEmpty) ...[
            PersonSectionHeading(
              text: 'Appears in',
              trailing: content.languages.length > 1
                  ? _LanguagePicker(
                      languages: content.languages,
                      language: language!,
                      onPick: (l) => setState(() => _picked = l),
                    )
                  : null,
            ),
            RoleGrid(
              cards: [
                for (final a in content.appearances)
                  RoleCard(
                    key: ValueKey(a.key),
                    media: a.media,
                    caption: a.role,
                    people: [
                      for (final v in a.voices)
                        if (v.language == language)
                          (href: '/staff/${v.id}', name: v.name, image: v.image, caption: v.note),
                    ],
                  ),
              ],
            ),
            if (content.hasMore || _failed)
              LoadMore(loading: _loading, failed: _failed, onTap: _loadMore, what: 'titles'),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: Space.x8),
              child: Text('No titles listed on AniList yet.', style: AppType.body.copyWith(color: TextTone.mid)),
            ),
        ],
      ),
    );
  }
}

/// Which language's voice actors the cards show.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.languages, required this.language, required this.onPick});

  final List<String> languages;
  final String language;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Voice actors in',
      initialValue: language,
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final l in languages) CheckedPopupMenuItem(value: l, checked: l == language, child: Text(l)),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Space.minTarget),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.record_voice_over_rounded, size: 16, color: TextTone.low),
            const SizedBox(width: 6),
            Text(language, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
            const Icon(Symbols.expand_more_rounded, size: 18, color: TextTone.mid),
          ],
        ),
      ),
    );
  }
}
