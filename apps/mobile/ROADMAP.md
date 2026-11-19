# miruyo mobile roadmap

The path to a mobile v1 that matches the design and the web app. **Source of truth:** the design export in [`design/`](../../design): `shared/` for screens, `mobile/` for gestures (screens 11–22, with 22 as the shared rules). The web app in [`apps/web`](../web) is the reference for AniList behaviour.

**Decisions:** Riverpod for state; the web's GraphQL queries ported verbatim over `http`; a cached list plus queued edits for offline; AniList's airing notifications plus on-device local notifications for reminders.

Critical path: 1 → 2 → 5. Phases 4 and 6–10 can go in any order after 5. Caught up with the web as of `e589b4b` (Nov 4, 2026): custom lists, rate pacing, the title page's tags and links, staff and character pages, Browse's exclusions, presets and people, user pages, Home's Upcoming and Continue, For You's daily rotation, the title page's Stats tab, titles before people in a search, and the season chart's year range. Next up: Phase 11 (polish and release builds), and the open items left in each phase.

## Phase 0 — Setup ✅

- [x] Packages, lints (120-column format), drift codegen.
- [x] `.github/workflows/mobile.yml`: codegen check, format, analyze, test on changes to `apps/mobile`.
- [x] README, run config (`config/anilist.example.json`), Android OAuth callback and permissions.
- [x] Bricolage Grotesque, Geist and Geist Mono bundled in `google_fonts/` (runtime fetching off; OFL licences registered).

## Phase 1 — Foundations ✅

- [x] Design tokens and theme, with a mode-aware accent that cross-fades.
- [x] AniList client: error kinds, 60s cache with in-flight dedupe, real 429 headers, a device copy of the list and Home for offline. Queries checked string-for-string against the web's.
- [x] Requests paced to AniList's rate limit (`pacer.dart`, the web's): at 5 or fewer left they go one at a time at the limit's pace, and a 429's Retry-After holds every request.
- [x] Catalog logic and its web tests ported: humanize, score, status, +1, airing chip, seasons, titles. Cover-colour mixing matches Chrome's `color-mix(in oklch)`.
- [x] Sign-in (OAuth in a sheet, token in the keychain), session with rate-limit retry and sign-out on a rejected token.
- [x] List store with optimistic edits and rollback; edits AniList can't take yet are queued in drift and sent on reconnect, sign-in and resume.
- [x] Toasts (max 3, Undo 5s for removals, 4s otherwise) and the haptic scale.
- [x] Shell: tabs (Seasonal → Releases in manga), top bar, mode toggle with drag and the halfway haptic, login screen.

## Signed-out experience ✅

Everything that works without an account, built ahead of the AniList client id. It covers parts of Phases 2, 4, 5, 7 and 8; what's left of each is listed under its phase.

- [x] PosterCard (a clean cover with no badges, 18+ hidden with Reveal, status pill, +1 and progress line once signed in), PosterRow, CoverImage (fades in over the cover colour), CountdownChip (blue → accent with a live dot → "Airing now"), Skeleton, SectionError (the rate-limit countdown retries on its own), hold-to-peek (450ms, dips to 96%, Medium haptic).
- [x] Home signed out: the poster wall and pitch, Trending, Popular this season (with countdowns), Upcoming; pull to refresh; the device's copy when offline.
- [x] Detail: banner or blurred cover, headline, countdown strip, Add to list (leads to Log In), score, rank, members, trailer, genres, synopsis, facts; sticky tabs for Overview, Relations, Characters & Staff and Recommendations; manga's publication card.
- [x] Browse: search (300ms debounce), the filter sheet as a draft with a live match count and Restore, removable chips, sort, pinch or tap for 2 / 3 across / list, paging, "See all" links, empty states.
- [x] Seasonal: the season chart (sections, season tabs, sort, AniChart-style cards or posters, remembered) and Airing (the week with ±4 week paging and the day strip; this week's past days fold under "Earlier this week"); manga's New releases.
- [x] My List and Profile explain what logging in gives you.
- [x] List actions anywhere lead to Log In while signed out.
- [x] Screen data is kept 5 minutes after leaving a screen (AniList is limiting to 30 requests a minute at the moment).

## Phase 2 — Shared widgets and gesture toolkit

- [x] Row swipes (`RowSwipe`): right +1, short left −1, long left or a hold for quick actions; thresholds measured from the touch (72 / 160px, flick 0.6px/ms after 32px), the track previews the result, haptics once per crossing. Tested at 71/72/159/160px.
- [x] Quick actions sheet: −1 / +1 / Edit, statuses, Open details, Remove (Undo 5s).
- [x] ScoreCells (drag, left half for .5, follows the score format), CountStepper (scrub 14px per step, hold to repeat), HoldToConfirm (800ms).
- [x] Paint-select (My List, quick-pick), drag-to-close (Detail), draggable thumbs (ModeSlider).
- [ ] A debug gallery of the widgets (not planned for 1.0).

## Phase 3 — Login & onboarding (09, 19)

- [x] First-run setup after the first sign-in on a device: "Connected as… Imported N anime and M manga", then the mode to open in (the accent previews it), title language and 18+, saved to AniList on Continue; Skip for now.
- [x] The quick-pick for an empty list: tap, or drag across posters to pick several (the first poster decides add or remove); picks go on as Completed. Back returns to setup with the picks kept; nothing goes back past sign-in.
- [x] Home's empty-list card uses the same quick-pick, until it's skipped (per account and mode).
- [x] Dragging the mode thumb in setup (ModeSlider, also on Profile); hold a quick-pick poster to peek.

## Phase 4 — Home (01, 14)

- [x] Picked for you at the top, then Trending, then Continue: everything in progress (ready first, their +1 green; then the countdowns), Up next from Planning with Start, Paused as one line. Rows say when the next episode airs, or the time left to finish; Up next says how long a title is ("24 eps", "1h 47m") and starts with a Start button. Caught up, the card says so and the summary doesn't repeat it.
- [x] Picked for you, at the top of Home: For You's picks (this season's first) with their reason, Plan and Not this; with no picks, the season's most popular you haven't added, and that row steps aside. Swipe or tap a dot; it never moves on its own.
- [x] The For You rows, only when full (six or more) and without the hero's picks.
- [x] The empty-list quick-pick.
- [x] Upcoming: six titles, dated premieres first (soonest first), each row the season, the title (a long sequel shortened in the middle so its season survives), the studio, then the countdown once AniList has a date; no "Unknown" format.
- [x] The full offline banner (1j): what's shown and from when, changes queued, Retry; discovery rows say they need a connection.

## Phase 5 — Detail and the list editor (03, 04, 12, 20)

- [x] Detail, and the list editor sheet: saves as you go, status chips with smart dates, progress (auto-completes at the total with an inline Undo), volumes, score, dates, rewatches, notes (asks only when half-typed), private, hold to remove.
- [x] Detail: drag down to close (from the top, 140px or a flick), the favourite heart, Remind me on the countdown (a local reminder, shared with episode alerts).
- [x] Detail: tags ranked by fit (spoilers behind "Show N spoilers", 18+ only when the account shows them; a tag opens Browse), Where to watch / read above the tabs (six, then "N more"), Links and Also known as closing the Overview, the other names under the headline. Opening a title switches the mode to match, once per title.
- [x] Detail: a Stats tab after Characters & Staff (rankings two to a row, each opening Browse; how many people have it on each list; the 1–10 score chart in the cover's colour), fetched when the tab opens. The tab strip scrolls the open tab fully into view.

## Staff and character pages ✅

From the web (`page-data/person.ts`, `markdown.ts`, with their tests).

- [x] `/staff/:id`: who someone is (portrait, other names, Favourite, bio, facts, View on AniList), then their voice roles and credits (folded per title), Popular or Newest, 25 at a time with Load more. Voice actors lead with their roles, authors and directors with their credits.
- [x] `/character/:id`: every title a character is in, with their voice actors one language at a time (Japanese first); spoiler names wait to be asked for.
- [x] Bios are AniList's markdown made into text (never markup): spoilers behind a chip, AniList links open in miruyo, the leading "Height: 157 cm" lines become facts.
- [x] Role cards say your status for titles on your list. The title page's characters, voice actors and manga authors, and Profile's favourite people, open these pages instead of AniList. Share copies the page's web link.
- [x] `/studio/:id` (Nov 2026, as on the web): a studio in the same layout, its portrait an icon (AniList has no picture), Favourite, then its titles, Popular or Newest, with Load more and "Producer" on titles it only helped on. Studios in a search, favourite studios and the title page's Studio row open it.

## Phase 6 — My List (05, 11, 21)

- [x] Status tabs with counts, the summary line, filter, sort (Planning defaults to Up next), and the list or a 3-across grid, one choice for every tab. Rows say what's new ("2 behind · EP 9 in 2d 4h"), carry +1 and the row swipes; pull to refresh; the device's copy offline.
- [x] Edit: circles to tap or paint down, a 300ms hold to carry the selection to the status panel, Move to…, hold to remove; one Undo for the lot. The edit bar takes the tab bar's place; swipes and pull to refresh pause.
- [x] Up next: drag handles on Planning in Edit, saved as AniList entry `priority` (added to both apps' save mutation), changing as few entries as it can.
- [x] Auto-scroll while painting near the edges; Move to top of Up next in quick actions (the screen-reader path for reordering).
- [x] Custom lists from AniList are tabs after the statuses (`/list?list=`), each row saying its status. Titles set to "hide from status lists" show only there, and count in Stats, For You and the summary. The editor sheet puts a title on a custom list, or takes it off ([#62](https://github.com/jasanpreetn9/miruyo/pull/62), as on the web).

## Phase 7 — Browse (02, 15)

Built, with list-row swipes (right Planning, left Not interested, shared with For You), tags in the filter sheet, and "Did you mean" (closest spelling among the most popular titles).

- [x] Exclusions: a genre goes in on the first tap, out on the second (struck through, a block icon), off on the third; a tag match's block button leaves it out. They're `?not_genre=` / `?not_tag=`, "Not Romance" chips, and AniList's `genre_not_in` / `tag_not_in`.
- [x] Ready-made lists under the search box while not searching (All-time popular, Trending, Top rated, Airing now or Releasing, Upcoming), the one you're on marked. Ordered lists number their results (#1 on each cover, a number on each row); searches and Newest don't.
- [x] A search also shows the characters, staff, AniList users and (anime) studios it matches, after the first two rows of titles (six covers or four list rows), as on the web; people, users and studios open their pages.

## Phase 8 — Seasonal & Schedule (06, 16)

Built, with slot swipes (+1 on yours once aired, a reminder on upcoming ones, Planning on others, −1), the day strip (highlights the day at the top; tap or scrub), the swipeable week bar (±4 weeks), and Back to now (also on tapping the tab again). A link opens the season chart only for 1940 to two years ahead, as on the web.

## Phase 9 — Profile, Stats & Settings (07, 18)

- [x] Profile: banner, avatar, member since, links to AniList and Settings; favourite titles (for the current mode), characters, staff and studios.
- [x] Stats from the list collection (the web's buildStats, with its tests): four cards, score distribution, finished per month, formats, statuses, top genres and the 26-week activity grid, for All time / this year / the last 12 months. Bars and the grid scrub sideways or by tap, with the value in the card header for 1.5s. The Anime/Manga switch moves the top bar's mode too.
- [x] Settings: title language, 18+, score format, airing notifications (all saved to AniList, rolled back if refused), sign out, legal links.
- [x] Swiping the stat cards between Anime and Manga; hold-to-peek on favourites (PosterRow).
- [x] User pages (`/user/:name`), as on the web: your profile is your own user page, laid out like the staff and character pages (avatar, Settings or Follow with Share, the bio, a facts card whose numbers are the Stats cards'), then Overview, Anime list and Manga list (someone else's, read-only, by status, sortable and filtered by Genre, Country and Year; a private list says so), Favourites and Stats. Others' lists come as anyone sees them, scores out of 10, 18+ titles left out unless your account shows them (lists, Stats and the facts card count the same). Follow notifications open these pages. Favourites are listed once each.

## Phase 10 — For You (08, 17)

- [x] Picks from AniList's recommendations for your highest-rated titles, nudged toward the genres you rate well (the web's buildPicks, with its tests); a cold start under 5 ratings.
- [x] Every pick swipes: right Planning, left Not this (hidden for good on the device). Hold for Why this pick: your rating of the seed, shared genres, AniList's recommendation count; Not this, Planning, Details.
- [x] The seed rail: tap to filter, swipe up to stop using a seed (its picks leave with it). Every action has Undo.
- [x] Home's For You row, with the reason under each pick.
- [x] Studios, across modes and Tune ([#61](https://github.com/jasanpreetn9/miruyo/pull/61), as on the web): favourite studios weigh more (the hold sheet says which, opening its page); the other list's top titles suggest their manga or anime, their seeds on the rail; Tune (app bar) leaves out titles not out yet, the other list's picks, or genres, and Home follows it.
- [x] The seeds rotate each day, as on the web (the same hash, so both draw the same titles): up to 8 of the titles you rated 7.5 or more, weighted so a 10 comes round about six times as often as a 7.5, ranked by your exact score. Home's "Because you loved…" rows change with them at midnight; a seed you stopped using doesn't take a slot.

## Phase 11 — Notifications and polish

- [x] Notifications: AniList's latest with the unread ones marked (opening them marks them read, as on the web); titles open in miruyo, the rest on AniList.
- [x] The rows' coach mark: on My List's first visit the top row (or card) demonstrates the swipes beside a card that explains them, until "Got it". Reduce Motion keeps the card and drops the demonstration.
- [x] App icon and launch screen: the 見 mark on Beni (`tool/make_icons.sh` regenerates every size from `tool/make_icon.swift`), the mark centred on the dark launch screen; "miruyo" under the icon.
- [x] A release build compiles (`flutter build ios --release --no-codesign`, 22.5 MB).
- [ ] Signing and TestFlight (needs the Apple developer team), Android release (needs the Android SDK on this Mac).
- [ ] Tablet layouts (1.0 is iPhone only); an accessibility pass (see PUBLISHING.md step 4).
- [x] Tapping the current tab scrolls it back to the top.
- [x] The bell refreshes on resume and every 5 minutes while the app is open.
- [x] Episode alerts on this phone: the next episode of everything you're watching is scheduled as a local notification (AniList publishes the air times), rescheduled on start, resume and sign-in; cleared on sign-out. Off until turned on (Notifications offers it; Settings toggles it), which asks for permission. A tap opens the title.
