# Publishing miruyo

What's left to put the app on the App Store (and later Google Play), in order. Sources: Flutter's [Build and release an iOS app](https://docs.flutter.dev/deployment/ios), [TFTUS's publishing requirements](https://www.tftus.com/blog/flutter-app-publishing-requirements), Apple's [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) and [privacy manifest docs](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files). Checked against the repo on Oct 10, 2026.

Already done: release builds compile and run on a phone (`flutter build ios --release`), icon (opaque 1024×1024, every size) and launch screen, display name "miruyo", bundle ID `com.jnagra.miruyo`, automatic signing with the personal team, a public privacy policy at [miruyo.jnagra.com/privacy](https://miruyo.jnagra.com/privacy) and terms at /terms, Xcode 27 (Apple requires Xcode 26+ since April 28, 2026).

## 1. Accounts (you)

- [ ] Join the [Apple Developer Program](https://developer.apple.com/programs/enroll/) ($99/year). The free personal team can't upload to App Store Connect or TestFlight, and its installs expire after 7 days. Decide individual or organization first: an organization needs a D-U-N-S number, and the seller name shown on the store comes from this.
- [ ] Set a yearly reminder to renew: a lapsed membership takes the app off the store.
- [ ] (Later, for Android) [Google Play Console](https://play.google.com/console/signup) ($25 once). A personal account has to run a closed test with 12+ testers for 14 days before production.

## 2. App Store Connect record (you)

- [ ] Register the explicit App ID `com.jnagra.miruyo` under [Identifiers](https://developer.apple.com/account/resources/identifiers/list) (Xcode's automatic signing may already have made it once the paid team is selected). No extra capabilities are needed: local notifications need no entitlement.
- [ ] In [App Store Connect](https://appstoreconnect.apple.com/) → Apps → **+** → New App: iOS, name **miruyo** (check it's free; have a fallback like "miruyo for AniList"), primary language, bundle ID, SKU (e.g. `miruyo-ios`).
- [ ] Switch Xcode's Signing team from the personal team to the paid one (commit the project change, as before).

## 3. Code and project changes

- [x] **iPhone only for 1.0**, portrait only (landscape was never designed or tested). The target is iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`); iPad would require iPad screenshots and review on iPad, and tablet layouts aren't done (roadmap Phase 11). Set it to `1`, drop `UISupportedInterfaceOrientations~ipad`.
- [x] **Privacy manifest** (`ios/Runner/PrivacyInfo.xcprivacy`, in the Runner target; the plugins and Flutter ship their own). Add `ios/Runner/PrivacyInfo.xcprivacy` (created through Xcode so it's in the Runner target) declaring: no tracking, no data collected, and the required-reason APIs the app uses (UserDefaults via shared_preferences: `CA92.1`; check the plugins' own manifests cover file timestamp and disk-space use). Verify the merged report: Xcode → Product → Archive → Generate Privacy Report.
- [x] **Export compliance**. Add `ITSAppUsesNonExemptEncryption = false` to Info.plist (the app only uses HTTPS, which is exempt), so each upload doesn't stop for the question.
- [x] **Version and build** (`tool/release.sh [build-number]`). `version: 1.0.0+1` in pubspec.yaml; every upload needs a new build number (`flutter build ipa --build-number=N`).
- [ ] **Deployment target** is iOS 15.0. Fine to keep; raise only if a plugin needs it. Test once on the oldest phone you can.
- [x] **Release secrets**: `tool/release.sh` refuses to build without a client id, runs format, analyze and tests, then `flutter build ipa`. The AniList client id comes from `config/anilist.json` via `--dart-define-from-file`; make sure every release build is made that way (a build without it can't log in). Consider a `tool/release.sh` that runs the checks and `flutter build ipa` with it.
- [x] **Obfuscation**: `tool/release.sh` obfuscates, keeping symbols in `symbols/<version>` (git-ignored; back them up per release). `flutter build ipa --obfuscate --split-debug-info=build/symbols`, keeping the symbols for crash reports.
- [x] **Remove debug-only output** before release (the episode-alerts debug log is `kDebugMode`-only already; check nothing else prints).
- [ ] **Crash reporting (optional but advised).** Without it, crashes on other people's phones are invisible. Sentry or Crashlytics; either means a privacy policy and label update.
- [x] **Update the privacy policy** (and a /support page, for the App Store's support URL: miruyo.jnagra.com/support). for the app: the AniList token is kept in the iOS keychain; the list and Home are cached on the device; episode alerts are scheduled on the device; nothing is sent anywhere but AniList; no tracking. Add an App Store contact/support URL (e.g. miruyo.jnagra.com/support or a GitHub issues page).

## 4. Test like a user

- [x] Signed-out pass on the simulator: every tab, Browse (search, Did you mean, tags), Seasonal and Airing (scrub, week swipe, reminders), a title page (drag to close, favourite, bell). Fixed what it found (keyboard over pages, the filter sheet under the keyboard, Hentai offered signed out).
- [ ] Signed in, on the phone, on the release build: My List, Profile, For You, Notifications, Settings, editing.
- [ ] Fresh install → login → first-run setup → quick-pick (needs an empty-list account) → everything signed out.
- [ ] Offline: airplane mode, edits queue and sync on reconnect.
- [x] An alert actually arriving (simulator, a reminder set 20s ahead: "Black Clover Season 2 · Episode 3 is out").
- [ ] Tapping an alert opens the title (the simulator wouldn't take taps on its lock screen; check on the phone).
- [x] Rate limits: debug builds log each request with what's left of the minute. Every screen signed out used 12 of 30; nothing repeats or loops.
- [x] Largest text (the app caps at 1.3×): fixed poster grids and rows that overflowed; tests at 1.3×.
- [x] VoiceOver basics: Flutter's guidelines (labels, 44pt targets, contrast) run in the tests on every tab, Log In, the title page, My List, For You, Profile and Airing; fixed what they found.
- [x] Reduce Motion: tests for the shared motion and drag-to-close.
- [ ] VoiceOver by ear on the phone: a quick pass through Home, a title, My List.

## 5. TestFlight (by hand, then automate)

- [ ] `tool/release.sh` → `build/ios/ipa/*.ipa`. With the free team it archives but can't export (no "iOS Distribution" certificate); it needs the paid team selected in Xcode.
- [ ] Upload with **Transporter** (drag the .ipa in), or Xcode → Organizer → Distribute App, or `xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey … --apiIssuer …` (App Store Connect API key with App Manager access).
- [ ] Wait for processing (an email within ~30 minutes), then TestFlight → Internal Testing → add yourself and testers.
- [ ] Use it for a week from TestFlight: it's also how the phone stops expiring every 7 days.

## 6. Store listing

- [ ] **Name** (30 chars), **subtitle** (30), **description** (4,000), **keywords** (100), **promotional text** (170). Say it's an unofficial client for AniList: miruyo must not look like AniList's own app, and shouldn't use AniList's logo.
- [ ] **Screenshots**: 6.9" iPhone (1320×2868 or 1290×2796), 1–10 of them, real captures (Home, title page, My List, Seasonal, Stats). The simulator can produce these.
- [ ] **Category**: Entertainment (secondary: Lifestyle or Utilities).
- [ ] **Age rating** questionnaire. The app can show 18+ titles when the AniList account allows it, so answer the mature/suggestive content questions honestly (likely 17+, or keep adult content hidden in-app regardless).
- [ ] **Privacy "nutrition" labels**: Data Not Collected (if no crash reporting); otherwise declare crash data. Must match the privacy manifest.
- [ ] **Pricing and availability**: free, countries.
- [ ] **Support URL**, marketing URL (miruyo.jnagra.com), privacy policy URL, copyright line.

## 7. App Review (you)

- [ ] **Demo account**: the app needs an AniList login, so give review a test AniList account (username/password) with a filled list, in App Review Information. Make a separate account for this, not yours.
- [ ] **Review notes**: explain it's a client for AniList (sign-in is AniList's own OAuth, so Sign in with Apple isn't required by guideline 4.8), that accounts are created and deleted on AniList (guideline 5.1.1(v)), and how to reach the main features.
- [ ] Check AniList's [API terms](https://anilist.gitbook.io/anilist-apiv2-docs/) allow a published client (they do for non-commercial use; don't charge for it without asking), and that cover art use is as AniList serves it.
- [ ] Submit for Review; choose manual or automatic release after approval. If rejected: fix only what's flagged, bump the build number, reply in the Resolution Center.

## 8. After launch

- [ ] Watch crashes and reviews; keep Flutter and plugins current (`flutter pub outdated`).
- [ ] Apple raises the required Xcode/SDK every spring; rebuild with the new one before then.
- [ ] Renew the developer membership yearly.

## Google Play (later)

The Android app isn't built yet on this Mac (no Android SDK). When it is:

- [ ] Install Android Studio / the SDK; `flutter build appbundle --release`; test the release APK on a real phone.
- [ ] Upload keystore (`keytool`), `android/key.properties` (git-ignored, backed up somewhere safe), and a release `signingConfig` (it's the debug key now); enrol in Play App Signing.
- [ ] targetSdk 35+ (Flutter's default; check), 64-bit libraries present, merged-manifest permission audit (`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `INTERNET`).
- [ ] Data safety form, content rating, target audience, ads declaration (none), 512×512 icon, 1024×500 feature graphic, 2–8 phone screenshots.
- [ ] Closed test with 12 testers for 14 days (personal account), then production.
