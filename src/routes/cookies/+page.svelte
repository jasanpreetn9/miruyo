<script lang="ts">
	import LegalPage from '#lib/components/legal/LegalPage.svelte';
	import { LEGAL } from '#lib/legal.ts';
	import {
		FOR_YOU_DISMISSED_STORAGE_KEY,
		FOR_YOU_TUNE_STORAGE_KEY,
		LIST_VIEW_STORAGE_KEY,
		MODE_STORAGE_KEY,
		OAUTH_STATE_STORAGE_KEY,
		ONBOARDED_STORAGE_KEY,
		QUICK_PICK_SKIPPED_STORAGE_KEY,
		RATE_LIMIT_STORAGE_KEY,
		SEASON_VIEW_STORAGE_KEY,
		TOKEN_STORAGE_KEY
	} from '#lib/storage-keys.ts';

	// Adapted from General Legal's "Cookie Notice" template (CC0,
	// github.com/General-Legal/legal-templates). Miruyo sets no cookies, so the
	// notice is mostly about local storage. The table reads the keys from
	// storage-keys.ts; a new key there needs a row (and a purpose) here.

	const { app, email } = LEGAL;

	const STORED: { key: string; what: string; cleared: string }[] = [
		{
			key: TOKEN_STORAGE_KEY,
			what: 'Your AniList access token, so you stay signed in.',
			cleared: 'When you sign out, or AniList stops accepting it'
		},
		{
			key: OAUTH_STATE_STORAGE_KEY,
			what: 'A random code that checks a sign-in came back from the one you started (session storage).',
			cleared: 'When the sign-in finishes, or you close the tab'
		},
		{
			key: RATE_LIMIT_STORAGE_KEY,
			what: "How many requests AniList's rate limit had left a moment ago, so a reload doesn't run into it (session storage).",
			cleared: 'After a minute, or when you close the tab'
		},
		{
			key: MODE_STORAGE_KEY,
			what: 'Whether you were last looking at anime or manga.',
			cleared: 'When you clear site data'
		},
		{
			key: ONBOARDED_STORAGE_KEY,
			what: 'That you finished or skipped the first-run setup.',
			cleared: 'When you clear site data'
		},
		{
			key: QUICK_PICK_SKIPPED_STORAGE_KEY,
			what: 'Which empty lists you chose not to fill from the quick-pick.',
			cleared: 'When you clear site data'
		},
		{
			key: LIST_VIEW_STORAGE_KEY,
			what: 'Whether My List shows as a table or a grid.',
			cleared: 'When you clear site data'
		},
		{
			key: SEASON_VIEW_STORAGE_KEY,
			what: 'Whether the season chart shows cards or posters.',
			cleared: 'When you clear site data'
		},
		{
			key: FOR_YOU_DISMISSED_STORAGE_KEY,
			what: 'Titles you hid from For You with "Not this".',
			cleared: 'When you clear site data'
		},
		{
			key: FOR_YOU_TUNE_STORAGE_KEY,
			what: 'How you tuned For You: only titles that are out, picks from your other list, and genres to leave out.',
			cleared: 'When you clear site data'
		}
	];
</script>

<LegalPage title="Cookies & Storage">
	{#snippet summary()}
		<p class="m-0">
			<strong class="text-ink">The short version:</strong>
			{app} doesn't set any cookies and doesn't track you. It keeps a few settings in your browser's local
			storage so it remembers you, and nothing there is sent to us. Anonymous page counts work without
			cookies.
		</p>
	{/snippet}

	<p>
		This page explains how {app} uses cookies and similar technologies, such as your browser's local storage.
		For how personal information is handled more broadly, see the
		<a href="/privacy">Privacy Policy</a>.
	</p>

	<h2 id="cookies">Cookies</h2>
	<p>
		Cookies are small files a website places on your device. {app} doesn't set any, first-party or third-party:
		no advertising, analytics, social or session-replay cookies, and no pixels or web beacons. Because
		there are no optional cookies, there's no cookie banner to accept.
	</p>
	<p>
		{app} counts page views and measures how fast pages load with Vercel Web Analytics and Speed Insights,
		and with Cloudflare Web Analytics. None of them use cookies or identify you; the
		<a href="/privacy">Privacy Policy</a> lists what they record.
	</p>
	<p>
		When you choose <strong>Log in with AniList</strong>, you go to anilist.co to approve access.
		AniList may use cookies on its own site, as its policies describe.
	</p>

	<h2 id="storage">Local storage</h2>
	<p>
		Local storage is space in your browser that a site can use to remember things on your device. {app}
		uses it only for things the site needs to work the way you left it. Under European rules this storage
		is strictly necessary, so it doesn't need consent. None of it leaves your device, except that the
		access token is sent to AniList with each request so AniList knows it's you.
	</p>
	<div class="table-wrap">
		<table>
			<thead>
				<tr>
					<th>Name</th>
					<th>What it remembers</th>
					<th>Removed</th>
				</tr>
			</thead>
			<tbody>
				{#each STORED as row (row.key)}
					<tr>
						<td><code>{row.key}</code></td>
						<td>{row.what}</td>
						<td>{row.cleared}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>

	<h2 id="third-parties">Content from other services</h2>
	<p>
		Some parts of the page load from other services: the typefaces from Google Fonts, cover art and
		banners from AniList, and trailer thumbnails from YouTube. Like any request, these share your IP
		address and browser details with those services. They don't set cookies through {app}, and we
		don't receive anything from them about you.
	</p>

	<h2 id="choices">Your choices</h2>
	<ul>
		<li>
			<strong>Sign out</strong> in Settings to remove the access token from this browser.
		</li>
		<li>
			<strong>Clear site data</strong> in your browser's settings to remove everything {app} has stored.
			You'll be signed out and your preferences will reset.
		</li>
		<li>
			<strong>Block storage</strong> in your browser. {app} still works for browsing, but it won't be
			able to keep you signed in or remember your preferences.
		</li>
	</ul>

	<h2 id="changes">Changes</h2>
	<p>
		If {app} starts storing something new, or adds cookies, we'll update this page and the date above
		first, and ask for your consent where the law requires it.
	</p>

	<h2 id="questions">Questions</h2>
	<p>Email <a href="mailto:{email}">{email}</a>.</p>
</LegalPage>
