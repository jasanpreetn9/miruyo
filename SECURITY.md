# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue: use GitHub's **[Report a vulnerability](../../security/advisories/new)** form on this repository (the Security tab). Include what you found, how to reproduce it, and what someone could do with it.

You'll get a reply within a week. Once a fix is out, the advisory is published, crediting you unless you'd rather not be named.

## What's in scope

- **The website** at [miruyo.vercel.app](https://miruyo.vercel.app) and the code in this repository.

Problems in AniList itself (its API, accounts or sign-in) belong to AniList; report those to them.

## How miruyo handles your account

- miruyo signs you in with AniList's OAuth. It never sees your AniList password.
- The AniList token is kept in your browser's `localStorage` and sent only to AniList's API.
- There's no miruyo server or database: nothing about you is stored anywhere but your device and AniList.

Things worth reporting include anything that could leak a token or send it somewhere other than AniList, cross-site scripting (for example through synopses or other text from AniList), and ways to make the site act on someone's account without them.
