# Roadmap

What's planned for the website. What has already shipped is in [CHANGELOG.md](CHANGELOG.md). Want to take something on? Open an issue first so we can talk it through ([CONTRIBUTING.md](CONTRIBUTING.md)).

## Next up

- [ ] **Title Stats: ranking history.** The tab shows today's rankings; add how they changed over time.
- [ ] **An accessibility audit.** AA contrast on every surface, visible focus rings, targets of at least 44px, and status never shown by colour alone. Keyboard equivalents for hover overlays; focus kept inside the sheet and the side panel.
- [ ] **End-to-end coverage** for every route and its empty, loading and error states.
- [ ] **Check notifications** against the live API.

## Known issues

- [ ] **Flaky e2e test:** "a rate-limited feed counts down and retries on its own" (`e2e/home.spec.ts`) fails about 1 run in 3. It's a timing race around the countdown.
- [ ] **Console noise in e2e runs** from queries some tests don't mock (list state: `reading 'mediaList'`; the login poster wall: `reading 'media'`). Harmless, but worth mocking.
- [ ] **Paused count:** My List once showed 7 paused while Home said 9. They come from different requests; not looked into yet.
- [ ] **Upcoming on phones:** long sequel titles can still lose their season number.

## Performance

From PageSpeed's mobile report:

- [ ] Server-render the signed-out Home so its first cover is in the HTML.
- [ ] Self-host the fonts: Google Fonts' CSS blocks rendering for about 0.75s.
- [ ] Covers are AniList's PNGs (up to 560 KB), which only an image resizer would shrink.

## Maintenance

- [ ] **Move Vercel analytics to stable releases.** `@vercel/analytics` and `@vercel/speed-insights` are pinned to pre-releases (`2.1.0-canary.5`, `2.1.0-canary`), the first to declare SvelteKit 3 support. When a stable release lists `^3` (`npm view @vercel/analytics peerDependencies`), switch both to it. Keep using the plain `inject()` / `injectSpeedInsights()`: the `/sveltekit` entry points use `$app/stores`, which throws in SvelteKit 3. `src/lib/analytics.test.ts` fails if either comes back.
- [ ] **Cloudflare:** turn off Cloudflare's Web Analytics on miruyo.jnagra.com. Its injected beacon is blocked by the CSP, which adds a hop and console errors.

## Later

- [ ] **An installable app.** The manifest's `display` is `browser`, so the site can't be installed as a PWA yet.
- [ ] **Reminders** for titles not on your list (see the open question below).

## Decisions

Settled, so they don't get reopened by accident:

- **Completing at the total:** any +1 that reaches the total moves the title to Completed, with an Undo. In the editor, the draft switches to Completed with an inline Undo.
- **Search and browse** are one page; the Search tab and ⌘K focus its search box.
- **Sharing a list** shares your page at `/user/[name]`, which has Overview, Anime list and Manga list, each at its own address.
- **For You** is a row on Home with "See all" opening `/for-you`; it has no nav item.
- **Settings** holds only what changes what miruyo shows, saved to AniList.
- **Server-side rendering** is for the first load of the title page, Seasonal and Schedule. Each has a `+page.server.ts` that fetches the signed-out data (`src/lib/server/public-load.ts`); the browser's own copy (your list state, 18+) replaces it once it loads. Client-side navigation skips the server fetch. The pages are the same for everyone, so the CDN caches them (`s-maxage=600, stale-while-revalidate=86400`), and the CSP uses hashes rather than nonces for that reason. `SSR_ANILIST=off` turns the server fetch off (e2e does, since its mocks reach only the browser). Character, staff, studio and user pages load in the browser only: crawlers are kept off them, and server-rendering them let a scraper use up Vercel's free transfer. Links preload their data on tap, not hover, and a navigation's data request is cached for a day, so neither wakes the server.

Still open:

- **Reminders.** AniList only sends airing notifications for titles on your list. Reminding you about anything else would need browser push plus a server or a scheduled job, which miruyo doesn't have. Settings already has AniList's own airing-notifications toggle.
