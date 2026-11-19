<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import Favourites from '#lib/components/profile/Favourites.svelte';
	import StatsPanel from '#lib/components/profile/StatsPanel.svelte';
	import { buildProfile } from '#lib/page-data/profile.ts';
	import { buildHeatmap, buildStats, parseRange, type StatsRange } from '#lib/page-data/stats.ts';
	import { possessive } from '#lib/page-data/user.ts';
	import { mediaTypeFor, session } from '#lib/state/session.svelte.ts';
	import { getUserPage } from '#lib/state/user-page.svelte.ts';

	// Overview: favourites (following the Anime / Manga switch), then Stats,
	// with the switch and the time range (?range=) in its heading. The bio and
	// the headline numbers are in the header (the layout). Yours in your own
	// score format; anyone else's out of 10.

	const user = getUserPage();
	const account = $derived(user.account);
	const signedIn = $derived(session.authState === 'in');
	const isAnime = $derived(session.mode === 'anime');
	const type = $derived(mediaTypeFor(session.mode));
	const resource = $derived(user.lists[type]);
	const whose = $derived(user.own ? 'your' : account ? possessive(account.name) : 'their');

	$effect(() => {
		void account?.id;
		user.loadList(type);
		user.loadHistory();
	});

	const view = $derived(
		user.loaded
			? buildProfile(user.loaded, { showAdult: signedIn && session.showAdultContent })
			: null
	);

	const now = new Date();
	const range = $derived(parseRange(page.url.searchParams.get('range')));
	function setRange(r: StatsRange) {
		const url = new URL(page.url.href);
		if (r === 'all') url.searchParams.delete('range');
		else url.searchParams.set('range', r);
		void goto(url, { replace: true, reset: false });
	}

	// counted as the list tabs show it (18+ titles left out unless the viewer shows them)
	const shown = $derived(user.shownList(type));
	const stats = $derived(
		shown ? buildStats(shown, { isAnime, range, scoreFormat: user.scoreFormat, now }) : null
	);
	const heatmap = $derived(user.history.data ? buildHeatmap(user.history.data, now) : null);
</script>

<svelte:head>
	<title>{account ? `${user.own ? 'Your profile' : account.name} · miruyo` : 'miruyo'}</title>
</svelte:head>

{#if account}
	<div class="flex flex-col gap-10">
		<Favourites
			{view}
			{isAnime}
			{whose}
			failed={user.profile.failed}
			error={user.profile.error}
			retryIn={user.profile.retry.active ? user.profile.retry.label : undefined}
			rateLimited={user.profile.rateLimited}
			onRetry={() => user.loadProfile(signedIn)}
		/>
		<StatsPanel
			{stats}
			{heatmap}
			historyTotal={user.history.data?.reduce((a, d) => a + d.amount, 0) ?? 0}
			historyFailed={user.history.failed}
			onRetryHistory={() => user.loadHistory()}
			loading={resource.pending}
			failed={resource.failed && !user.isPrivate(type)}
			error={resource.error}
			retryIn={resource.retry.active ? resource.retry.label : undefined}
			rateLimited={resource.rateLimited}
			onRetry={() => user.loadList(type)}
			{range}
			onRange={setRange}
			{isAnime}
			{now}
			{whose}
			own={user.own}
			privateList={user.isPrivate(type) ? `${account.name} keeps their list private` : null}
		/>
	</div>
{/if}
