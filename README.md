# miruyo

A fast front end for your [AniList](https://anilist.co) anime and manga list: one-tap progress, what's airing next, and what's trending this season.

**Live at [miruyo.vercel.app](https://miruyo.vercel.app).** Sign in with your AniList account; everything you change is saved straight to AniList.

## What it does

- **Track in one tap.** Home leads with what you're behind on, and +1 logs an episode or chapter from anywhere. Edits show at once and sync to AniList, and the app queues them while you're offline.
- **Know what's airing.** The season chart, the week's schedule in your own time zone, countdowns to the next episode, and (in the app) a reminder when it's out.
- **Find what's next.** For You picks from the titles you rated highest, each saying why; trending and popular rows; search with AniList's filters.
- **Anime and manga.** One switch changes the whole app between them.
- **Your stats and profile**, people's lists, staff, characters and studios.

## Layout

| Folder        | What it is                                                                                                                                                  |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/web`    | The website: SvelteKit, deployed to Vercel at [miruyo.vercel.app](https://miruyo.vercel.app). [README](apps/web/README.md) · [Roadmap](apps/web/ROADMAP.md) |
| `apps/mobile` | The iOS and Android app, in Flutter. [README](apps/mobile/README.md) · [Roadmap](apps/mobile/ROADMAP.md)                                                    |

Each app has its own tooling and is run from its own folder: npm in `apps/web`, Flutter in `apps/mobile`. CI runs each app's checks only when that app changes.

**Built with** SvelteKit (Svelte 5), Tailwind CSS v4 and Vercel for the web; Flutter, Riverpod and drift for the app. Both call AniList's public GraphQL API directly: there's no miruyo server or database.

## Running it yourself

You need your own AniList API client, from [anilist.co/settings/developer](https://anilist.co/settings/developer). Setup for each app is in [CONTRIBUTING.md](CONTRIBUTING.md#setting-up) and the app's README.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first; everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md). Report security problems privately, as [SECURITY.md](SECURITY.md) describes.

## Credits

- Data and cover art come from [AniList](https://anilist.co) through its public API. **miruyo is an unofficial client: it isn't affiliated with or endorsed by AniList.**
- Fonts: [Fraunces](https://github.com/undercasetype/Fraunces), [Schibsted Grotesk](https://github.com/schibsted/schibsted-grotesk) and [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono), under the SIL Open Font License. Icons: [Material Symbols](https://fonts.google.com/icons), under the Apache License 2.0.

## Licence

[MIT](LICENSE) © Jasanpreet Nagra
