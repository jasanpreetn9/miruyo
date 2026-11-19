# miruyo roadmap

The path to a complete v1. **Where things stand (Nov 2026):** Phases 0–8 are done, and the site is live at [miruyo.vercel.app](https://miruyo.vercel.app). Since then it has gained people's pages (`/user/[name]`, your profile included), staff and character pages, a Stats tab on title pages and custom lists; [CHANGELOG.md](CHANGELOG.md) lists every change. Left: what's [next up](#next-up), polish and launch (Phase 9), and the [known issues](#known-issues).

**Source of truth:** the design export in [`design/Kōhai design system complete/`](<../../design/Kōhai design system complete/>) (UI/UX v0.3). Open its `miruyo Index.dc.html` in a browser for the screen index. The screen files named below are in its `shared/` folder; the mobile gesture specs are in `mobile/`. Each screen file is interactive (mode toggle, +1, tabs, editor). Each phase below names the design file it implements. Where this roadmap and the design disagree, the design wins unless it's listed under [Open decisions](#open-decisions). **Design v0.2 (Oct 2026)** redrew the files to match what's built (the AniChart-style Seasonal and Schedule, Settings, the notifications panel, the compact search, Relations before Characters, and more), so for built screens the design and the app now agree. **Design v0.3 (Oct 2026)** caught up with the profile (07, favourites and Stats), For You (08), the season chart's new cards, the title page's countdown in the status column, Home's For You row and −1, and the legal links.

| #   | Design file                        | Route(s)                    | Status                                      |
| --- | ---------------------------------- | --------------------------- | ------------------------------------------- |
| 00  | `miruyo Design System.dc.html`     | —                           | Built (Phase 1)                             |
| 01  | `miruyo Home.dc.html`              | `/`                         | Built (Phase 2)                             |
| 02  | `miruyo Browse.dc.html`            | `/browse`, `/search`        | Built (Phase 3)                             |
| 03  | `miruyo Detail.dc.html`            | `/title/[id]`               | Built (Phase 4)                             |
| 04  | `miruyo List Editor.dc.html`       | panel / sheet (no route)    | Built (Phase 4)                             |
| 05  | `miruyo My List.dc.html`           | `/list`                     | Built (Phase 5)                             |
| 06  | `miruyo Seasonal.dc.html`          | `/schedule`, `/seasonal`    | Built (Phase 6), re-laid out after AniChart |
| 07  | `miruyo Stats.dc.html`             | `/user/[name]`, `/settings` | Built (Phase 7)                             |
| 08  | `miruyo For You.dc.html`           | `/for-you`                  | Built (Phase 8)                             |
| 09  | `miruyo Login.dc.html`             | `/login`, `/welcome`        | Built (Phase 2)                             |
| —   | `PosterCard` / `TopBar` / `TabBar` | shared components           | Built                                       |

## Known issues

- [ ] **Flaky e2e test:** "a rate-limited feed counts down and retries on its own" (`e2e/home.spec.ts`) fails about 1 run in 3, on `main` too — a timing race around the countdown.
- [ ] Console noise in e2e runs from queries some tests don't mock (list state: `reading 'mediaList'`; the login poster wall: `reading 'media'`); harmless, but worth mocking. For You's and the notifications test's were fixed in #46.
- [ ] **Paused count:** My List showed 7 paused while Home said 9. They come from different requests; not looked into yet.
- [ ] **Upcoming on phones:** long sequel titles can still lose their season number.
- [ ] **PageSpeed (mobile) after [#59](https://github.com/jasanpreetn9/miruyo/pull/59):** still to do from the Nov 9 report (COOP is in [#60](https://github.com/jasanpreetn9/miruyo/pull/60); HSTS was already sent, and `preload` is a call about all of jnagra.com): server-render signed-out Home so its first cover is in the HTML; self-host the fonts (Google Fonts' CSS blocks rendering for ~0.75s); covers are AniList's PNGs (up to 560 KB), which only an image resizer would shrink. Re-run PageSpeed once #59 is live.
- [ ] **Move Vercel analytics to stable releases.** `@vercel/analytics` and `@vercel/speed-insights` are pinned to pre-releases (`2.1.0-canary.5`, `2.1.0-canary`), the first to declare SvelteKit 3 support; the stable 2.0.x releases only list SvelteKit 1–2. When a stable release lists `^3` (check with `npm view @vercel/analytics peerDependencies`), switch both to it. Keep using the plain `inject()` / `injectSpeedInsights()`: even these pre-releases' `/sveltekit` entry points use `$app/stores`, which throws in SvelteKit 3 and took production down (Nov 2, 2026); `src/lib/analytics.test.ts` fails if either comes back.

## Next up

**Features**

1. ~~**Search for users**~~ → done (Nov 2026, [#54](https://github.com/jasanpreetn9/miruyo/pull/54)): a Browse search shows the users it matches in a Users row after Staff, each opening their page.
2. ~~**A studio page**~~ → done (Nov 2026, [#56](https://github.com/jasanpreetn9/miruyo/pull/56)): `/studio/[id]` lists a studio's titles, popular or newest first, and every studio link opens it.
3. ~~**For You**~~ → done (Nov 2026, [#61](https://github.com/jasanpreetn9/miruyo/pull/61)): favourite studios weigh more ("From MADHOUSE"), the other list suggests its manga or anime ("The manga of Frieren, which you rated 9/10"), and "Tune picks" leaves out what you don't want. The "Because you loved…" rows on Home were already built.
4. ~~**Custom lists from the editor**~~ → done (Nov 2026, [#62](https://github.com/jasanpreetn9/miruyo/pull/62)): the editor shows every custom list (empty ones too) as a chip, and saves the set with the rest.
5. ~~**People's list tabs**~~ → done (Nov 2026, [#65](https://github.com/jasanpreetn9/miruyo/pull/65)): someone's anime or manga list filters by AniList's Genre, Country and Year, kept in the address.
6. **Title Stats:** ranking history over time (the tab shows today's rankings).

**Launch work**

- Fix the flaky e2e test (see [Known issues](#known-issues)).
- ~~Favicon PNG fallback, `apple-touch-icon` and a web manifest~~ → done ([#57](https://github.com/jasanpreetn9/miruyo/pull/57)).
- An accessibility audit (Phase 9).
- Confirm AniList's redirect address for miruyo.vercel.app, then tick Deploy.
- Check notifications against the live API.

**Outside the code**

- **Cloudflare:** switch miruyo.vercel.app to DNS only, or turn off Cloudflare's Web Analytics. Its injected beacon is blocked by the CSP (harmless, but it adds a hop and console errors).

---

The phases are in dependency order. Each one ends with something you can ship.

**Rough timeline:** about 5–6 focused weeks (the designs add scope over the first draft of this plan, mainly the list editor, the calendar, the Stats charts and For You). Phases 1 → 3 → 4 are the critical path. Phases 5–7 can be done in any order once Phase 4's list editor exists, and Phase 8 needs Phase 4's detail data.

---

## Phase 0 — Lock in the current work (½ day)

- [x] Commit the component reorganisation, the bug fixes and this roadmap. The extracted `design/` files are committed; the original `.zip` is git-ignored.
- [x] Add CI (GitHub Actions) running `npm run check`, `npm run lint`, `npm run test:unit` and `npm run test:e2e` on every push and pull request (`.github/workflows/web.yml`). Since Nov 2, 2026 the e2e job also builds for production (Node 24, as Vercel does) and runs a smoke test against it (`npm run test:prod`, `e2e-prod/`): every main page must start, also after a client-side navigation, with no uncaught error. Production-only code took the site down that day, and the dev-server suite never runs it.
- [x] Add Vitest unit tests (`npm run test:unit`) for the pure logic: `anilist/adapt`, `anilist/humanize`, `catalog/dress`, `page-data/home`, `page-data/browse`.
- [x] Add `src/routes/+error.svelte` so unknown routes (currently the dead nav links) get a proper error page.

## Phase 1 — Data layer and design-system foundations (2–3 days) ✅

Everything after this phase depends on it.

**Data**

- [x] **Title language:** signed in, titles use AniList's `userPreferred` (the account's own title-language setting); signed out, English (falling back to romaji). miruyo has no title-language setting of its own.
- [x] **Request caching:** add a small cache keyed by query and variables, and merge identical requests that are in flight at the same time. AniList limits clients to ~90 requests a minute (sometimes cut to 30).
- [x] **Error handling:** treat 429 and 401 separately. 429 → automatic retry with a visible countdown (Home 1e: "we'll try again automatically in 0:12"). 401 → sign out and explain why.
- [x] **List editing:** generalise `saveProgress` into `saveEntry({ status, progress, progressVolumes, score, startedAt, completedAt, repeat, notes, private })` plus `deleteEntry`. Scores follow the viewer's `mediaListOptions.scoreFormat` (10-point with half points shown in the design).
- [x] **Shared list state:** keep list entries in one reactive store keyed by media id, so a change made anywhere updates every card.

**Design system (00)**

- [x] Status verbs per mode across the app: Watching → Reading, Rewatching → Rereading (currently only Watching is relabelled).
- [x] Focus is always a 2px light ring with 2px offset; every touch target is ≥44px.
- [x] Motion tokens: enter `cubic-bezier(.2,.8,.2,1)`, exit `cubic-bezier(.4,0,1,1)`. Under `prefers-reduced-motion`, lifts and shimmer become opacity fades.
- [x] **Countdown chip:** blue at rest; turns the accent colour with a live dot within 24h; reads "Airing now" for 30 min after release.
- [x] **Progress control:** +1 is the biggest target, on the right. Reaching the total completes the title with an Undo toast (decision 2). Unknown totals show an open-ended bar.
- [x] **Status dropdown menu**, with an "Open full editor" entry (used by PosterCard and Detail). The entry appears once a caller passes `onOpenEditor`, i.e. when the Phase 4 editor exists.
- [x] **Adult content:** 18+ covers are blurred with "18+ · Hidden · Reveal" when the setting is off.
- [x] **PosterCard:** long-press on touch reveals the same overlay as hover; badges sit on a dark blur chip; a missing cover shows the `image_not_supported` placeholder.

## Phase 2 — Bring Home and Login up to the design (2 days)

**Home (01)**

- [x] **Scoped errors:** a failed section shows its own error (with the rate-limit countdown) while cached rows stay usable. Home now loads in two independent requests (`HomeList`: Continue + hero; `HomeFeed`: the rows), each a `Resource` with its own retry.
- [x] **Hero:** the banner bleeds edge-to-edge and fades left and down. A missing banner falls back to the cover, blurred and enlarged. Add the "info" action linking to Detail (`/title/[id]`, built in Phase 4).
- [x] "See all →" links on the rows (Continue → My List, Trending → Browse sorted by trending, Popular → Seasonal). "Plan" quick action on Upcoming cards.
- [x] **Signed out:** the same public rows (Trending now, Popular this season, Upcoming) sit under the sign-in hero, in English titles; list actions go to login.
- [x] **Empty list (1d):** "Tap anything you've seen" quick-pick grid that saves the picks, plus "import from AniList" and "skip".

**Login & onboarding (09)**

- [x] **First-run setup (9c)** at `/welcome`: after OAuth, show "Connected as {name}. Imported N anime and M manga," then default mode, title language and adult content → Continue. Title language and adult content are saved to the AniList account (`UpdateUser`), since miruyo follows the account's settings. The design's third mode option, "Both", is left out: the app has no combined mode. Shown once per device, tracked by `ONBOARDED_STORAGE_KEY`.

**TopBar**

- [x] ⌘K / Ctrl+K opens search from anywhere (goes to Browse with the search box focused). The top bar's search pill and the mobile Search tab (`/search`) do the same.

## Phase 3 — Live Search & browse (02) (3–4 days)

- [x] **Live data:** replace the mock `anime`/`manga` arrays with AniList's `Page.media` query.
- [x] **Desktop filter rail:** genres, **tags** (searchable, 400+), format, status, **score range** (e.g. 7.0–10), "Hide titles on my list". Anime adds **Season / Year**; manga swaps in **Country of origin** (JP / KR / CN) and **Publishing status**. Genre and tag lists come from `GenreCollection` and `MediaTagCollection`.
- [x] **Live results** on desktop with a 300ms debounce and no Apply button. The mobile sheet keeps "Show N results", because each change would otherwise reflow under your thumb.
- [x] **Chips mirror state:** every active filter (not only genres, as today) appears as a removable chip with a count. The rail and the chips share one state.
- [x] **Sort:** popularity, score, trending, newest, both in the desktop dropdown and the mobile sheet.
- [x] **Scrolling:** infinite scroll or "load more". Add a loading state (2e).
- [x] **No results (2d):** "Did you mean {title}?" suggestion, a count of active filters, Clear filters and Search "{suggestion}".
- [x] **URL state:** filters, search text, sort and view live in the URL.
- [x] **`/search`:** the mobile Search tab opens Browse with the search box focused. The design treats them as one screen ("Search & browse").
- [x] **Logged-out pages:** the login poster wall uses public trending data. Then delete the mock catalog in `src/lib/catalog/titles.ts`.

**Notes from building it**

- All Browse state lives in the URL (`src/lib/browse/params.ts`): `?q=…&genre=…&tag=…&format=…&status=…&season=…&year=…&country=…&min=…&max=…&hide=1&sort=…&view=list`. Defaults are left out; values from the other mode are dropped (switching mode tidies the URL).
- The design lists Manhwa / Manhua as manga _formats_; on AniList they're manga from Korea / China, so they're under Country of origin, and manga formats are AniList's (Manga, Light novel, One-shot).
- Filter toggles apply immediately; only typing in the search box is debounced (300 ms).
- "Did you mean" suggests the top result of the same search without the filters (AniList has no spelling suggestions), so it shows when filters are on.
- The design shows a count next to each format; that would cost one request per format, so it's left out.

## Phase 4 — Title detail (03) and List editor (04) (4–5 days)

**Detail — `/title/[id]`**

- [x] **Cover colour owns the page:** banner, cover glow, progress fill and the countdown accent all derive from it. Missing banner → fallback (shown in the manga example).
- [x] **Sticky status column under the cover:** list button, progress stepper, score and favourite, so updating never needs a scroll past the synopsis.
- [x] **Anime:** next-episode countdown with local day and time, trailer and studios. "Remind me" waits on decision 3.
- [x] **Manga:** chapters (or "ongoing"), volumes, authors with roles. AniList has no release cadence or publisher, so those are left out.
- [x] Rank badges (e.g. "Highest rated all time"), members, tabs, characters ("All →"), relations, "If you like this".
- [x] **Mobile (3b):** back button, share (`ios_share`), countdown strip, Edit button.
- [x] Link every poster in the app to this page.
- [x] **Oct 2026, from comparing with AniList:** tags ranked by fit, spoiler tags hidden until asked for, 18+ tags only when the account shows adult content, each opening Browse filtered by it; "Where to watch" / "Where to read" from AniList's streaming links (above the tabs, the first six then "N more"); the official site and socials, and the other names ("Also known as") at the end of Overview. Alternative titles show on phones too. Links that aren't http(s) and colours that aren't plain hex are dropped.
- [x] **Stats tab (Nov 2026):** after Characters & Staff, loaded when it opens: AniList's rankings for the title (all time, the year, the season; each opens the same list in Browse, except a manga's yearly one, as Browse has no year for manga), how many people have it on each list, and the score distribution with the average, in the cover's colour.
- [x] **Staff and character pages (Nov 2026):** `/staff/[id]` and `/character/[id]`, server-rendered like the title page, with their own share cards (`Person` JSON-LD for staff). A voice actor's roles (most popular or newest first, `?sort=newest`; changing it reloads only the roles), credits folded per title ("Original Creator · Story & Art"), and a character's titles with their voice actors in any language (Japanese first). 25 roles a page with Load more (AniList's limit). Bios come from AniList's markdown through `page-data/markdown.ts`, which makes text segments, never HTML: spoilers hide behind a chip, AniList links open in miruyo, and the leading "**Height:** 157 cm" lines become facts. Favouriting works for both. The title page's characters, voice actors and manga authors, and the profile's favourite people, link here instead of AniList.

**List editor (no route)**

- [x] **Side panel on desktop, bottom sheet on mobile:** the page stays visible behind it. Esc or swipe-down closes it; unsaved edits ask once.
- [x] **Field order:** status → progress → score above the fold. Dates, rewatches/rereads, notes and "Private entry" sit below (collapsed into rows on mobile).
- [x] **Manga:** chapters plus volumes; "93 out · ongoing" when the total is unknown.
- [x] **Smart defaults:** setting Watching fills Start date with today. Reaching the last episode offers "Mark as completed?" and fills Finish date.
- [x] Delete entry, and "Saved to AniList ✓" confirmation.
- [x] **Entry points:** the status menu's "Open full editor" on every poster card, Detail (status button; Edit on mobile) and the Home hero's Edit button. My List rows come with Phase 5.
- [x] **Saving behaviour:** every change shows immediately and rolls back if the save fails.

**Notes from building it**

- Every query was checked against the live AniList API before use (Browse taught that lesson). `Media(id)` accepts `mediaListEntry`; AniList has no rating count, so the score block reads "Average score".
- The trailer is a "Trailer" button in the stats row (opens YouTube/Dailymotion in a new tab), not a large card.
- The character preview shows as many as fit in one row; the Characters & Staff tab has all of them with Japanese voice actors.
- The editor saves a draft (only changed fields are sent). If the full entry finishes loading after you've started typing, your edits are kept.

## Phase 5 — My List (05) (2–3 days)

- [x] Use AniList's `MediaListCollection` query, with status tabs and their counts.
- [x] **Table by default, grid optional.** The view choice is remembered, one choice for every tab.
- [x] Filter text, Sort (last updated, title, score, progress, next episode), Format filter, "Share list" (links to the AniList list for now; a miruyo page is decision 4).
- [x] **Edit in place:** +1 at the end of every progress bar; click a score to nudge it with a stepper. A row that reaches its total moves to Completed with an Undo toast (decision 2).
- [x] **Airing context:** Watching rows show "2 behind" or the next-episode countdown.
- [x] Empty tab state ("Browse seasonal"), mobile layout (5b), loading state (5c), and efficient rendering for long lists.

**Notes from building it**

- One `MediaListCollection` request per mode, with a lighter media fragment than Home; custom lists are skipped so each title appears once. Tabs group by each entry's own status (AniList can split Completed by format).
- Local edits show at once: a row that's completed slides to the Completed tab, a removed one disappears. +1 on a Planning row starts it (moves it to Watching).
- The tab is in the URL (`?tab=completed`); table/grid is remembered (one choice for every tab). Rows render 100 at a time.
- Every list change now confirms with a toast and Undo, app-wide: added, moved, completed, removed (and "Added N titles" from the quick-pick).

## Phase 6 — Schedule and Seasonal (06) ✅

**Anime: the week's schedule — `/schedule`** (was `/seasonal`)

- [x] **Seven columns,** cards stacked by local air time, built from AniList's `AiringSchedule` data.
- [x] **Today** is lifted, with a "NOW 18:20" line; earlier slots fade and show a check.
- [x] Season picker (chevrons, Winter / Spring / Summer / Fall), "Fall 2026 · week of Oct 5", and a timezone label ("Times in CEST (UTC+2)").
- [x] **Your shows glow:** titles on your list get a cover-colour ring, your progress, and a one-tap +1 once the episode is out. A "My list only" toggle collapses the week to just those.
- [x] **Mobile (6b):** a day strip where you tap a day.

**Manga: New releases**

- [x] ~~A feed of chapters grouped by day~~ — AniList has no chapter release data, so New releases follows **series**: yours that are still releasing (with +1), then popular series that started serializing in the last six months (Plan from the card).
- [x] Summary: "N series you're reading are still releasing."
- [ ] "Notify me about: series I'm reading / Planning list" — waits on decision 3.

**Notes from building it**

- `AiringSchedule` for the week (paged, ~110–150 airings), in the viewer's local timezone. 18+ titles are hidden unless the account allows them. List state comes from `loadListState`, as with Browse.
- The week is in the URL (`?week=2026-10-05`); chevrons move a week; the season buttons jump to the first week of that season within the shown season's year (AniList's seasons: Winter = Dec–Feb of the new year).
- Countdowns refresh every 30 seconds.
- **Layout changed (Oct 2026) to AniChart's:** instead of seven columns (and a day strip on mobile), the week is a section per day — today first, then the rest of the week, with days already past at the end under "Earlier this week" — each a grid of horizontal cards ("Ep 9 airing at 23:00 · in 4h 40m"), 1 to 4 columns by width. The week's next episode carries an "Airing next" badge in place of the NOW line; days with nothing airing are left out.

**Anime: the season chart — `/seasonal`** (added Oct 2026, after AniChart)

- [x] Everything premiering in a season, in AniChart's sections: TV, TV Short, **Leftovers** (still airing from earlier seasons), Movie, OVA / ONA / Special.
- [x] Cards: cover with title and studio; "Ep 2 of 12 airing in · 18 hours, 31 mins" (or premiere / release date); "Sequel to …" or "Source • Light Novel"; synopsis; genres; AniList score with a face (green ≥75, amber ≥60, red below) and this season's popularity rank.
- [x] The card's + is the status menu ("Open full editor" included); signed out it leads to log in.
- [x] Filter and sort (popularity, score, airing soonest, title). The season is in the URL (`?season=winter&year=2027`; the current season needs none).
- [x] A shared season header on both views: the season before, the shown one and the two after (‹ › move further), then **Airing** for the schedule.

**Notes from building the season chart**

- One request per 50 titles (a season is ~100, so 2) plus the leftovers. AniList has no "leftovers" filter: they come from the airings in the season's second week (after last season's finales), keeping shows that started before the season — ~3 more requests, all cached.
- `pageInfo.total` is unreliable (it reads 5000), so paging follows `hasNextPage`.
- The rank is AniList's own seasonal POPULAR ranking; leftovers carry their own season's rank, so they show none.
- **Navigation (decided Oct 2026):** one nav item, two views, like AniChart. The top bar's "Seasonal" opens the chart; on phones the tab bar's Search slot became Seasonal (search stays in Browse and ⌘K). In manga mode the item is "New releases" (`/schedule`); arriving at the chart in manga mode switches to anime.
- Old `/seasonal?week=…` links forward to `/schedule?week=…`.

## Phase 7 — Stats (07) and Settings ✅

**Stats — now part of your profile (`/user/<you>`)** ✅

- [x] Anime / Manga tabs swap the units (episodes → chapters, days watched → volumes) and the accent colour. Time-range picker: All time, this year, last 12 months.
- [x] **Charts:** score distribution (mean and σ), format, by status, top genres (count · mean score), titles finished per month over the last 12 months, and a daily activity heatmap for the last 26 weeks.
- [x] **Chart rules:** one accent per chart, neutral greys for the rest, and status colours only where status is the data. Every bar is labelled. Gridlines are 6% white; values are Geist Mono. Hover lifts the bar and shows an exact tooltip.
- [x] Mobile layout (7b). The mobile Profile tab opens Stats (decision 1).
- [x] **Profile (Oct 2026):** Stats grew into a profile at `/profile` (the nav item is Profile; `/stats` forwards): the AniList banner and avatar, name and "Member since", then favourites (anime or manga by mode, characters, staff, studios), then Stats. _Since Nov 2026 the profile is your user page, bio included (see below)._

**Notes from building it**

- Stats are computed from the same `MediaListCollection` request as My List (and share its cache), not `User.statistics`: checked against the live API, its breakdowns (formats, statuses, genres, scores) are often stale or empty — one account had 471 anime but 2 in its format counts. Computing from the list also makes time ranges possible.
- A time range keeps titles you started or finished in it (undated entries go by their last update). Their episodes count in full, since AniList doesn't timestamp progress.
- Scores are shown on the 10-point axis whatever the account's score format, so the mean matches the chart. "AniList mean" on the score card is the site average of the titles you scored.
- The design's "episodes per month" needs per-episode history, which would mean paging through every list activity (the rate limit is 30/min). The monthly chart shows **titles finished** per month instead (`completedAt`).
- The heatmap uses `User.stats.activityHistory`: about six months of list updates, anime and manga together (AniList doesn't split them), levelled by quartile so one import day doesn't flatten the rest.
- The staged `User.statistics` types in `anilist/types.ts` were removed, since nothing uses them now.

**People's pages — `/user/[name]`** ✅ (Nov 2026)

- [x] Laid out like the title, staff and character pages (`PersonLayout`): the avatar, Follow (Settings on yours) and Share, and a facts card on the left (Member since, then the Stats cards' numbers for the mode); the name, "Follows you", the bio and the tabs on the right.
- [x] **Overview:** favourite titles (following Anime / Manga), characters, staff and studios, then Stats. **Anime list** and **Manga list** (someone else's only): My List's toolbar (statuses, filter, format, sort, rows or covers), all in the URL. The tabs share one load of the profile (`state/user-page.svelte.ts`); lists load when a tab needs them.
- [x] **Your profile is your user page:** the nav's Profile opens `/user/<you>`; `/profile` and `/stats` forward there. Yours has no list tabs, since My List is your list, and your list addresses open it.
- [x] Their lists are fetched without a token (as anyone sees them, private entries left out) with scores out of 10, so their scores and stats read the same whoever's looking. 18+ titles count only when the viewer's account shows them (`forViewer`), so the totals match the list. A private list says so; an unknown name is a 404. Server-rendered for link previews, never indexed.

**Settings — `/settings`** ✅ (built in the existing style; decision 5)

- [x] **Display:** title language (keeping the account's "stylised" choice) and adult content — the same as first-run setup.
- [x] **Scoring:** score format (100 / 10 with decimals / 10 / 5 stars / 3 smileys).
- [x] **Notifications:** AniList's airing notifications on/off.
- [x] **Account:** signed in as, sign out (this browser), "Revoke access" and "More settings on AniList" links.
- [x] Entry points: the avatar menu on desktop; on mobile, the profile header (the Profile tab) has a settings button.

**Notes from building it**

- Everything is saved to the AniList account (`UpdateUser`) as soon as it changes, and rolls back if AniList refuses. Nothing is kept locally; mode stays in the top bar, where it's already remembered.
- Changing the score format loses nothing: AniList stores scores on one scale and converts on read (`MediaList.score(format:)`). miruyo drops its in-memory entries so pages reload scores in the new format.
- Left out on purpose: staff-name language, individual notification types, timezone, list layout and social settings — "More settings on AniList" covers them. The API can't revoke a token, so "Revoke access" links to AniList's apps page.

**Notifications** (TopBar bell)

- [x] The bell shows `unreadNotificationCount`, with a read-only list of AniList notifications.

**Notes from building it**

- The design only draws the bell and its dot, so the list is a dropdown in the avatar menu's style (desktop), and a panel under the header on phones, where the bell sits next to the mode toggle.
- Opening the list fetches the latest 25 and marks them read on AniList (`resetNotificationCount`), as AniList's own page does; the ones that were unread keep a dot. The count refreshes every 5 minutes, and when the tab comes back into view.
- Airing, related-title, data-change and merge notifications open the title in miruyo; activity, forum and follows open on AniList. Submission updates are left out. "All on AniList" links to the full page.
- **Not yet checked against the live API** (AniList was unreachable from the build environment): the query follows AniList's published schema; confirm it once signed in.

## Phase 8 — For You (08) (3 days)

- [x] **Picks with reasons:** candidates come from AniList's recommendations for your highest-rated titles (7.5/10 and up, the top 8). Each scores by the seed's rating × AniList's votes, summed across seeds, with a nudge for your favourite genres and 15% more from a favourite studio (two titles rated 7.5+; "From MADHOUSE", [#61](https://github.com/jasanpreetn9/miruyo/pull/61)). Titles already on your list are left out. Every pick says "Because you rated X 9/10".
- [x] **Seed rail:** the titles driving your picks; tap one to filter to "because of X". Since [#61](https://github.com/jasanpreetn9/miruyo/pull/61) it also holds the day's top four titles from your other list (marked "· anime" / "· manga"), whose source manga or novel, or two most popular anime, join the picks; a list with too few ratings shows those instead of the cold start.
- [x] **Say "not this":** dismissed picks don't come back (stored locally), with Undo. **Tune picks** ([#61](https://github.com/jasanpreetn9/miruyo/pull/61)): only titles that are out, the other mode's picks on or off, and genres to leave out, kept on the device and applied on Home too. _Still to do: the "Refreshed this morning" timestamp._
- [x] **Cold start (8c):** when logged out or with fewer than 5 ratings, show "Picks get good after 5 ratings" with "Log in with AniList" or "Rate a few titles instead."
- [x] Mobile layout (8b). Entry point: a Home row with "See all" (decision 6).
- **Not yet checked against the live API:** the query asks for each seed's recommendations in one request (the shape the title page already uses); the page shows AniList's error if it fails.

## Phase 9 — Polish and launch (2–3 days)

- [x] **Tablet widths:** the desktop layout starts at 1024px (it was 768, where the top bar overflowed and 1440 layouts were crushed). iPads in portrait get the touch layout and tab bar, with more columns; 1024–1279 gets half the side padding and a compact top bar.

- [ ] **Accessibility:** run an audit against the design-system rules (AA contrast on every surface up to S3, focus rings, ≥44px targets, status never shown by colour alone). Keyboard equivalents for hover overlays; focus kept inside the sheet and panel.
- [x] **Performance:** the icon font loads only the icons the app uses (`icon_names` in `app.html`: ~50 KB instead of 3.1 MB; `src/lib/icons.test.ts` fails if one is missing), and icons stay hidden until it arrives. Covers are lazy `<img>`s (`CoverImage`) over the title's colour, fading in once loaded, inside fixed 2:3 frames so nothing shifts; cards use `extraLarge`, list thumbnails `large`. The hero and the title page cover load eagerly.
- [ ] **Metadata:** page titles, OG tags on Detail, and a favicon and manifest (optionally an installable PWA).
  - [x] Search and share tags (`src/lib/seo.ts`, written by the root layout): a description, canonical URL and Open Graph / Twitter card on every page, with `static/og.png` as the default card. Personal pages (My List, Profile, Settings…), error pages and 18+ titles are `noindex`. `sitemap.xml` lists the public pages and `robots.txt` points to it.
  - [x] Title pages carry their own name, synopsis, banner as the card, and JSON-LD (`TVSeries` / `Movie` / `Book`) — see decision 7.
  - [x] Favicon PNG fallback, `apple-touch-icon` and a web manifest ([#57](https://github.com/jasanpreetn9/miruyo/pull/57)): `favicon.ico` (16–48px), a 180px `apple-touch-icon`, and `manifest.webmanifest` with 192 and 512px icons (maskable), all from the app's 1024px icon. `display` is `browser`, so the site isn't an installable app yet.
- [ ] **Deploy:** production is live on Vercel at miruyo.vercel.app, with Web Analytics and Speed Insights. Still to confirm: the AniList client's redirect URL is registered for that domain.
- [ ] **Finish:** e2e coverage for every route and design state, then update the README.

---

## Open decisions

**Resolved by the design**

- ~~Search vs Browse~~ → one screen ("Search & browse", 02); the Search tab and ⌘K focus its search box.
- ~~Seasonal in the nav?~~ → yes. The TopBar design has Home / Browse / Seasonal ("New releases" for manga) / My List / Stats, matching today's Navbar.
- ~~Notifications in v1?~~ → yes. The bell is in the TopBar, and Detail and Seasonal have reminder controls (but see 3).

**Still open**

1. ~~**Stats vs Profile**~~ → **decided by the Stats design (7b)**, which shows the TabBar with Profile active: the mobile Profile tab opens the profile (your user page since Nov 2026, with Stats in its Overview). Its Settings button holds sign-out (see 5).
2. ~~**Completing at the total**~~ → **decided (Oct 2026): auto-complete everywhere.** Any +1 that reaches the total moves the title to Completed with an Undo toast — My List, Home, poster cards, the hero, the title page. In the editor the draft switches to Completed with an inline Undo. (The design system's "never auto-completes" is superseded.)
3. **Reminders:** AniList's API only offers its own airing notifications for titles on your list. "Remind me" (Detail) and "Notify me about" (Seasonal) would need browser push plus a server or scheduled job, or they could just toggle AniList's notification setting. Which? _(Settings now has the AniList airing-notifications toggle, which would make the second option a small step.)_
4. ~~**Share list**~~ → **decided (Nov 2026): a miruyo page.** People have pages at `/user/[name]` — Overview, Anime list and Manga list, each its own address — and "Share list" opens your page, whose Share button has the link. See Phase 7.
5. ~~**Settings page**~~ → **decided (Oct 2026): built in the existing style**, with only the settings that change what miruyo shows. See Phase 7.
6. ~~**For You entry point**~~ → **decided (Oct 2026): a Home row** (signed in, above the feed rows) with "See all" opening `/for-you`. No nav item.
7. ~~**Server-side rendering**~~ → **decided (Oct 2026): yes, for the first load of Detail, Seasonal and Schedule.** Each has a `+page.server.ts` that fetches the signed-out data (`src/lib/server/public-load.ts`); the page shows it until the browser's own copy (the viewer's titles, list state, 18+) arrives, which loads as before. Client-side navigation skips the server fetch, so a click never waits on it. The pages are the same for everyone, so the CDN caches them (`s-maxage=600, stale-while-revalidate=86400`) and crawlers don't spend AniList's rate limit; the CSP moved from nonces to hashes for that reason. If AniList fails, the page renders as before and isn't cached; a title AniList doesn't know is a real 404. `SSR_ANILIST=off` turns the server fetch off (e2e does, since its mocks reach the browser only). The schedule's server week is UTC, so its days can shift for a moment until the viewer's own week loads.
