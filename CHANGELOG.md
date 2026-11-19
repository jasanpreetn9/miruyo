# miruyo changelog

What changed on the website, newest first. Dates are when each pull request merged and went live. What's planned next is in [ROADMAP.md](ROADMAP.md#next-up); the iPhone app has its own [roadmap](../mobile/ROADMAP.md).

## Nov 19, 2026

**Changed**

- **An editorial redesign.** The site drops the generic dark-dashboard look for one drawn from anime and manga print (mockups in [`design/mockups`](../../design/mockups)): a warm off-black page and cream ink, one vermilion accent for anime (manga keeps its violet), Fraunces for headings, Schibsted Grotesk for text and JetBrains Mono for numbers, square corners, ruled sections instead of cards, underlined fields and text tabs instead of pills. Each title's cover colour tints its page (offset shadows behind covers, the score, progress). Home opens with a masthead and Continue, led by the title you're furthest behind on; the title page gets a duotone banner, a timeline of relations and credits for its cast; Seasonal gets the season's kanji and ranked entries. Motion is quick and quiet: mastheads rise in, section rules draw, +1 counters tick, chart bars grow, and under reduced motion only fades remain.
- **For You measures your taste against your own scores.** What counts as a title you loved follows how you rate: half a deviation above your average, between 7 and 9, so a harsh rater's 7s seed picks and a generous rater's 8.5s don't (lists under 10 scores keep 7.5). Genres weigh a pick by how far you rate them above your usual, not by how often they're on your list, and a genre you rate below it weighs a pick down. Recommendations AniList's users voted to nothing are left out, and each title you loved brings 20 recommendations instead of 8, so more picks are backed by several of them.

## Nov 17, 2026

**Changed**

- **Your list shows at once, and refreshes behind the page** ([#66](https://github.com/jasanpreetn9/miruyo/pull/66)). My List, For You, Stats and Schedule used to load your whole list again once their copy was a minute old, or after any edit, behind a skeleton: 0.6s for 300 titles, about 5s for 8,000. They now show the copy they have straight away and swap in AniList's newer one when it lands, keeping your edits meanwhile. Someone else's list does the same.
- **For You loads your anime and manga lists at the same time** ([#66](https://github.com/jasanpreetn9/miruyo/pull/66)), instead of one after the other.
- **Row thumbnails load a smaller cover** ([#66](https://github.com/jasanpreetn9/miruyo/pull/66)). Rows in My List, someone's list and Continue load AniList's 100px cover (about 15KB) instead of the 230px one (about 62KB), and the larger one only on 3x screens.

## Nov 11, 2026

**Added**

- **Filter someone's list by genre, country and year** ([#65](https://github.com/jasanpreetn9/miruyo/pull/65)). A user page's Anime and Manga lists gain AniList's Genre, Country and Year filters beside Format and Sort, each offering what's on the list ("South Korea", "2019"). A manga's year is its start date's. They stay in the address (`?genre=Drama&year=2019`), so a filtered list can be shared.

## Nov 9, 2026

**Added**

- **Put a title on your custom lists from the editor** ([#62](https://github.com/jasanpreetn9/miruyo/pull/62)). The list editor shows every custom list you have for anime or manga, empty ones too, as a chip; tap to put the title on a list or take it off, and Save sends the change to AniList with the rest. My List's custom tabs follow.
- **For You picks from your other list, and Tune picks** ([#61](https://github.com/jasanpreetn9/miruyo/pull/61)). An anime you loved now suggests its source manga, and a manga its anime ("The manga of Frieren, which you rated 9/10"); with too few manga ratings for picks of their own, Manga mode shows those instead of asking you to rate more. Studios behind two titles you rated highly count as favourites: their picks rank higher and say "From MADHOUSE". "Tune picks" leaves out what you don't want (titles not out yet, the other list's picks, genres), on this device, on For You and Home.

**Changed**

- **Pages isolate themselves from cross-origin openers** ([#60](https://github.com/jasanpreetn9/miruyo/pull/60)). Every page sends a Cross-Origin-Opener-Policy, so a page another site opens can't reach back into miruyo. PageSpeed's Best Practices asked for it.
- **Home loads faster on phones** ([#59](https://github.com/jasanpreetn9/miruyo/pull/59)), from PageSpeed's mobile report (performance 61). Signed out, the Trending row's first covers load right away, the first ahead of everything, and AniList's API and image servers are connected to early. The footer no longer jumps down as Home's rows arrive (all of the report's layout shift), and every page has one main landmark for screen readers.

**Added**

- **Icons for home screens, link previews and crawlers** ([#57](https://github.com/jasanpreetn9/miruyo/pull/57)). The site had only an SVG favicon, so adding it to an iPhone home screen, Safari and many link previews showed a blank or generic icon, and `/favicon.ico` was missing. It now has a `favicon.ico`, an `apple-touch-icon` and a web manifest, all from the app's icon.
- **A studio page** ([#56](https://github.com/jasanpreetn9/miruyo/pull/56)). Studios used to send you to AniList; `/studio/[id]` now shows a studio's name and kind, Add to favourites, Share and its AniList link, then its titles, most popular or newest first, 25 at a time with Load more. Titles it only helped on are marked "Producer". Studios in a search, your favourite studios and the title page's Studio fact all open it.

## Nov 8, 2026

**Changed**

- **Up next only offers titles that are out** ([#55](https://github.com/jasanpreetn9/miruyo/pull/55)). Home's Up next took the first four Planning titles whatever their status, so seasons not out yet sat there with a Start button. It now skips those (they're on the Upcoming row) and still fills four.

**Added**

- **A search also finds AniList users** ([#54](https://github.com/jasanpreetn9/miruyo/pull/54)). Everyone on AniList has a page here, so a Browse search now shows the users whose names match, in a Users row after Staff: round avatars and names, each opening their page. They show in Manga mode too, since anyone's list holds both. It's part of the same request as the characters, staff and studios.

## Nov 7, 2026

**Changed**

- **A title page's tags fold to the best-fitting eight** ([#53](https://github.com/jasanpreetn9/miruyo/pull/53)). A title can carry thirty tags, which took up several rows of a phone before anything else on the Overview. The first eight show, then an "N more" chip opens the rest and becomes "Show fewer". Showing spoilers opens them all, so a low-ranked spoiler isn't left folded away.

## Nov 4, 2026

**Fixed**

- **The season chart only opens years it can show** ([#48](https://github.com/jasanpreetn9/miruyo/pull/48)). `/seasonal` took any year after 1900 from the address. Past 2038 the week it asks AniList about doesn't fit in a 32-bit timestamp, so AniList refused it and the page rendered without data: a request for Winter 2367 did this in production. The chart now takes years from 1940 to two years ahead; anything else opens the current season. The season tabs and arrows stop at both ends.

## Nov 3, 2026

**Added**

- **A Stats tab on title pages** ([#45](https://github.com/jasanpreetn9/miruyo/pull/45)), after Characters & Staff, from AniList's counts across every user:
  - **Rankings:** all time first, then the year, then the season ("#1 Highest rated · Fall 2023 · TV"). Each opens the same list in Browse.
  - **On lists:** how many people have it, in one bar coloured by status, with each list's count and share.
  - **Score distribution:** the average and how many scored it, over a 1–10 chart in the cover's colour.

**Changed**

- **A search shows titles first** ([#47](https://github.com/jasanpreetn9/miruyo/pull/47)). The characters, staff and studios a search finds now come after the first two rows of titles (ten on desktop, four on a phone) instead of above them, and the rest of the titles carry on below.

**Fixed**

- **A title page's open tab is never cut off on a phone** ([#45](https://github.com/jasanpreetn9/miruyo/pull/45)): the tab bar scrolls it fully into view.
- **A profile's totals match its list** ([#44](https://github.com/jasanpreetn9/miruyo/pull/44)): Stats and the facts card counted 18+ titles the list tab hides.
- **A missing list reads as empty instead of crashing** ([#46](https://github.com/jasanpreetn9/miruyo/pull/46)), for your list, your custom lists and other people's. Two e2e tests that had been hitting this now mock what they open.

## Nov 2, 2026

**Added**

- **Other people's pages, and your profile is your user page** ([#43](https://github.com/jasanpreetn9/miruyo/pull/43)). `/user/[name]` is laid out like the title, staff and character pages: the avatar, Follow (or Settings on yours) and Share, and a facts card on the left; the name, bio and tabs on the right.
  - **Overview:** favourite titles, characters, staff and studios, then Stats.
  - **Anime list** and **Manga list** on someone else's page, with My List's toolbar (statuses, filter, format, sort, rows or covers), all in the URL. Theirs are fetched as anyone sees them, scores out of 10.
  - **Your own page** has no list tabs, since My List is your list. The nav's Profile opens it, and `/profile` and `/stats` forward there.
  - Follow notifications, My List's Share list and favourites lead here.
- **Custom lists on My List** ([#38](https://github.com/jasanpreetn9/miruyo/pull/38)): your AniList custom lists are tabs after the statuses (`?list=`), each row saying its status. Titles set to "hide from status lists" on AniList were missing from My List, Stats and For You; they're counted now.
- **Vercel Web Analytics and Speed Insights** ([#41](https://github.com/jasanpreetn9/miruyo/pull/41)), on SvelteKit 3's own navigation events.
- **Browse can exclude genres and tags** ([#34](https://github.com/jasanpreetn9/miruyo/pull/34)): tap a genre twice to exclude it, or Exclude a tag from the tag search (`?not_genre=`, `?not_tag=`).
- **A Browse search also finds characters, staff and studios** ([#34](https://github.com/jasanpreetn9/miruyo/pull/34)).
- **Browse's ready-made lists, with ranks** ([#34](https://github.com/jasanpreetn9/miruyo/pull/34)): All-time popular, Trending, Top rated, Airing now and Upcoming, with #1, #2… on lists ordered by score, popularity or trending.
- **CI smoke-tests the production build** ([#42](https://github.com/jasanpreetn9/miruyo/pull/42)): every main page must start in a real production build, also after a client-side navigation, with no uncaught error.

**Changed**

- **The Anime / Manga switch follows the title you open** ([#34](https://github.com/jasanpreetn9/miruyo/pull/34)): a manga's page switches to Manga, an anime's to Anime.
- **For You's titles rotate each day** ([#34](https://github.com/jasanpreetn9/miruyo/pull/34)), weighted so the higher you rated a title the more often it seeds your picks.
- **AniList requests are paced to its rate limit** ([#35](https://github.com/jasanpreetn9/miruyo/pull/35)), 30–90 a minute: when few are left they go out one at a time instead of failing behind "AniList is busy".
- **Home's Upcoming** ([#36](https://github.com/jasanpreetn9/miruyo/pull/36)): one layout for every card, six titles, dated premieres first, and long sequel titles keep their season.
- **Home's Continue watching** ([#37](https://github.com/jasanpreetn9/miruyo/pull/37)): caught up, the next episode is a slim strip instead of a big card; Up next says Start and shows each title's length.

**Fixed**

- **A profile with a favourite listed twice no longer crashes** ([#43](https://github.com/jasanpreetn9/miruyo/pull/43)).
- **Production was down for part of the day** after the first analytics release ([#39](https://github.com/jasanpreetn9/miruyo/pull/39)): Vercel's SvelteKit helpers use `$app/stores`, which SvelteKit 3 removed. It was reverted ([#40](https://github.com/jasanpreetn9/miruyo/pull/40)) and rebuilt on the plain scripts; a test fails if the old helpers come back, and the production smoke test above would have caught it.

## Nov 1, 2026

**Added**

- **Staff and character pages** ([#33](https://github.com/jasanpreetn9/miruyo/pull/33)) (`/staff/[id]`, `/character/[id]`): a voice actor's roles (popular or newest), credits folded per title, and a character's titles with their voice actors. Bios are AniList's markdown, made safe, with spoilers behind a chip. The title page's people and your favourite people link here instead of AniList.
- **Server rendering for public pages** ([#32](https://github.com/jasanpreetn9/miruyo/pull/32)): the title page, season chart and schedule load their signed-out data on the server, so they show at once and the CDN caches them. Every page has search and share tags; title pages have their own card and JSON-LD; personal pages aren't indexed; there's a sitemap.
- **Title pages show more** ([#32](https://github.com/jasanpreetn9/miruyo/pull/32)): tags ranked by fit (spoilers hidden until asked), where to watch or read, the official links and socials, and other names.

**Changed**

- **CI checks always report** ([#31](https://github.com/jasanpreetn9/miruyo/pull/31)), and skip their steps when their app didn't change, so a mobile-only PR no longer waits on a web e2e that never runs.

## Before Nov 2026

Phases 0–8 of the [roadmap](ROADMAP.md): the design system, Home, Login, Browse, the title page and list editor, My List, Schedule and Seasonal, Stats, Settings, notifications and For You.
