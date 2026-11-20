# miruyo — web

A fast front end for your [AniList](https://anilist.co) anime and manga list: one-tap progress, what's airing next, and what's trending this season.

Built with SvelteKit (Svelte 5 runes), Tailwind CSS v4, and deployed to Vercel.

![Home, signed out](../../docs/screenshots/web-home.jpg)

| A title page                                                                                                                       | The season chart                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| ![Frieren's title page, tinted green by its cover, with its score, streaming links and tabs](../../docs/screenshots/web-title.jpg) | ![Fall 2026's season chart: the season's kanji, then ranked entries](../../docs/screenshots/web-seasonal.jpg) |

## How it works

- **Auth** — AniList OAuth implicit grant. `/login` links to AniList, which redirects back to `/api/callback` with the token in the URL hash; the token is stored in `localStorage`.
- **Data** — everything is fetched client-side from `https://graphql.anilist.co` (`src/lib/anilist/`), then adapted to the UI's `Title` shape (`src/lib/catalog/`). Identical queries share one in-flight request and are cached for a minute; saves drop the signed-in responses (public ones stay cached). A 429 retries automatically after a countdown, and a rejected token signs the viewer out with a notice.
- **Titles** — signed in, AniList's `userPreferred` title (the account's own language setting); signed out, English.
- **State** — `session` (`src/lib/state/session.svelte.ts`) holds auth state and the anime/manga mode. `list` (`src/lib/state/list.svelte.ts`) holds every list entry by media id, so an edit on one card updates them all; edits apply immediately and roll back if AniList rejects them.
- **Stats** are computed from the viewer's list collection (`src/lib/page-data/stats.ts`) rather than AniList's `User.statistics`, whose breakdowns are often stale.
- **Layout** — phones and iPads in portrait (under 1024px) get the touch layout with a bottom tab bar; from 1024px, the desktop layout and top bar.

## Code layout

| Where                              | What it is                                                                                                                                                             |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/routes`                       | One folder per page. A page's `+page.svelte` stays thin: it calls `src/lib/page-data` and composes components. `+page.server.ts` files fetch the signed-out first load |
| `src/routes/layout.css`            | The design tokens (`@theme`: colours, type, spacing) and shared utilities (`btn-ink`, `btn-quiet`, `field-line`, the motion classes)                                   |
| `src/lib/anilist`                  | The GraphQL client, queries, rate pacing, and adapting AniList's responses                                                                                             |
| `src/lib/catalog`                  | Pure logic about titles: status verbs, progress and +1 rules, airing, cover colours                                                                                    |
| `src/lib/page-data`                | Each page's data: what it fetches and how it shapes it, as plain functions with unit tests                                                                             |
| `src/lib/state`                    | Shared reactive state (`*.svelte.ts`): the session, the list store, toasts, the editor, the clock                                                                      |
| `src/lib/components`               | Svelte components, by page (`home`, `browse`, `seasonal`, …), and `shared` for those used everywhere                                                                   |
| `src/lib/server`                   | Server-only code: the signed-out first load                                                                                                                            |
| `src/lib/browse`, `src/lib/editor` | Browse's URL parameters; the list editor's draft                                                                                                                       |
| `src/lib/*.ts`                     | App-wide helpers: SEO tags, motion, analytics, storage keys, legal details                                                                                             |
| `e2e`                              | Playwright tests, one spec per page, with AniList mocked; shared helpers in `e2e/helpers`                                                                              |
| `e2e-prod`                         | A smoke test of the production build                                                                                                                                   |

Unit tests sit next to the code they test (`foo.ts` and `foo.test.ts`).

## Pages

| Route                            | What it is                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `/`                              | Home: continue watching/reading, the hero, trending, popular this season, upcoming (the public rows show signed out too) |
| `/browse`, `/search`             | Search & browse with filters; everything in the URL                                                                      |
| `/title/[id]`                    | A title: status, progress, score, relations, characters, recommendations; opens the list editor                          |
| `/list`                          | My List: tabs by status, table or grid, edit in place                                                                    |
| `/seasonal`                      | The season chart (AniChart's layout): TV, TV Short, Leftovers, Movie, OVA / ONA / Special                                |
| `/schedule`                      | The week's airings, day by day (manga: New releases)                                                                     |
| `/for-you`                       | Picks from your top-rated titles, each with its reason; also a row on Home                                               |
| `/profile`                       | Your profile: banner, avatar and favourites, then stats from your list (`/stats` forwards here)                          |
| `/settings`                      | Account settings, saved to AniList                                                                                       |
| `/login`, `/welcome`             | Sign-in and first-run setup                                                                                              |
| `/privacy`, `/terms`, `/cookies` | Privacy Policy, Terms of Use, Cookies & Storage; operator details live in `src/lib/legal.ts`                             |

What's planned is in [ROADMAP.md](ROADMAP.md); what changed, in [CHANGELOG.md](CHANGELOG.md).

## Developing

Run these from `apps/web`.

```sh
npm install
cp .env.example .env   # then set PUBLIC_ANILIST_CLIENT_ID
npm run dev
```

`PUBLIC_ANILIST_CLIENT_ID` is the AniList API client to sign in with ([anilist.co/settings/developer](https://anilist.co/settings/developer)). A client has one redirect URL, `<origin>/api/callback`, so use one client for `localhost` and another for production (set it in Vercel's environment variables). The build fails if it's missing.

## Checks

```sh
npm run check     # svelte-check / TypeScript
npm run lint      # prettier
npm run test:e2e  # Playwright (AniList API is mocked)
npm run build && npm run test:prod  # the production build starts (smoke test, e2e-prod/)
```

The smoke test is the one that runs production-only code (analytics) in a browser; the dev server never does. CI runs it after the e2e tests, on Node 24 (Vercel's adapter needs 22 or 24; on newer Node its last step fails, but the build the smoke test serves is already written).

## Building

```sh
npm run build
npm run preview
```
