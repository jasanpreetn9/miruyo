# miruyo

A fast front end for your [AniList](https://anilist.co) anime and manga list: one-tap progress, what's airing next, and what's trending this season.

## Layout

| Folder        | What it is                                                                                                                                                  |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/web`    | The website: SvelteKit, deployed to Vercel at [miruyo.jnagra.com](https://miruyo.jnagra.com). [README](apps/web/README.md) · [Roadmap](apps/web/ROADMAP.md) |
| `apps/mobile` | The iOS and Android app, in Flutter. [README](apps/mobile/README.md) · [Roadmap](apps/mobile/ROADMAP.md)                                                    |
| `design`      | Design exports, shared by both apps                                                                                                                         |

Each app has its own tooling and is run from its own folder: npm in `apps/web`, Flutter in `apps/mobile`. CI runs each app's checks only when that app changes.
