# Contributing to miruyo

Thanks for wanting to help. miruyo is a fast front end for [AniList](https://anilist.co), built with SvelteKit. It talks to AniList's public GraphQL API straight from the browser; there's no miruyo server or database.

## Before you start

- **Bugs and small fixes:** open a pull request, or an issue first if you're not sure it's a bug.
- **New features or bigger changes:** open an issue to talk it through before writing code, so nobody's work goes to waste. [ROADMAP.md](ROADMAP.md) lists what's planned and what's been decided.
- **Security problems:** don't open an issue; see [SECURITY.md](SECURITY.md).

Look for an issue labelled **good first issue** if you want somewhere to start.

## Where things live

```
src/routes/         one folder per page
src/routes/layout.css   design tokens and shared utilities
src/lib/anilist/    the GraphQL client, queries and rate pacing
src/lib/catalog/    pure logic about titles: status, progress, airing
src/lib/page-data/  each page's data, as plain functions with tests
src/lib/state/      shared reactive state: session, list store, toasts
src/lib/components/ components by page, and shared/ for the rest
e2e/                Playwright tests, one spec per page (helpers in e2e/helpers)
e2e-prod/           a smoke test of the production build
static/             icons and the manifest
docs/               architecture notes and README screenshots
.github/            CI, issue and PR templates, Dependabot
```

[docs/architecture.md](docs/architecture.md) explains how it fits together: sign-in, data loading and caching, state, and every page.

## Setting up

Node 24 or later (CI uses 24 and 26), and your own AniList API client: create one at [anilist.co/settings/developer](https://anilist.co/settings/developer) with the redirect URL `http://localhost:5173/api/callback`.

```bash
npm install
cp .env.example .env   # set PUBLIC_ANILIST_CLIENT_ID
npm run dev
```

The build fails without a client id.

## Checks

CI runs these on every pull request. Run them before you push.

```bash
npm run check
```

```bash
npm run lint
```

```bash
npm test
```

`npm test` runs the unit tests and the Playwright end-to-end tests, with AniList mocked (`npx playwright install` the first time). Fix formatting with `npm run format`. CI also builds for production and runs a smoke test against it (`npm run build && npm run test:prod`, on Node 24).

## How the project works

- **Design.** The look is editorial: a warm off-black page, cream ink, Fraunces headings, rules instead of cards, and each title's cover colour tinting its page. Reuse the tokens and shared pieces (`SectionHeading`, `btn-ink`, `btn-quiet`, `field-line`) rather than new one-off styles.
- **Accessibility.** Tap targets are at least 44px, text meets WCAG AA contrast, and motion respects reduced-motion settings. The tests check most of this.
- **AniList's limits.** The API allows about 90 requests a minute, sometimes cut to 30. Batch, cache and avoid refetching; identical in-flight requests are shared and responses cached briefly.
- **Pages stay thin.** A page's data lives in `src/lib/page-data` as plain functions with unit tests; the `+page.svelte` composes components around it.

## Commits and pull requests

- Keep a pull request to one change. Commit messages say what changed for the user, in plain words.
- Add or update tests with the change, and a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice.
- Pull requests are rebase-merged once CI is green, so `main` stays linear.

## Code of conduct

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Licence

By contributing, you agree that your contributions are licensed under the project's [MIT licence](LICENSE).
