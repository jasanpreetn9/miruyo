<script lang="ts">
	import { MediaQuery } from 'svelte/reactivity';
	import PosterCard from './PosterCard.svelte';
	import SectionHeading from './SectionHeading.svelte';
	import type { Title } from '#lib/catalog/types.ts';

	interface Props {
		heading: string;
		/** Set in italics after the heading (the title it's because of). */
		em?: string;
		/** A small Japanese gloss beside the heading. */
		jp?: string;
		subtitle?: string;
		titles: Title[];
		countdown?: boolean;
		meta?: 'default' | 'season';
		loggedOut?: boolean;
		/** Where "See all →" goes; no link when unset. */
		seeAllHref?: string;
		/**
		 * The page's first row of covers: the ones on screen load right away,
		 * the first ahead of everything (it's the page's largest image).
		 */
		lead?: boolean;
	}

	let {
		heading,
		em,
		jp,
		subtitle = '',
		titles,
		countdown = false,
		meta = 'default',
		loggedOut = false,
		seeAllHref,
		lead = false
	}: Props = $props();

	/** Desktop shows one row of 7; "See all" has the rest. */
	const DESKTOP_COUNT = 7;
	/** How many 128px covers a phone shows before scrolling. */
	const PHONE_VISIBLE = 3;
	// both layouts are in the page, one hidden by CSS: only the shown one's
	// covers load eagerly (an eager image downloads even when hidden)
	const desktop = new MediaQuery('min-width: 1024px', false);
	const eagerPhone = (i: number) => lead && !desktop.current && i < PHONE_VISIBLE;
	const eagerDesktop = $derived(lead && desktop.current);
</script>

<div class="flex flex-col gap-3.5 lg:gap-[18px]">
	<SectionHeading {heading} {em} {jp} {subtitle} {seeAllHref} />

	<div class="flex scrollbar-none gap-3 overflow-x-auto px-4 lg:hidden">
		{#each titles as t, i (t.id)}
			<div class="w-32 flex-none">
				<PosterCard
					title={t}
					size="sm"
					{countdown}
					{meta}
					{loggedOut}
					eager={eagerPhone(i)}
					priority={eagerPhone(i) && i === 0}
				/>
			</div>
		{/each}
	</div>

	<div class="hidden grid-cols-7 gap-5 lg:grid">
		{#each titles.slice(0, DESKTOP_COUNT) as t, i (t.id)}
			<PosterCard
				title={t}
				{countdown}
				{meta}
				{loggedOut}
				eager={eagerDesktop}
				priority={eagerDesktop && i === 0}
			/>
		{/each}
	</div>
</div>
