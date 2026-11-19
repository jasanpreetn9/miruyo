# Changelog

What changed in the Flutter app, newest first. The website (`apps/web`) is the reference: app work is mostly bringing the app up to it, with GraphQL queries copied word for word and the web's unit tests ported alongside.

## Next

### The editorial redesign, as on the web

The app takes the website's editorial look (mockups in [`design/mockups`](../../design/mockups)). Tokens: the warm palette and cream ink, vermilion for anime, square corners (`Corner` 2–6), and the quiet grey lifted to `#938979` so it passes AA on every surface up to S3 (the web's `--color-dim` follows). Type: Fraunces, Schibsted Grotesk and JetBrains Mono, bundled as variable fonts in `fonts/` (pubspec `fonts:`; `google_fonts` dropped), weights and Fraunces's optical size set through font variations; tests load them (`flutter_test_config.dart`). Shared: `SectionHeading` (serif, a Japanese gloss, a hairline that draws in), `Halftone`, `Tick`, `offsetShadow`; the mode toggle and tab bar as words over a rule; main actions in ink, chips square, fields underlined, cards ruled. Home: a masthead, Continue first with a lead card (its +1 counter ticks; it keeps the row's swipes), the pick ruled over a halftone. The title page: a duotone banner (modulate, so empty pixels stay clear), the score large in the cover's colour, genres and tags as words. Seasonal: the season's kanji, text season tabs, ruled entries. A Home test runs at 1.3× text on a 375pt phone. Checked in the iOS Simulator (Home, the title page, Seasonal, My List, Browse and its filters, the editor, Profile, manga mode); not yet on Android.

### For You measures your taste against your own scores

Web and app together. `lovedFrom` (half a deviation above your mean, 7 to 9; 7.5 under 10 scores) decides seeds and favourite studios; `genreLift` replaces the five most frequent genres, so a pick's genres move it by how far you rate them above your usual (−30% to +40%), and Why this pick's "Shares …" lists only genres clearly above it. Recommendations voted to nothing are left out; `forYouQuery` asks for 20 a seed instead of 8 (checked against the live API). The data tests are ported from the web's.

### In progress: `perf/list-cache`

- **Your list shows at once, and refreshes behind the screen** ([#66](https://github.com/jasanpreetn9/miruyo/pull/66), web and app together). The list collection is served from the copy in memory even past its minute or after an edit, while AniList's newer one loads behind it (`cachedQuery`'s `staleWhileRevalidate`, also saved on the device); My List and someone's list rebuild when it lands, keeping their rows. Each response carries the list store's stamp from when it was requested (`Fetched.stamp`), so an older copy never undoes an edit. Pull to refresh still waits for a new copy. The device copy is written once per response, not on every read.
- **For You loads both lists at the same time** ([#66](https://github.com/jasanpreetn9/miruyo/pull/66)). The app keeps the 230px row thumbnails: at 3x, its 40–48pt slots need more than the 100px cover the web now uses. Checked in the iOS Simulator (My List, pull to refresh, Home's picks).

### Still to check or fix

- The Follow button on someone else's page hasn't been tried in the app. Their page itself now opens from a search and works.
- The build on the iPhone predates the staff page's Popular/Newest chips. Reinstall it with a release build. The free signing team expires installs after 7 days.

## 2026-11-11: someone's list filters by genre, country and year

[PR #65](https://github.com/jasanpreetn9/miruyo/pull/65), web and app together. A user page's Anime and Manga lists gain Genre, Country and Year menus under the summary, each offering what's on the status ("South Korea", "2019"), with "Any…" to clear. `ListMedia` gains `countryOfOrigin` and `startDate { year }` (a manga's year), copied from the web; `buildListView` takes the three filters. Checked in the iOS Simulator on a real list.

## 2026-11-11: the editor puts a title on your custom lists

**The editor puts a title on your custom lists, or takes it off** ([#62](https://github.com/jasanpreetn9/miruyo/pull/62), web and app together). A Custom lists row of chips in the editor sheet, before Private, when you have custom lists for the title's type; a tap saves the whole set at once. The list names come from the viewer's `mediaListOptions` (empty lists too), the entry's from `customLists(asArray: true)`; `EntryInput`'s JSON carries it through the offline queue, and My List's collection reloads when the sheet closes. An edit made before the full entry loads keeps the title's lists, and Undo puts them back. A save to a real custom list isn't checked, as the test account has none.

## 2026-11-11: the Picked for you card fits, and the score bars are 44pt targets

[PR #63](https://github.com/jasanpreetn9/miruyo/pull/63). Home's Picked for you card measures its lines in its own text styles, so it no longer overflows by 1.2pt; each score bar fills the chart's height, a 44pt tap target even when empty.

## 2026-11-09: For You weighs studios, suggests across modes, and can be tuned

**For You: studios, picks across anime and manga, and Tune picks** ([#61](https://github.com/jasanpreetn9/miruyo/pull/61), web and app together). Favourite studios (two titles rated 7.5+) weigh 15% more, and holding a pick says "From MADHOUSE", opening its page; `AniListMedia` gains `mainStudio`. The day's top four titles on the other list suggest their source manga or two most popular anime (`forYouRelationsQuery`, copied from the web), with their seeds on the rail; a list with too few ratings shows those instead of the cold start. Tune (app bar) leaves out titles not out yet, the other list's picks, or genres; Home follows it. Checked in the iOS Simulator.

## 2026-11-09: a studio page

[PR #56](https://github.com/jasanpreetn9/miruyo/pull/56), web and app together. `/studio/:id` shows a studio in the person pages' layout (its portrait a film icon), Add to favourites, Share, a Type fact and View on AniList, then its titles, popular or newest first, with Load more and "Producer" on titles it only helped on. Studios in a search, favourite studios and the title page's Studio row open it.

## 2026-11-08: Up next only offers titles that are out

[PR #55](https://github.com/jasanpreetn9/miruyo/pull/55), web and app together. Up next skips Planning titles that aren't out yet (they're on the Upcoming row) and keeps the first four by priority; the home query asks for twelve Planning entries so it still fills. The row's "Not out yet" line is gone.

## 2026-11-08: a search also finds AniList users

[PR #54](https://github.com/jasanpreetn9/miruyo/pull/54), web and app together. A Browse search shows the users whose names match, in a Users row after Staff, each opening `/user/:name`. Checked in the iOS Simulator: a search for "josh" lists users, and tapping one opens their page.

## 2026-11-07: title page tags fold to eight

[PR #53](https://github.com/jasanpreetn9/miruyo/pull/53), web and app together. A title's tags show the eight best-fitting, then an "N more" chip that opens the rest and becomes "Show fewer", announced as expanded or collapsed. Showing spoilers opens them all. A test checks the fold, the toggle, the spoiler case, and the tap-target and contrast guidelines.

## 2026-11-07: caught up with the web's November changes

[PR #52](https://github.com/jasanpreetn9/miruyo/pull/52). This brings the app up to the website as of `e589b4b`, porting the four web changes made since the last catch-up, one commit each. 352 tests pass. All four were checked in the iOS Simulator against the live API.

- **Title pages get a Stats tab** (`2a48162`, web `3a5eabd`). It sits after Characters & Staff and loads `titleStatsQuery`, copied from the web, only when the tab opens:
  - **Rankings**, two to a row: all time first, then the year, then the season. Each opens the same list in Browse, except a manga's yearly ranking.
  - **On lists:** one bar coloured by status, with each list's count and share.
  - **Score distribution:** the average, and a 1–10 chart in the cover's colour. It reuses the profile's `ScrubBars`, which now take an optional colour, so a drag or tap reads out "1,234 scored it 8". A title with no scores says so instead, so the chart's 25pt empty bars never show here.
  - `buildTitleStats` is ported with the web's unit tests. A widget test opens the tab and runs the tap-target and contrast checks.
- **A search shows titles first** (`6454339`, web `62db66d`). Characters, staff and studios now follow the first two rows of titles: six covers, or four list rows. With fewer titles, an error or none, they follow whatever is there.
- **A title page's open tab is never cut off** (`7f95e67`, web `7d837fd`). The five tabs are wider than a phone, so the strip now scrolls just enough to show the open tab, whether it was tapped or opened by an "All →" link. Under Reduce Motion it jumps instead of animating.
- **The season chart only opens years it can show** (`a0d8567`, web `e589b4b`). `parseSeasonQuery` accepts 1940 through two years ahead, as the web's `parseSeasonParams` does. The app has no season arrows, and its tabs sit around the current season, so only a link could ask for a year outside that range.

## 2026-11-07: a missing list reads as empty

[PR #50](https://github.com/jasanpreetn9/miruyo/pull/50). The app already read a missing `MediaListCollection`, or missing lists, as an empty list. This ports the web's test (`1f22892`), which covers My List, custom lists and someone else's list, and fails if that check is removed. It also added this changelog.

## 2026-11-04: caught up with the website

[PR #49](https://github.com/jasanpreetn9/miruyo/pull/49), merged on 2026-11-05. It brings the app up to the website as of `23ef5b5`, one commit per web change. 342 tests pass, and CI is green.

### From the website

- **Custom lists on My List** (`313c48e`). Your custom lists appear as tabs after the statuses (`/list?list=`).
  - **Bug fix:** titles marked "hide from status lists" on AniList used to vanish from My List, Stats and For You. They're counted again, and kept off the status tabs only.
- **Requests paced to AniList's rate limit** (`1dd2af1`). A new `pacer.dart`:
  - At 5 or fewer requests left, they go out one at a time at the limit's pace.
  - A 429's Retry-After holds every request.
- **Title pages** (`d5cd10c`):
  - Tags ranked by fit, with spoiler tags hidden until asked for. Tapping a tag opens Browse.
  - Where to watch / Where to read, Links, and Also known as. Duplicate names are now caught regardless of case.
  - Opening a manga switches the app to Manga mode, and an anime back to Anime.
- **Staff and character pages** (`82b5098`), at `/staff/:id` and `/character/:id`:
  - Bios are AniList markdown shown as text. Spoilers sit behind a chip, and AniList links open in the app.
  - Staff pages list voice roles and credits, 25 at a time with Load more, sorted Popular or Newest.
  - Character pages list appearances with their voice actors, one language at a time, Japanese first.
  - Both pages have a favourite heart.
  - Characters, voice actors, manga authors and Profile's favourite people now open these pages instead of AniList.
- **Browse** (`8599e06`):
  - Exclude a genre by tapping it twice; tags have an Exclude button.
  - Ready-made lists, with `#n` ranks on ordered results.
  - A search also finds characters, staff and studios.
- **User pages** (`41ad5e8`), at `/user/:name`:
  - Follow, read-only Anime and Manga lists, Favourites and Stats.
  - Your Profile tab is now your own user page.
  - Follow notifications open these pages.
  - Totals leave out 18+ titles unless your account shows them, so the lists, Stats and the facts card always agree.
- **Home** (`7db4a04`):
  - Upcoming shows six titles, dated ones first. Long sequel titles are shortened in the middle, and an unknown format is no longer shown as "Unknown".
  - Up next has a Start button and shows the title's length ("24 eps", "1h 47m").
  - The caught-up card is now a slim strip.
- **For You rotates each day** (`b308e78`). It uses the web's hash bit for bit, so the app and the website draw the same picks on the same day. Muted titles are left out before the draw.
- **Tidy-up** (`3317c19`): removed an unused badge style and a stale comment, and updated `ROADMAP.md`.

### App only

- Home leads with Picked for you, above Trending (`0513ab3`).
- A poster's details sit right under a one-line title, with no gap (`db2d897`).
- The Profile tab starts right under the top bar instead of a bar's height lower (`1e7cca9`).
- The staff page's sort is a pair of chips (`ca2d093`). It was a segmented button whose small text failed the contrast check on CI.
- Bio links on staff and character pages are underlined in their own colour, and the excluded-genre chip is announced on its own by screen readers (`02c3fa2`).

### Checked

- In the iOS Simulator, signed out and then signed in:
  - Home and a title page
  - Browse: a tag, the ready-made lists, and a search
  - A character page and a staff page, including the staff sort
  - My List and Profile
- Installed on the iPhone and launched.
