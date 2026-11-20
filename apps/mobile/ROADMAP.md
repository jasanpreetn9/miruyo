# Roadmap

What's planned for the Flutter app. What has already shipped is in [CHANGELOG.md](CHANGELOG.md), and the steps to publish it are in [PUBLISHING.md](PUBLISHING.md). Want to take something on? Open an issue first so we can talk it through ([CONTRIBUTING.md](../../CONTRIBUTING.md)).

The website in [`apps/web`](../web) is the reference for screens and AniList behaviour. The app keeps up with it: when the web gains a feature, it lands here too. The gesture rules live in `lib/core/gestures` and `GestureSpec` (`lib/core/theme/tokens.dart`).

## Next up: a 1.0 release

- [ ] **Signing and TestFlight**, which needs an Apple developer team.
- [ ] **An Android release build**, and a pass on an Android phone; so far the app has been checked only in the iOS Simulator.
- [ ] **An accessibility pass** (PUBLISHING.md, step 4).
- [ ] **Try the Follow button** on someone else's page; it hasn't been checked in the app yet.

## Later

- [ ] **Tablet layouts.** 1.0 is iPhone only, in portrait.
- [ ] **A debug gallery** of the shared widgets.

## Decisions

- **State:** Riverpod. **Routing:** go_router. **Storage:** drift for the cached list and the offline edit queue, the keychain (or Android's encrypted storage) for the token.
- **AniList:** the web's GraphQL queries, copied word for word, over `http`.
- **Offline:** the list is cached on the device, and edits are queued until AniList can take them.
- **Reminders:** AniList's airing notifications, plus on-device local notifications for the next episode of everything you're watching.
- **Fonts** are bundled in `fonts/` and declared in `pubspec.yaml`, so nothing is fetched at runtime.
