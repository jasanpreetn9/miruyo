<script lang="ts">
	import { session } from '#lib/state/session.svelte.ts';
	import { LEGAL, LEGAL_PAGES } from '#lib/legal.ts';

	// The quiet line at the foot of the main pages: who runs the site, where the
	// data comes from, the sections and the legal documents. PageShell puts it
	// on every main page; focused screens (login, welcome) leave it out.

	const isAnime = $derived(session.mode === 'anime');
	const year = new Date().getFullYear();

	const sections = $derived([
		{ href: '/browse', label: 'Browse' },
		isAnime
			? { href: '/seasonal', label: 'Seasonal' }
			: { href: '/schedule', label: 'New releases' },
		{ href: '/for-you', label: 'For You' },
		{ href: '/list', label: 'My List' }
	]);

	const link = 'text-dim transition-colors hover:text-ink';
</script>

<footer
	class="mt-8 border-t border-line px-4 py-6 text-[13px] text-dim lg:mt-12 lg:px-10 lg:py-8 xl:px-20"
>
	<div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between lg:gap-8">
		<p class="m-0 flex flex-wrap items-center gap-x-1.5 gap-y-1">
			<span>© {year} {LEGAL.app}</span>
			<span aria-hidden="true">·</span>
			<span>
				Data from
				<a href="https://anilist.co" target="_blank" rel="noreferrer" class="{link} font-medium"
					>AniList</a
				>
			</span>
		</p>

		<div class="flex flex-wrap items-center gap-x-5 gap-y-3">
			<nav aria-label="Sections" class="flex flex-wrap gap-x-4 gap-y-2">
				{#each sections as s (s.href)}
					<a href={s.href} class={link}>{s.label}</a>
				{/each}
			</nav>
			<span class="hidden h-3.5 w-px bg-line sm:block" aria-hidden="true"></span>
			<nav aria-label="Legal" class="flex flex-wrap gap-x-4 gap-y-2">
				{#each LEGAL_PAGES as p (p.href)}
					<a href={p.href} class={link}>{p.label}</a>
				{/each}
			</nav>
			{#if LEGAL.appStore}
				<a
					href={LEGAL.appStore}
					target="_blank"
					rel="noreferrer"
					class="flex h-8 items-center rounded-[2px] border border-line px-3 font-semibold text-muted transition-colors hover:border-ink hover:text-ink"
					>Get the iOS app</a
				>
			{/if}
		</div>
	</div>
</footer>
