<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import SectionError from '#lib/components/home/SectionError.svelte';
	import PageShell from '#lib/components/shared/PageShell.svelte';
	import Skeleton from '#lib/components/shared/Skeleton.svelte';
	import { session } from '#lib/state/session.svelte.ts';

	// Your profile is your own user page (/user/[name]): the same page anyone
	// sees, with your whole list in your own score format and Settings in the
	// header. Old links here (and /stats) forward to it, keeping ?range= for
	// its Stats; signed out, this asks you to log in.

	$effect(() => {
		const name = session.user?.name;
		if (session.authState !== 'in' || !name) return;
		const range = page.url.searchParams.get('range');
		const base = `/user/${encodeURIComponent(name)}`;
		void goto(range ? `${base}?range=${encodeURIComponent(range)}` : base, { replace: true });
	});
</script>

<svelte:head>
	<title>Profile · miruyo</title>
</svelte:head>

<PageShell nav="profile" tab="profile" pad="pb-28 lg:pb-0">
	{#if session.authState === 'out'}
		<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
			<span class="material-symbols-rounded !text-[40px] text-dim" aria-hidden="true"
				>bar_chart</span
			>
			<h1
				class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
			>
				Your profile lives on AniList
			</h1>
			<p class="m-0 max-w-sm text-sm text-muted">
				Log in to see your favourites, what you've watched and read, how you score, and when.
			</p>
			<a
				href="/login"
				class="mt-2 flex h-12 items-center rounded-[2px] bg-anime px-5 font-semibold text-anime-ink hover:text-anime-ink"
				>Log in with AniList</a
			>
		</div>
	{:else if session.authState === 'error'}
		<div class="px-4 pt-10 lg:px-10 xl:px-20">
			<SectionError
				title="Couldn't load your profile"
				onRetry={() => session.loadCurrentUser()}
				detail={session.loadError}
			/>
		</div>
	{:else}
		<div class="flex flex-col gap-6" aria-busy="true" aria-label="Loading your profile">
			<div class="skeleton-shimmer h-36 lg:h-60"></div>
			<div class="flex items-end gap-3 px-4 lg:-mt-16 lg:px-10 xl:px-20">
				<Skeleton class="h-20 w-20 rounded-[2px] lg:h-28 lg:w-28" />
				<Skeleton class="mb-2 h-8 w-48" />
			</div>
		</div>
	{/if}
</PageShell>
