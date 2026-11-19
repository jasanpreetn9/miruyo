<script lang="ts">
	import { page } from '$app/state';
	import Navbar from '#lib/components/shared/Navbar.svelte';
	import TabBar from '#lib/components/shared/TabBar.svelte';

	const notFound = $derived(page.status === 404);
	// a title page whose id AniList doesn't know (see its +page.server.ts)
	const missingTitle = $derived(notFound && page.route.id === '/title/[id]');
</script>

<svelte:head>
	<title>{notFound ? 'Not found' : 'Something went wrong'} · miruyo</title>
</svelte:head>

<div class="min-h-screen bg-canvas pb-24 lg:pb-0">
	<Navbar />

	<div class="flex flex-col items-center gap-3 px-6 py-24 text-center">
		<div
			class="grid h-16 w-16 place-items-center rounded-[2px] border border-line bg-raised text-dim"
		>
			<span class="material-symbols-rounded !text-[32px]">
				{notFound ? 'explore_off' : 'error'}
			</span>
		</div>
		<div class="font-mono text-xs text-dim">{page.status}</div>
		<h1
			class="m-0 font-display text-[34px] leading-[0.95] font-light tracking-[-0.04em] lg:text-[44px]"
		>
			{missingTitle
				? "This title doesn't exist"
				: notFound
					? 'This page doesn’t exist yet'
					: 'Something went wrong'}
		</h1>
		<p class="max-w-sm text-sm leading-relaxed text-muted">
			{missingTitle
				? 'It may have been removed from AniList.'
				: notFound
					? 'It may be on the way — miruyo is still being built. Head back home or browse in the meantime.'
					: (page.error?.message ?? 'An unexpected error occurred.')}
		</p>
		<div class="mt-1.5 flex gap-2">
			<a
				href="/browse"
				class="flex h-11 items-center btn-quiet px-4 text-sm font-semibold text-ink"
			>
				Browse
			</a>
			<a
				href="/"
				class="flex h-11 items-center rounded-[2px] bg-anime px-4 text-sm font-semibold text-anime-ink"
			>
				Go home
			</a>
		</div>
	</div>

	<TabBar />
</div>
