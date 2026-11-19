<script lang="ts">
	import { adaptMedia } from '#lib/anilist/adapt.ts';
	import { fetchPublicTrending } from '#lib/anilist/client.ts';
	import type { Title } from '#lib/catalog/types.ts';
	import { mediaTypeFor, session } from '#lib/state/session.svelte.ts';

	let titles = $state<Title[]>([]);

	$effect(() => {
		fetchPublicTrending(mediaTypeFor(session.mode))
			.then((media) => {
				// signed out there's no account title preference, so show English
				titles = media.map((m) => adaptMedia(m, undefined, { titles: 'english' }));
			})
			.catch((err) => {
				console.error('Failed to load public trending:', err);
			});
	});

	const wall = $derived(titles.slice(0, 16));
</script>

<!-- the poster wall and sign-in pitch; Home renders the public rows below it -->
<div class="flex flex-col">
	<div class="relative h-[360px] overflow-hidden lg:h-[520px]">
		<div
			class="absolute inset-0 grid origin-top-right grid-cols-4 gap-2 p-4 opacity-80 lg:grid-cols-8 lg:gap-3 lg:p-0 lg:pt-10 lg:pl-[640px]"
			style="transform:rotate(-6deg) scale(1.15)"
		>
			{#each wall as title (title.id)}
				<div class="aspect-2/3" style="background:{title.cover}"></div>
			{/each}
		</div>
		<div
			class="absolute inset-0"
			style="background:radial-gradient(circle at 1px 1px, rgb(19 17 15 / .6) 1px, transparent 1.5px) 0 0 / 5px 5px, linear-gradient(90deg,#13110F 38%,rgba(19,17,15,.4) 75%,rgba(19,17,15,.7)),linear-gradient(0deg,#13110F,rgba(19,17,15,0) 40%)"
		></div>
		<div
			class="absolute top-16 left-5 flex max-w-[90%] flex-col gap-4 lg:top-[150px] lg:left-10 lg:max-w-[600px] lg:gap-5 xl:left-20"
		>
			<div
				class="rise font-display text-[38px] leading-[0.95] font-light tracking-[-0.04em] text-balance lg:text-[76px]"
			>
				Every episode. Every chapter. <em class="font-semibold italic">One list.</em>
			</div>
			<div class="rise text-sm leading-relaxed text-muted [--d:100ms] lg:text-[17px]">
				miruyo syncs with your AniList account — track progress in one tap, see what airs tonight,
				and find out what to watch next.
			</div>
			<div class="flex flex-wrap gap-2.5">
				<a
					href="/login"
					class="flex h-12 press items-center btn-ink px-[22px] text-[15px] hover:text-canvas"
				>
					Log in with AniList
				</a>
				<a
					href="/browse"
					class="flex h-12 items-center btn-quiet px-5 text-[15px] font-semibold hover:text-ink"
				>
					Browse without an account
				</a>
			</div>
		</div>
	</div>
</div>
