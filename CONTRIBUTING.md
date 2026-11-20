# Contributing to miruyo

Thanks for wanting to help. miruyo is a fast front end for [AniList](https://anilist.co): a website (`apps/web`, SvelteKit) and an iOS and Android app (`apps/mobile`, Flutter). Both talk to AniList's public GraphQL API directly; there's no miruyo server or database.

## Before you start

- **Bugs and small fixes:** open a pull request, or an issue first if you're not sure it's a bug.
- **New features or bigger changes:** open an issue to talk it through before writing code, so nobody's work goes to waste. Each app's `ROADMAP.md` lists what's planned and what's been decided.
- **Security problems:** don't open an issue; see [SECURITY.md](SECURITY.md).

## Where things live

```
.github/            CI workflows, issue and PR templates, Dependabot
docs/screenshots/   images for the READMEs
apps/web/           the website (SvelteKit): README, ROADMAP, CHANGELOG
  src/routes/         one folder per page
  src/lib/            AniList client, logic, state, components
  e2e/                Playwright tests
apps/mobile/        the app (Flutter): README, ROADMAP, CHANGELOG, PUBLISHING
  lib/core/           AniList client, logic, list store, storage, theme
  lib/features/       one folder per screen
  lib/widgets/        shared widgets
  test/               mirrors lib/
```

Each app's README has the full map. The two apps are built the same way, so most things have a twin:

| What                                    | Website (`apps/web/src`)            | App (`apps/mobile/lib`)                    |
| --------------------------------------- | ----------------------------------- | ------------------------------------------ |
| GraphQL queries                         | `lib/anilist/queries.ts`            | `core/anilist/queries.dart`                |
| AniList client and rate pacing          | `lib/anilist/client.ts`, `pacer.ts` | `core/anilist/client.dart`, `pacer.dart`   |
| Title logic (status, progress, airing)  | `lib/catalog/`                      | `core/catalog/`                            |
| The list store (optimistic edits, Undo) | `lib/state/list.svelte.ts`          | `core/list/list_store.dart`                |
| A page's data                           | `lib/page-data/<page>.ts`           | `features/<page>/<page>_data.dart`         |
| A page                                  | `routes/<page>/+page.svelte`        | `features/<page>/<page>_screen.dart`       |
| Design tokens                           | `routes/layout.css`                 | `core/theme/tokens.dart`, `app_theme.dart` |
| Shared pieces                           | `lib/components/shared/`            | `widgets/`                                 |

Look for an issue labelled **good first issue** if you want somewhere to start.

## Setting up

You'll need your own AniList API client: create one at [anilist.co/settings/developer](https://anilist.co/settings/developer). A client has one redirect URL, so the web and the app each need their own.

### Website (`apps/web`)

Node 24 or later (CI uses 24 and 26).

```bash
cd apps/web
npm install
cp .env.example .env   # set PUBLIC_ANILIST_CLIENT_ID; the redirect URL is http://localhost:5173/api/callback
npm run dev
```

### App (`apps/mobile`)

Flutter (the version CI uses is in `.github/workflows/mobile.yml`).

```bash
cd apps/mobile
cp config/anilist.example.json config/anilist.json   # set your client id; the redirect URL is miruyo://auth
flutter run --dart-define-from-file=config/anilist.json
```

Without a client id, both still run signed out.

## Checks

CI runs these on every pull request, only for the app that changed. Run them before you push.

**Website**, from `apps/web`:

```bash
npm run check
```

```bash
npm run lint
```

```bash
npm test
```

`npm test` runs the unit tests and the Playwright end-to-end tests (`npx playwright install` the first time). Fix formatting with `npm run format`.

**App**, from `apps/mobile`:

```bash
tool/format.sh
```

```bash
flutter analyze
```

```bash
flutter test
```

Use `tool/format.sh`, not `dart format lib`: it leaves the generated `*.g.dart` files alone. After changing a database table, regenerate them with `dart run build_runner build --delete-conflicting-outputs`.

## How the project works

- **The website is the reference.** The app follows the web's behaviour; GraphQL queries are copied between them word for word, and logic is ported with its tests. A change to how something works usually lands in both, in separate commits.
- **Design.** The look is editorial: a warm off-black page, cream ink, Fraunces headings, rules instead of cards, and each title's cover colour tinting its page. Reuse the shared pieces (`SectionHeading`, `btn-ink`, `btn-quiet`, `field-line` on the web; the matching widgets and tokens in the app) rather than new one-off styles.
- **Accessibility.** Tap targets are at least 44pt, text meets WCAG AA contrast, motion respects reduced-motion settings, and the app is tested at 1.3× text. The tests check most of this.
- **AniList's limits.** The API allows about 90 requests a minute, sometimes cut to 30. Batch, cache and avoid refetching; both apps share identical in-flight requests and cache responses briefly.

## Commits and pull requests

- Keep a pull request to one change. Commit messages start with the area (`Web:`, `Mobile:`, `Docs:`) and say what changed for the user, in plain words.
- Add or update tests with the change, and a line in the app's `CHANGELOG.md` for anything a user would notice.
- Pull requests are rebase-merged once CI is green, so `main` stays linear.

## Code of conduct

Everyone taking part is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Licence

By contributing, you agree that your contributions are licensed under the project's [MIT licence](LICENSE).
