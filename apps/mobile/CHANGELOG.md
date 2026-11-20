# Changelog

What changed in the Flutter app, newest first. The website (`apps/web`) is the reference: GraphQL queries are copied from it word for word and its unit tests ported alongside. Add a line under **Unreleased** with any change a user would notice. What's planned is in [ROADMAP.md](ROADMAP.md).

## Unreleased

## 2026-11-19: first public release

The source is now open, under the MIT licence. The app is not yet on the App Store or Google Play. What it does at this point, matching the web:

- **Home, the title page, My List, Browse, Seasonal and Schedule, For You, Profile and Stats, Settings and notifications**, plus people's pages and staff, character and studio pages.
- **Built for a phone.** Rows swipe for +1, −1 and quick actions, with haptics; a held poster peeks; the title page drags down to close; paint-select works in My List and onboarding.
- **Works offline.** Your list is cached on the device and edits are queued until AniList can take them.
- **Episode alerts:** the next episode of everything you're watching can be scheduled as a local notification.
- **The editorial look, as on the web.** Fraunces, Schibsted Grotesk and JetBrains Mono are bundled with the app, nothing is fetched at runtime, and text meets AA contrast at 1.3× text size.
- **Checked** in the iOS Simulator, not yet on Android.
