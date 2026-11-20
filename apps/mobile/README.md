# miruyo mobile

The iOS and Android app, in Flutter. It talks to AniList directly, the same way the [web app](../web) does, and adds what a phone allows: swipe gestures, haptics, and a list that works offline, with edits queued until AniList can take them. It can also remind you when a new episode airs.

What's planned is in [ROADMAP.md](ROADMAP.md) and what changed in [CHANGELOG.md](CHANGELOG.md); what is left to publish it, in [PUBLISHING.md](PUBLISHING.md).

## Running it

1. Create an AniList API client at [anilist.co/settings/developer](https://anilist.co/settings/developer) with the redirect URL `miruyo://auth`. It has to be a separate client from the web's, because a client has only one redirect URL.
2. Copy `config/anilist.example.json` to `config/anilist.json` (git-ignored) and put the client's id in it.
3. Run:

```bash
flutter run --dart-define-from-file=config/anilist.json
```

Without a client id, the app still runs signed out; Log In explains what's missing.

## Checks

Format with the script, not `dart format lib`: it leaves the generated `*.g.dart` files alone, which CI checks against build_runner's own output.

```bash
tool/format.sh
```

```bash
flutter analyze
```

```bash
flutter test
```

App Store builds: `tool/release.sh [build-number]` checks everything, then builds the .ipa (see [PUBLISHING.md](PUBLISHING.md)).

The app icon and launch mark are generated: after changing `tool/make_icon.swift`, run `tool/make_icons.sh` (macOS) to rewrite every iOS and Android size.

Drift's generated code (`*.g.dart`) is committed. After changing a table, regenerate it:

```bash
dart run build_runner build --delete-conflicting-outputs
```

CI ([`.github/workflows/mobile.yml`](../../.github/workflows/mobile.yml)) runs codegen, format, analyze and tests whenever `apps/mobile` changes.

## Layout

| Folder              | What it is                                                                                                                                                                                                                                                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/core/theme`    | Design tokens (kept in step with the web): colours, type, spacing, corners, motion, gesture thresholds                                                                                                                                                                                                                                                                   |
| `lib/core/anilist`  | The GraphQL client and queries, ported from `apps/web/src/lib/anilist` (the queries are copied verbatim)                                                                                                                                                                                                                                                                 |
| `lib/core/catalog`  | Pure logic shared with the web: titles, status verbs, scores, +1 rules, airing chips, cover colours                                                                                                                                                                                                                                                                      |
| `lib/core/list`     | The list store (optimistic edits, Undo) and the actions cards and rows call                                                                                                                                                                                                                                                                                              |
| `lib/core/sync`     | The offline edit queue                                                                                                                                                                                                                                                                                                                                                   |
| `lib/core/storage`  | Device storage: preferences, the keychain token, the drift database                                                                                                                                                                                                                                                                                                      |
| `lib/core/auth`     | AniList sign-in and the session                                                                                                                                                                                                                                                                                                                                          |
| `lib/core/gestures` | The haptic scale and the shared gestures: the row swipe (+1, −1, quick actions)                                                                                                                                                                                                                                                                                          |
| `lib/core/ui`       | App-wide UI state: toasts, the ticking clock for countdowns                                                                                                                                                                                                                                                                                                              |
| `lib/widgets`       | Shared widgets: poster card and row, cover image, countdown chip, peek, score cells, count stepper, hold-to-confirm, skeletons, section errors                                                                                                                                                                                                                           |
| `lib/features`      | Screens, one folder each: `home`, `browse`, `detail`, `seasonal`, `list` (My List and its Edit mode), `profile` (Profile, Stats, Settings), `for_you`, `notifications`, `editor` (the list editor and quick actions), `onboarding` (login and first-run setup), `person` (staff and character pages), `studio`, `user` (people's pages), `shell` (tabs, top bar, router) |

Tests live in `test/`, in folders that mirror `lib/` (`test/features/home/home_screen_test.dart` tests `lib/features/home/home_screen.dart`). `test/helpers.dart` has the shared setup; `test/flutter_test_config.dart` loads the bundled fonts so text measures as it does on a phone.

The web app is the reference for behaviour: when this app and the web disagree about AniList, check `apps/web` first. The web app is also the reference for how things look; how things move on a phone (the gestures) is documented in the code, `lib/core/gestures` and `lib/core/theme/tokens.dart`.
