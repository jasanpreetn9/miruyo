import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anilist/client.dart';
import '../../core/anilist/errors.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/score.dart';
import '../../core/gestures/haptics.dart';
import '../../core/notifications/episode_alerts.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Settings, after the web's /settings. Everything here is saved to the
/// AniList account (miruyo follows it rather than keeping its own copy), so
/// each change saves as soon as it's made and rolls back if AniList refuses.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

const titleLanguages = [
  (TitleLanguage.romaji, 'Romaji', 'Kusuriya no Hitorigoto'),
  (TitleLanguage.english, 'English', 'The Apothecary Diaries'),
  (TitleLanguage.native, 'Native', '薬屋のひとりごと'),
];

const _scoreFormats = [
  (ScoreFormat.point10Decimal, '10 points, with decimals', 8.5),
  (ScoreFormat.point10, '10 points', 8.0),
  (ScoreFormat.point100, '100 points', 85.0),
  (ScoreFormat.point5, '5 stars', 4.0),
  (ScoreFormat.point3, '3 smileys', 3.0),
];

/// ROMAJI_STYLISED → ROMAJI: the picker offers the base languages.
TitleLanguage baseLanguage(TitleLanguage? lang) => switch (lang) {
  TitleLanguage.english || TitleLanguage.englishStylised => TitleLanguage.english,
  TitleLanguage.native || TitleLanguage.nativeStylised => TitleLanguage.native,
  _ => TitleLanguage.romaji,
};

/// Keeps the account's "stylised" choice (official casing) when switching.
TitleLanguage withLanguageStyle(TitleLanguage lang, TitleLanguage? current) {
  final stylised = current?.api.endsWith('_STYLISED') ?? false;
  if (!stylised) return lang;
  return TitleLanguage.values.firstWhere((l) => l.api == '${lang.api}_STYLISED');
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ViewerSettings _pending = const ViewerSettings();
  bool _saving = false;

  Future<void> _save(ViewerSettings patch) async {
    if (_saving) return;
    unawaited(ref.read(hapticsProvider).play(Haptic.light));
    setState(() {
      _saving = true;
      _pending = patch;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionProvider.notifier).updateSettings(patch);
      messenger.showSnackBar(const SnackBar(content: Text('Saved to AniList'), duration: Duration(seconds: 2)));
    } on AniListError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save to AniList (${e.message}). Nothing was changed.")));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _pending = const ViewerSettings();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final lang = baseLanguage(_pending.titleLanguage ?? user?.titleLanguage);
    final adult = _pending.displayAdultContent ?? user?.displayAdultContent ?? false;
    final airing = _pending.airingNotifications ?? user?.airingNotifications ?? true;
    final scoreFormat = _pending.scoreFormat ?? session.scoreFormat;
    final accent = context.mode.accent;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.x1, Space.x6, Space.x1, Space.x2),
      child: Text(text, style: AppType.section.copyWith(fontSize: 18)),
    );

    // a Material, so the tiles' ripples show
    Widget group(List<Widget> children) => Material(
      color: Surface.s1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corner.md),
        side: const BorderSide(color: Surface.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(height: 1, indent: Space.x4), c],
        ],
      ),
    );

    Widget choice({required bool selected, required String title, String? detail, required VoidCallback onTap}) =>
        ListTile(
          onTap: _saving || selected ? null : onTap,
          title: Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
          subtitle: detail == null ? null : Text(detail, style: AppType.caption.copyWith(color: TextTone.low)),
          trailing: Icon(
            selected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
            color: selected ? accent : TextTone.low,
          ),
          selected: selected,
        );

    Widget toggle({
      required bool value,
      required String title,
      required String detail,
      required ValueChanged<bool> onChanged,
    }) => SwitchListTile.adaptive(
      value: value,
      onChanged: _saving ? null : onChanged,
      activeTrackColor: accent,
      title: Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(detail, style: AppType.caption.copyWith(color: TextTone.low)),
    );

    Widget link(IconData icon, String title, String detail, VoidCallback onTap, {Color? color}) => ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? TextTone.mid),
      title: Text(
        title,
        style: AppType.body.copyWith(fontWeight: FontWeight.w500, color: color),
      ),
      subtitle: Text(detail, style: AppType.caption.copyWith(color: TextTone.low)),
      trailing: color == null ? const Icon(Symbols.open_in_new_rounded, size: 18, color: TextTone.low) : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppType.title),
        backgroundColor: Surface.base,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x10),
        children: [
          heading('Display'),
          Padding(
            padding: const EdgeInsets.only(left: Space.x1, bottom: Space.x2),
            child: Text('Show titles in', style: AppType.caption.copyWith(color: TextTone.mid)),
          ),
          group([
            for (final (key, name, example) in titleLanguages)
              choice(
                selected: lang == key,
                title: name,
                detail: example,
                onTap: () => _save(ViewerSettings(titleLanguage: withLanguageStyle(key, user?.titleLanguage))),
              ),
          ]),
          const SizedBox(height: Space.x3),
          group([
            toggle(
              value: adult,
              title: 'Show adult (18+) titles',
              detail: 'Off: hidden from feeds, and covers are blurred',
              onChanged: (v) => _save(ViewerSettings(displayAdultContent: v)),
            ),
          ]),
          heading('Scoring'),
          group([
            for (final (key, name, example) in _scoreFormats)
              choice(
                selected: scoreFormat == key,
                title: name,
                detail: 'e.g. ${formatScore(example, key)}',
                onTap: () => _save(ViewerSettings(scoreFormat: key)),
              ),
          ]),
          heading('Notifications'),
          group([
            toggle(
              value: airing,
              title: 'New episodes on AniList',
              detail: 'AniList lists it under the bell when an episode of something you watch airs',
              onChanged: (v) => _save(ViewerSettings(airingNotifications: v)),
            ),
            // on the device, not the account: the phone's own notification
            SwitchListTile.adaptive(
              value: ref.watch(episodeAlertsProvider),
              onChanged: (v) async {
                final alerts = ref.read(episodeAlertsProvider.notifier);
                if (!v) return alerts.disable();
                final messenger = ScaffoldMessenger.of(context);
                if (!await alerts.enable()) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Notifications are off for miruyo. Allow them in the phone’s Settings.'),
                    ),
                  );
                }
              },
              activeTrackColor: accent,
              title: Text('Alerts on this phone', style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text(
                'A notification when a new episode of something you’re watching comes out',
                style: AppType.caption.copyWith(color: TextTone.low),
              ),
            ),
          ]),
          heading('Account'),
          group([
            ListTile(
              leading: const Icon(Symbols.person_rounded, color: TextTone.mid),
              title: Text(user?.name ?? '', style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
              subtitle: Text('Signed in as', style: AppType.caption.copyWith(color: TextTone.low)),
            ),
            link(
              Symbols.tune_rounded,
              'More settings on AniList',
              'Profile, privacy, lists',
              () => launchUrl(Uri.parse('https://anilist.co/settings'), mode: LaunchMode.externalApplication),
            ),
            link(Symbols.logout_rounded, 'Sign out', 'On this device only', () async {
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/');
            }, color: Accent.danger),
          ]),
          const SizedBox(height: Space.x6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (name, url) in [
                ('Terms of Use', 'https://miruyo.jnagra.com/terms'),
                ('Privacy Policy', 'https://miruyo.jnagra.com/privacy'),
              ])
                TextButton(
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                  style: TextButton.styleFrom(foregroundColor: TextTone.low),
                  child: Text(name, style: AppType.caption),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
