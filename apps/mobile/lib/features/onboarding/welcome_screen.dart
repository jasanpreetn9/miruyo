import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/client.dart';
import '../../core/anilist/errors.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/mode_slider.dart';
import '../home/home_data.dart';
import '../profile/settings_screen.dart' show baseLanguage, titleLanguages, withLanguageStyle;
import 'quick_pick.dart';

/// The viewer's anime and manga counts, for "Imported 120 anime and 14 manga".
final viewerCountsProvider = FutureProvider.autoDispose<({int anime, int manga})>(
  (ref) => ref.watch(anilistClientProvider).fetchViewerCounts(),
);

/// First-run setup (09, Gestures · Onboarding 19), right after the first
/// sign-in: the mode to open in, title language and adult content, then,
/// for an empty list, the quick-pick. Only Continue moves forward; Back (or
/// the edge swipe) returns from the quick-pick to setup with the picks
/// kept, and never goes back past sign-in.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  var _step = 0;
  Mode? _mode;
  TitleLanguage? _lang;
  bool? _adult;
  var _picked = <int>{};
  bool _saving = false;
  String? _error;

  void _finish() {
    unawaited(ref.read(prefsProvider).setString(PrefKeys.onboarded, '1'));
    context.go('/');
  }

  Future<void> _continue({required int listed}) async {
    if (_saving) return;
    final user = ref.read(sessionProvider).user;
    final Mode mode = _mode ?? ref.read(modeProvider);
    final lang = _lang ?? baseLanguage(user?.titleLanguage);
    final adult = _adult ?? user?.displayAdultContent ?? false;
    final langChanged = baseLanguage(user?.titleLanguage) != lang;
    final adultChanged = (user?.displayAdultContent ?? false) != adult;
    setState(() {
      _saving = true;
      _error = null;
    });
    ref.read(modeProvider.notifier).set(mode);
    try {
      if (langChanged || adultChanged) {
        await ref
            .read(sessionProvider.notifier)
            .updateSettings(
              ViewerSettings(
                titleLanguage: langChanged ? withLanguageStyle(lang, user?.titleLanguage) : null,
                displayAdultContent: adultChanged ? adult : null,
              ),
            );
      }
      if (!mounted) return;
      // an empty list gets the quick-pick; anything else is ready to go
      if (listed == 0) {
        setState(() => _step = 1);
      } else {
        _finish();
      }
    } on AniListError catch (e) {
      if (mounted) setState(() => _error = "Couldn't save to AniList (${e.message}). Try again, or skip for now.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final counts = ref.watch(viewerCountsProvider).value;
    final Mode mode = _mode ?? ref.watch(modeProvider);
    final colors = ModeColors.of(mode);
    final listed = counts == null ? -1 : (mode.isAnime ? counts.anime : counts.manga);

    // signed out (or never signed in): this page has nothing to set up
    if (session.authState == AuthState.signedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
    }

    return PopScope(
      // back from the quick-pick returns to setup; never back past sign-in
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) setState(() => _step = 0);
      },
      child: Theme(
        // the accent previews the mode before Continue
        data: buildTheme(mode),
        child: Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.x6, Space.x4, Space.x6, Space.x8),
              children: [
                Row(
                  children: [
                    if (_step == 1)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => setState(() => _step = 0),
                        icon: const Icon(Symbols.arrow_back_rounded),
                      ),
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.overlay,
                          height: 4,
                          decoration: BoxDecoration(
                            // sign-in is done; setup, then the quick-pick
                            color: i <= _step + 1 ? colors.accent : Surface.s4,
                            borderRadius: BorderRadius.circular(Corner.full),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.x6),
                if (user == null)
                  const Center(child: CircularProgressIndicator.adaptive())
                else if (_step == 0)
                  ..._setup(user, counts, mode, colors, listed)
                else
                  _QuickPickStep(
                    mode: mode,
                    picked: _picked,
                    onPicked: (p) => setState(() => _picked = p),
                    onDone: _finish,
                    onSkip: _finish,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _setup(AniListUser user, ({int anime, int manga})? counts, Mode mode, ModeColors colors, int listed) {
    final lang = _lang ?? baseLanguage(user.titleLanguage);
    final adult = _adult ?? user.displayAdultContent;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x2),
      child: Text(
        text,
        style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w600),
      ),
    );

    return [
      Container(
        padding: const EdgeInsets.all(Space.x3),
        decoration: BoxDecoration(
          color: const Color(0x144ED98A),
          borderRadius: BorderRadius.circular(Corner.md),
          border: Border.all(color: const Color(0x404ED98A)),
        ),
        child: Row(
          children: [
            const Icon(Symbols.check_circle_rounded, fill: 1, size: 22, color: Accent.green),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Connected as '),
                    TextSpan(
                      text: user.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: counts == null
                          ? '.'
                          : counts.anime + counts.manga == 0
                          ? '. Your list is empty.'
                          : '. Imported ${counts.anime} anime and ${counts.manga} manga.',
                    ),
                  ],
                ),
                style: AppType.body,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.x6),
      Text('Make it yours', style: AppType.heading),
      label('Open the app in'),
      // tap a side, or drag the thumb (19)
      ModeSlider(value: mode, onChanged: (m) => setState(() => _mode = m)),
      label('Show titles in'),
      Material(
        // a Material, so the tiles' ripples show
        color: Colors.transparent,
        // a ruled group: ink above, a hairline below
        shape: const Border(
          top: BorderSide(color: Surface.rule),
          bottom: BorderSide(color: Surface.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, (key, name, example)) in titleLanguages.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: Space.x4),
              ListTile(
                onTap: () => setState(() => _lang = key),
                title: Text(name, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(example, style: AppType.caption.copyWith(color: TextTone.low)),
                trailing: Icon(
                  lang == key ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  color: lang == key ? colors.accent : TextTone.low,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: Space.x3),
      Material(
        // a Material, so the tiles' ripples show
        color: Colors.transparent,
        // a ruled group: ink above, a hairline below
        shape: const Border(
          top: BorderSide(color: Surface.rule),
          bottom: BorderSide(color: Surface.line),
        ),
        child: SwitchListTile.adaptive(
          value: adult,
          onChanged: (v) {
            unawaited(ref.read(hapticsProvider).play(Haptic.light));
            setState(() => _adult = v);
          },
          activeTrackColor: colors.accent,
          title: Text('Show adult (18+) titles', style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text('Off: hidden and blurred everywhere', style: AppType.caption.copyWith(color: TextTone.low)),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.x3),
        Text(_error!, style: AppType.body.copyWith(color: Accent.danger)),
      ],
      const SizedBox(height: Space.x6),
      FilledButton(
        onPressed: _saving ? null : () => _continue(listed: listed),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: TextTone.high,
          foregroundColor: Surface.base,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(_saving ? 'Saving…' : 'Continue'),
      ),
      TextButton(
        onPressed: _saving ? null : _finish,
        style: TextButton.styleFrom(foregroundColor: TextTone.mid, minimumSize: const Size.fromHeight(44)),
        child: const Text('Skip for now'),
      ),
    ];
  }
}

/// The quick-pick from popular titles in the chosen mode.
class _QuickPickStep extends ConsumerWidget {
  const _QuickPickStep({
    required this.mode,
    required this.picked,
    required this.onPicked,
    required this.onDone,
    required this.onSkip,
  });

  final Mode mode;
  final Set<int> picked;
  final ValueChanged<Set<int>> onPicked;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(homeFeedProvider(mode))) {
      AsyncData(:final value) => QuickPick(
        titles: _choices(value),
        picked: picked,
        onPicked: onPicked,
        onDone: onDone,
        onSkip: onSkip,
      ),
      AsyncError() => Column(
        children: [
          Text("Couldn't load titles to pick from.", style: AppType.body.copyWith(color: TextTone.mid)),
          TextButton(onPressed: onSkip, child: const Text('Skip for now')),
        ],
      ),
      _ => const Padding(
        padding: EdgeInsets.all(Space.x10),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    };
  }
}

/// Nine well-known titles to pick from: trending, then popular, without repeats.
List<Title> _choices(FeedContent feed) {
  final seen = <int>{};
  return [
    for (final t in [...feed.trending, ...feed.popular])
      if (seen.add(t.id)) t,
  ].take(9).toList();
}

/// The choices, shared with Home's empty-list card.
List<Title> quickPickChoices(FeedContent feed) => _choices(feed);
